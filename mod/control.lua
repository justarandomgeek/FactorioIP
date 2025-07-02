---@class (exact) FBStorage
---@field address int32 router address
---@field router FBRouterPort?
---@field id_to_signal {[integer]:SignalID}
---@field signal_to_id {[QualityID]:{[SignalIDType]:{[string]:integer}}}
---@field peers FBPeerPort[]
---@field remote_ports {[integer]:{[int16]:FBRemotePort}} map player->port->Port for dispatching received udp packets
---@field nodes {[integer]:FBCombinatorPort}
---@field neighbors {[int32]:Neighbor}
storage = {}

---@class (exact) QueuedPacket
---@field retry_count int32? # if non-nil, retry and decrement until 0 or txgood
---@field proto int32
---@field src_addr int32
---@field dest_addr int32
---@field payload LogisticFilter[]

---@class (exact) FBRemotePort
---@field public type "router"|"peer"
---@field public port uint16
---@field public player integer
---@field public on_received_packet fun(port:FBRemotePort, packet:string)

local bridge = require("bridge")

local ports = {
  combinator = require("ports.combinator"),
  peer = require("ports.peer"),
  router = require("ports.router"),
}
script.on_event(defines.events.on_received_packet, function (event)
  local player_ports = storage.remote_ports[event.player_index]
  if not player_ports then return end
  local port = player_ports[event.source_port]
  if not port then return end

  ---@type string
  local payload = event.payload
  port:on_received_packet(payload)
end)

script.on_nth_tick(30*60, function(e)
  local router = storage.router
  if router then
    router:periodic()
  end
end)

script.on_init(function()
  storage = {
    address = math.random(0x10000,0x7fffffff),
    nodes = {},
    id_to_signal = {},
    signal_to_id = {},
    neighbors = {},
    peers = {},
    remote_ports = {},
  }
end)

script.on_event(defines.events.on_tick, function()
  for player_id, player_ports in pairs(storage.remote_ports) do
    if next(player_ports) then
      helpers.recv_udp(player_id)
    end
  end

  for _,node in pairs(storage.nodes) do
    if node:valid() then
      node:on_tick()
    else
      for _, neigh in pairs(storage.neighbors) do
        if neigh.bridge_port == node then
          neigh.bridge_port = nil
          neigh.last_seen = 0
        end
      end
      storage.nodes[_] = nil
    end
  end
end)

script.on_event(defines.events.on_script_trigger_effect, function (event)
  if event.effect_id == "featherbridge-created" then
    local ent = event.cause_entity
    if ent and ent.type == "constant-combinator" then
      storage.nodes[ent.unit_number] = ports.combinator(ent)
    end
  end
end)

commands.add_command("FBstatus", "", function (param)
  local player = game.get_player(param.player_index)
  ---@cast player -?
  local out = {
    string.format("address %8X", storage.address),
  }
  if storage.router then
    out[#out+1] = string.format("router %i:%i", storage.router.player, storage.router.port)
  end
  for _, peer in pairs(storage.peers) do
    out[#out+1] = string.format("peer %i:%i", peer.player, peer.port)
  end

  out[#out+1] = "\nqueues:"
  for _, node in pairs(storage.nodes) do
    out[#out+1] = node:queues()
  end

  out[#out+1] = "\nneighbors:"
  for _, neighbor in pairs(storage.neighbors) do
    local port = neighbor.bridge_port and neighbor.bridge_port:label() or "-"
    out[#out+1] = string.format("addr %8X port %s last_seen %i", bit32.band(neighbor.address), port, neighbor.last_seen)
  end
  player.print(table.concat(out, "\n"))
end)

---@param parameter string
---@return integer?
---@return integer?
local function parse_player_and_port(parameter)
  if not parameter then return end
  local player,port = string.match(parameter, "(%d+) (%d+)")
  if not player then return end
  ---@cast port -?
  player = tonumber(player)
  port = tonumber(port)
  
  if port < 0 or port > 65535 then return end
  if not (player == 0 or game.get_player(player)) then return end

  return player,port
end

commands.add_command("FBPeer", "", function (param)
  local player,port = parse_player_and_port(param.parameter)
  if not player then return end
  ---@cast port -?

  local rp = storage.remote_ports
  local pl = rp[player]
  if not pl then
    pl = {}
    rp[player] = pl
  end
  local oldpeer = pl[port]

  local peers = storage.peers
  local peer_i
  if oldpeer then
    if oldpeer.type == "peer" then
      for i, peer in pairs(peers) do
          if peer == oldpeer then
            peer_i = i
            break
          end
        end
    else
      return -- conflicts with existing other type port
    end
  else
    peer_i = #peers + 1
  end

  local peer = ports.peer(port, player)
  peers[peer_i] = peer
  pl[port] = peer
end)

commands.add_command("FBUnpeer", "", function (param)
  local player,port = parse_player_and_port(param.parameter)
  if not player then return end
  ---@cast port -?

  local rp = storage.remote_ports
  local pl = rp[player]
  if not pl then return end
  local peer = pl[port]
  if not peer then return end
  if peer.type ~= "peer" then return end

  pl[port] = nil
  for i, oldpeer in pairs(storage.peers) do
    if peer == oldpeer then
      table.remove(storage.peers, i)
      break
    end
  end
end)

commands.add_command("FBTun", "", function (param)
  local player,port = parse_player_and_port(param.parameter)
  if not (port or param.parameter=="close") then return end

  local rp = storage.remote_ports
  local old = storage.router
  if old then
    rp[old.player][old.port] = nil
  end

  if param.parameter=="close" then return end
  ---@cast port -?
  ---@cast player -?

  local router = ports.router(port, player)
  storage.router = router

  local pl = rp[player]
  if not pl then
    pl = {}
    rp[player] = pl
  end
  pl[port] = router
end)