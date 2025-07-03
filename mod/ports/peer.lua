local protocol = require("protocol.protocol")
local bridge = require("bridge")

---@class (exact) FBPeerPort: FBBridgePort, FBRemotePort
---@field public type "peer"
---@field public port uint16
---@field public player integer
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
  "calling":
    player id (int32)
    port (uint16)
  TLVs for the rest? 
    type u16, datasize u16, data (`datasize` bytes)
  0001 last seen partner
    bridge i32, player i32, port u16, ticks_ago u16
  0002 list other known peers?
    my(player i32, port i32) was (bridge i32, player i32, port u16), ticks_ago u16

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
  filters[1023] = nil

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

function peer:label()
  return string.format("u%i:%i", self.player, self.port)
end

return new