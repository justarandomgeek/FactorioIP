local protocol = require("protocol.protocol")
local bridge = require("bridge")

---@class (exact) FBPeerPort: FBBridgePort, FBRemotePort
---@field public type "peer"
---@field public port uint16
---@field public player integer
---@field package partner? {address:int32, player:integer, port:uint16, last_info:MapTick, last_data:MapTick}
local peer = {}

---@type metatable
local peer_meta = {
    __index = peer,
}

script.register_metatable("FBPeerPort", peer_meta)

---@param port uint16
---@param player integer
---@return FBPeerPort
local function new(port, player)
  return setmetatable({
    type = "peer",
    port = port,
    player = player,
  }, peer_meta)
end

---@param change ConfigurationChangedData
function peer:on_configuration_changed(change)
  self.partner = nil
end

--[[

0x01 mtype=raw
fnet header:
  protoid (int32)
  src_addr (int32)
  dst_addr (int32)
num qual sections (uint8)
  qual name (string8)
  num sigs (uint16)
    type(uint8), name(string8), value(int32)

0x02 mtype=packed
fnet header
  (same as raw)
then packed body per-protocol...



0x03 mtype=peerinfo
  "this is":
    mod version (u16.u16.u16)
    bridge id (int32)
  "calling on":
    player id (int32)
    port (uint16)
  TLVs for the rest
    type u8, datasize u16, data (`datasize` bytes)
  01 last seen partner
    info_bridge i32, info_player i32, info_port u16, info_ticks_ago u16, data_ticks_ago u16
  02 other known peer
    my(player i32, port i32) was (bridge i32, player i32, port u16, info_ticks_ago u16, data_ticks_ago u16)
  
  routing info
    dest i32, age u16
    num hops (uint8) [bridge id int32 from self to dest, not including self/dest]
    
  ip tunnel status?
    map info? recv_ticks_ago?
  active mods?
  list supported packed protocols?
    list fnet protoids

0x04 fragmented message
  msg id (uint32) random? sequential? hash some header bits + tick?
  offset (uint32)
  flags
    last fragment
  size (uint16)
  data
    [chunks of any fragmentable mtype]

peer mapex for denser messages?
some way to derive a map-hash from just listing everything locally to save the exchange when all matches?
some kind of loop detection/spanning-tree exchange? elect a leader? ip tunnel or lowest id?


]]

local packed_version = string.pack(">I2I2I2", string.match(script.active_mods[script.mod_name], "^(%d+)%.(%d+)%.(%d+)$"))

local qmap = prototypes.quality

---@type {type:SignalIDType, protos:LuaCustomTable<string>}[]
local typeinfos = { -- same order as SignalIDBase::Type internal enum
  [0]={
    type = "item",
    protos = prototypes.item,
  },
  {
    type = "fluid",
    protos = prototypes.fluid,
  },
  {
    type = "virtual",
    protos = prototypes.virtual_signal,
  },
  {
    type = "recipe",
    protos = prototypes.recipe,
  },
  {
    type = "entity",
    protos = prototypes.entity,
  },
  {
    type = "space-location",
    protos = prototypes.space_location,
  },
  {
    type = "quality",
    protos = prototypes.quality,
  },
  {
    type = "asteroid-chunk",
    protos = prototypes.asteroid_chunk,
  },
}

---@type table<SignalIDType, uint8>
local typeids = {}
for i, info in pairs(typeinfos) do
  typeids[info.type] = i
end

---@enum msgtype
local msgtype = {
  raw = 1,
  packed = 2,
  peerinfo = 3,
}

---@type {[msgtype]:fun(self:FBPeerPort, packet:string)}
local mtype_handlers = {}

---@param packet string
function peer:on_udp_packet_received(packet)
  ---@type msgtype
  local mtype = string.unpack(">B", packet)
  local handler = mtype_handlers[mtype]
  if handler then
    handler(self, packet)
  end
  if mtype~=3 and self.partner then
    self.partner.last_data = game.tick
  end
