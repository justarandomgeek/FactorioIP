local protocol = require("protocol.protocol")
local ipv6 = require("protocol.ipv6")
local fcp = require("protocol.fcp")
require("protocol.map_transfer")

local bridge = require("bridge")


---@class (exact) FBRouterPort: FBBridgePort, FBRemotePort
---@field public type "router"
---@field public port uint16
---@field public player integer
local router = {}

---@type metatable
local router_meta = {
    __index = router,
}

script.register_metatable("FBRouterPort", router_meta)

---@param port uint16
---@param player integer
---@return FBRouterPort
local function new(port, player)
  return setmetatable({
    type = "router",
    port = port,
    player = player,
  }, router_meta)
end

function router:advertise()
  bridge.send({
    proto = 2,
    src_addr = storage.address,
    dest_addr = 0,
    payload = fcp.advertise()
  }, self)
end

---@param packet string
function router:on_received_packet(packet)
  local greflags,ptype = string.unpack(">I2I2", packet)
  if greflags ~= 0 then return end
  if ptype ~= 0x86dd then return end

  -- remove the gre header
  packet = packet:sub(5)

  -- and make sure the end is aligned for whole 32bit words
  local padsize = 4 - (#packet % 4)
  if padsize ~= 4 then
    packet = packet .. string.rep("\0", padsize)
  end

  bridge.send(ipv6.parse(packet), self)
end

---@param packet QueuedPacket
function router:send(packet)
  local proto = protocol.handlers[packet.proto]
  if not proto then return end
  proto.dispatch(packet)
end

function router:label()
  return string.format("r%i:%i", self.player, self.port)
end

return new