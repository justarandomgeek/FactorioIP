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
  TLVs for the rest? 
    type u8, datasize u16, data (`datasize` bytes)
  01 last seen partner
    info_bridge i32, info_player i32, info_port u16, info_ticks_ago u16, data_ticks_ago u16
  02 other known peers
    my(player i32, port i32) was (bridge i32, player i32, port u16, info_ticks_ago u16, data_ticks_ago u16)
  
  active mods?
  ip tunnel port info?
    map size u16, ticks_ago_recv u16
  
  list supported packed protocols?
    list fnet protoids
  supported peering features?
    list optional mtypes?
  (local) neighbor info?

peer mapex for denser messages?
some kind of loop detection/spanning-tree exchange?



]]

local packed_version = string.pack(">I2I2I2", string.match(script.active_mods[script.mod_name], "^(%d+)%.(%d+)%.(%d+)$"))

local qmap = prototypes.quality

---@type {name:SignalIDType, protos:LuaCustomTable<string>}[]
local typeinfos = { -- same order as SignalIDBase::Type internal enum
  [0]={
    name = "item",
    protos = prototypes.item,
  },
  {
    name = "fluid",
    protos = prototypes.fluid,
  },
  {
    name = "virtual",
    protos = prototypes.virtual_signal,
  },
  {
    name = "recipe",
    protos = prototypes.recipe,
  },
  {
    name = "entity",
    protos = prototypes.entity,
  },
  {
    name = "space-location",
    protos = prototypes.space_location,
  },
  {
    name = "quality",
    protos = prototypes.quality,
  },
  {
    name = "asteroid-chunk",
    protos = prototypes.asteroid_chunk,
  },
}

---@type table<SignalIDType, uint8>
local typeids = {}
for i, info in pairs(typeinfos) do
  typeids[info.name] = i
end

---@type {[integer]:fun(self:FBPeerPort, packet:string)}
local mtype_handlers = {}

---@param packet string
function peer:on_received_packet(packet)
  ---@type uint8
  local mtype = string.unpack(">B", packet)
  local handler = mtype_handlers[mtype]
  if handler then
    handler(self, packet)
  end
  if mtype~=3 and self.partner then
    self.partner.last_data = game.tick
  end
end

mtype_handlers[1] = function(self, packet)
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
            type = typeinfo.name,
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
    string.pack(">Bi4i4i4B", 1, packet.proto, packet.src_addr, packet.dest_addr, table_size(qgroups))
  }

  for qname, qgroup in pairs(qgroups) do
    local numsigs = #qgroup
    if numsigs > 0xffff then return end --too many signals, drop it.
    --TODO: maybe just split oversize an oversize group into two groups for the same qual?
    out[#out+1] = string.pack(">s1I2", qname, numsigs)
    out[#out+1] = table.concat(qgroup)
  end

  helpers.send_udp(self.port, table.concat(out), self.player)
end

---@type {[integer]:fun(self:FBPeerPort, data:string)}
local peerinfo_handlers = {}
mtype_handlers[3] = function(self, packet)
  -- got peer info
  local version, address, player, port, i = string.unpack(">xc6i4I4I2", packet)
  --TODO: compare versions?
  local lastpartner = self.partner
  if lastpartner and lastpartner.address == address then
    lastpartner.player = player
    lastpartner.port = port
    lastpartner.last_info = game.tick
  else
    self.partner = {
      --TODO: record version?
      address = address,
      player = player,
      port = port,
      last_info = game.tick,
      last_data = 0,
    }
  end

  while i < #packet do
    local typecode,datasize
    typecode,datasize,i = string.unpack(">BI2", packet, i)

    local handler = peerinfo_handlers[typecode]
    if handler then
      handler(self, packet:sub(i,i+datasize))
    end
    i = i+datasize
  end
end

peerinfo_handlers[1] = function(self, data)
  local address, player, port, last_info, last_data = string.unpack(">i4I4I2I2I2", data)
  if address ~= storage.address or player ~= self.player or port ~= self.port then
    self:send_peer_info()
  end
end


---@param type_id uint8
---@param pack_fmt string
---@param ... string|number
---@return string
local function tlv(type_id, pack_fmt, ...)
  local size = string.packsize(pack_fmt)
  return string.pack(">BI2"..pack_fmt, type_id, size, ...)
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

function peer:send_peer_info()
  self:expire_partner()
  local out = {
    string.pack(">Bc6i4i4I2", 3, packed_version, storage.address, self.player, self.port)
  }

  do
    local partner = self.partner
    if partner then
      out[#out+1] = tlv(1, ">i4I4I2I2I2", partner.address, partner.player, partner.port, ticks_ago(partner.last_info), ticks_ago(partner.last_data))
    end
  end

  for _, other in pairs(storage.peers) do
    local partner = other.partner
    if self ~= other  and partner then
      out[#out+1] = tlv(2, ">I4I2i4I4I2I2I2", other.player, other.port, partner.address, partner.player, partner.port, ticks_ago(partner.last_info), ticks_ago(partner.last_data))
    end
  end

  helpers.send_udp(self.port, table.concat(out), self.player)
end


function peer:expire_partner()
  local partner = self.partner
  if not partner then return end

  -- more than ~18 minutes with no info report, missed three cycles!
  if ticks_ago(partner.last_info) == 0xffff then
    self.partner = nil
  end
end

function peer:label()
  return string.format("u%i:%i", self.player, self.port)
end

return new