end

mtype_handlers[msgtype.raw] = function(self, packet)
  local
  ---@type int32
  ptype,
  ---@type int32
  src,
  ---@type int32
  dest,
  ---@type uint8
  qual_sections,
  ---@type integer
  i = string.unpack(">xi4i4i4B", packet)

  ---@type LogisticFilter[]
  local filters = {}
  -- pre-allocate array part...
  filters[1024] = nil

  for _ = 1,qual_sections,1 do
    local quality,num_signals
    quality,num_signals,i = string.unpack(">s1I2", packet, i)

    local qvalid = not not qmap[quality]
    for _ = 1,num_signals,1 do
      local typeid,name,value
      typeid,name,value,i = string.unpack(">Bs1i4", packet, i)
      if qvalid then
        local typeinfo = typeinfos[typeid]
        if typeinfo and typeinfo.protos[name] then
          filters[#filters+1] = protocol.signal_value({
            type = typeinfo.type,
            name = name,
            quality = quality,
          }, value)
        end
      end
    end
  end
  bridge.send({
    proto = ptype,
    src_addr = src,
    dest_addr = dest,
    retry_count = 2,
    payload = filters,
  }, self)
end

mtype_handlers[msgtype.packed] = function(self, packet)
  local
  ---@type int32
  ptype,
  ---@type int32
  src,
  ---@type int32
  dest,
  ---@type integer
  i = string.unpack(">xi4i4i4", packet)

  local handler = protocol.handlers[ptype]
  if handler and handler.unpack then
    local unpacked = handler.unpack({
        proto = ptype,
        src_addr = src,
        dest_addr = dest,
        retry_count = 2,
        payload = {},
      }, packet:sub(i))
    if unpacked then
      bridge.send(unpacked, self)
    end
  end
end

---@type {[QualityID]:{[SignalIDType]:{[string]:boolean}}}
local pack_skip_list = {
  normal = {
    virtual = {
      ["signal-check"] = true,
      ["signal-info"] = true,
      ["signal-input"] = true,
      ["signal-output"] = true,
    }
  }
}

---@param signal SignalFilter.0
---@return boolean?
local function pack_skip(signal)
  local qual = pack_skip_list[signal.quality or "normal"]
  if not qual then return end
  local stype = qual[signal.type or "item"]
  if not stype then return end
  return stype[signal.name]
end

