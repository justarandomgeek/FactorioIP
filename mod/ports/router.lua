local protocol = require("protocol.protocol")
local ipv6 = require("protocol.ipv6")
local fcp = require("protocol.fcp")
require("protocol.map_transfer")

local bridge = require("bridge")


---@class (exact) FBRouterPort: FBBridgePort, FBRemotePort
---@field public type "router"
---@field public player integer
---@field public port uint16
---@field public last_recv MapTick
local router = {}

---@type metatable
local router_meta = {
    __index = router,
}

script.register_metatable("FBRouterPort", router_meta)

---@return FBRouterPort
local function new()
  return setmetatable({
    type = "router",
    port = 0,
    player = 0,
    last_recv = 0,
  }, router_meta)
end


---@param port uint16
---@param player integer
function  router:set_tunnel(player,port)
  local rp = storage.remote_ports
  if self.port ~= 0 then
    rp[self.player][self.port] = nil
  end

  if port==0 then return end

  local pl = rp[player]
  if not pl then
    pl = {}
    rp[player] = pl
  end
  pl[port] = self
end

---@public
---@param dest? int32
function router:advertise(dest)
  local flags = fcp.adv_flags.map_trans
  if self.port ~= 0 then
    flags = flags + fcp.adv_flags.ip_tun
  end
  bridge.send(fcp.advertise(dest or 0, flags), self)
end

---@param packet string
function router:on_udp_packet_received(packet)
  -- too short to contain valid headers
  if #packet < 44 then return end
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

  self.last_recv = game.tick

  bridge.send(ipv6.parse(packet), self)
end

---@param packet QueuedPacket
function router:send(packet)
  if packet.dest_addr ~= 0 and packet.dest_addr ~= storage.address then return end
  local proto = protocol.handlers[packet.proto]
  if not proto then return end
  proto.dispatch(self, packet)
end

function router:label()
  return string.format("r%i:%i", self.player, self.port)
end

function router:status()
  return string.format("router %i:%i last_recv %i", self.player, self.port, self.last_recv and game.tick-self.last_recv or -1)
end

return new