---@param packet QueuedPacket
function peer:send(packet)
  self:expire_partner()
  if not self.partner then return end
  if not (self.player==0 or game.get_player(self.player).connected) then return end

  local handler = protocol.handlers[packet.proto]
  if handler and handler.pack then
    local data = handler.pack(packet)
    if data then
      local head = string.pack(">Bi4i4i4", msgtype.packed, packet.proto, packet.src_addr, packet.dest_addr)
      helpers.send_udp(self.port, head..data, self.player)
      return
    end
  end

  local qgroups = {}
  for _, signal in pairs(packet.payload) do
    local value = signal.value
    ---@cast value -?
    ---@cast value -string
    if not pack_skip(value) then
      local q = value.quality or "normal"
      local qgroup = qgroups[q]
      if not qgroup then
        qgroup = {}
        qgroups[q] = qgroup
      end
      qgroup[#qgroup+1] = string.pack(">Bs1i4", typeids[value.type or "item"], value.name, signal.min)
    end
  end

  local out = {
    string.pack(">Bi4i4i4B", msgtype.raw, packet.proto, packet.src_addr, packet.dest_addr, table_size(qgroups))
  }

  for qname, qgroup in pairs(qgroups) do
    local numsigs = #qgroup
    if numsigs > 0xffff then return end --too many signals, drop it.
    --TODO: maybe just split oversize an oversize group into two groups for the same qual?
    -- probably too large for one packet anyway at that point, so need to fragment it?...
    out[#out+1] = string.pack(">s1I2", qname, numsigs)
    --TODO: probably faster to just flatten the list into one table and let the concat at the end do it all!
    out[#out+1] = table.concat(qgroup)
  end

  helpers.send_udp(self.port, table.concat(out), self.player)
end

---@enum peerinfo_opt
local peerinfo_opt = {
  knownpeer = 1,
  otherpeer = 2,
}

---@type {[peerinfo_opt]:fun(self:FBPeerPort, options:table, data:string)}
local peerinfo_handlers = {}
mtype_handlers[msgtype.peerinfo] = function(self, packet)
  -- got peer info
  local version, address, player, port, i = string.unpack(">xc6i4I4I2", packet)
  --TODO: compare versions?
  local lastpartner = self.partner
  if lastpartner and lastpartner.address == address then
    lastpartner.player = player
    lastpartner.port = port
    lastpartner.last_info = game.tick
    -- reset any proto options
  else
    self.partner = {
      --TODO: record version? space for any proto options?
      address = address,
      player = player,
      port = port,
      last_info = game.tick,
      last_data = 0,
    }
  end

  local options = {}

  while i < #packet do
    local typecode,data
    typecode,data,i = string.unpack(">Bs2", packet, i)

    local handler = peerinfo_handlers[typecode]
    if handler then
      handler(self, options, data)
    end
    i = i
  end

  if options.send_info or not options.known_peer then
    self:send_peer_info()
  end
end

peerinfo_handlers[peerinfo_opt.knownpeer] = function(self, options, data)
  local address, player, port, last_info, last_data = string.unpack(">i4I4I2I2I2", data)
  options.known_peer = { address=address, player=player, port=port, last_info=last_info, last_data=last_data }
  if address ~= storage.address or player ~= self.player or port ~= self.port or
      last_info > 10*60*60 then
    options.send_info = true
  end
end


---@param type_id uint8
---@param pack string
---@param ... string|number
---@return string
local function tlv(type_id, pack, ...)
  if ... then
    pack = string.pack(pack, ...)
  end
  return string.pack(">Bs2", type_id, pack)
end

---@param t MapTick
local function ticks_ago(t)
  t = game.tick - t
  if t > 0xffff then
    return 0xffff
  else
    return t
  end
end

---@public
function peer:send_peer_info()
  self:expire_partner()
  if not (self.player==0 or game.get_player(self.player).connected) then return end

  local out = {
    string.pack(">Bc6i4i4I2", msgtype.peerinfo, packed_version, storage.address, self.player, self.port)
  }

  do
    local partner = self.partner
    if partner then
      out[#out+1] = tlv(peerinfo_opt.knownpeer, ">i4I4I2I2I2", partner.address, partner.player, partner.port, ticks_ago(partner.last_info), ticks_ago(partner.last_data))
    end
  end

  for _, other in pairs(storage.peers) do
    local partner = other.partner
    if self ~= other  and partner then
      out[#out+1] = tlv(peerinfo_opt.otherpeer, ">I4I2i4I4I2I2I2", other.player, other.port, partner.address, partner.player, partner.port, ticks_ago(partner.last_info), ticks_ago(partner.last_data))
    end
  end

  helpers.send_udp(self.port, table.concat(out), self.player)
end

---@public
---@param force? boolean force the peer to expire, even if timer is not run out
function peer:expire_partner(force)
  local partner = self.partner
  if not partner then return end

  -- more than ~18 minutes with no info report, missed three cycles!
  if force or ticks_ago(partner.last_info) == 0xffff then
    self.partner = nil
  end
end

---@public
---@return string
function peer:label()
  return string.format("u%i:%i", self.player, self.port)
end

---@public
---@return string
function peer:status()
  local partner = "-"
  if self.partner then
    partner = string.format("%8X:%i:%i last_info %i last_data %i", bit32.band(self.partner.address), self.partner.player, self.partner.port, game.tick-self.partner.last_info, game.tick-self.partner.last_data)
  end
  return string.format("peer %i:%i %s", self.player, self.port, partner)
end

return new