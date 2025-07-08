---@class (exact) FBStorage
---@field address int32 bridge/router address
---@field router FBRouterPort
---@field id_to_signal {[integer]:SignalID} --TODO: use LuaXPrototype objects here for free migrations
---@field signal_to_id {[QualityID]:{[SignalIDType]:{[string]:integer}}} --TODO: move this to a local taht's rebuilt on_load
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

script.on_nth_tick(60*60, function(e)
  for _, peer in pairs(storage.peers) do
    peer:send_peer_info()
  end

  storage.router:advertise()

  -- drop stale neighbor records
  local stale = game.tick - 15*60*60
  for addr, neigh in pairs(storage.neighbors) do
    if neigh.last_sought < stale and neigh.last_seen < stale then
      storage.neighbors[addr] = nil
    end
  end
end)

script.on_init(function()
  storage = {
    address = math.random(0x10000,0x7fffffff),
    router = ports.router(),
    nodes = {},
    id_to_signal = {},
    signal_to_id = {},
    neighbors = {},
    peers = {},
    remote_ports = {},
  }
end)

script.on_load(function()
  --reload reverse maps
  -- signal_to_id
  -- remote_ports
end)

script.on_configuration_changed(function(change)
  storage.neighbors = {}
  for _, peer in pairs(storage.peers) do
    peer:on_configuration_changed(change)
  end
  if not storage.router then
    storage.router = ports.router()
  end
  --TODO: check signal maps still valid
end)

script.on_event(defines.events.on_player_left_game, function (event)
  -- mark peers as dead
  for _, peer in pairs(storage.peers) do
    if peer.player ~= event.player_index then
      peer:expire_partner(true)
    end
  end
end)

script.on_event(defines.events.on_player_removed, function (event)
  -- remove ports entirely (and cleanup neighbor entries)
  if storage.router.player == event.player_index then
    storage.router:set_tunnel(0,0)
    -- router stays active, so no neighbor cleanup
  end
  local peers = {}
  for _, peer in pairs(storage.peers) do
    if peer.player ~= event.player_index then
      peer[#peer+1] = peer
    else
      for _, neigh in pairs(storage.neighbors) do
        if neigh.bridge_port==peer then
          neigh.bridge_port = nil
          neigh.last_seen = 0
        end
      end
    end
  end
  storage.peers = peers
  storage.remote_ports[event.player_index] = nil
end)

script.on_event(defines.events.on_player_joined_game, function (event)
  -- announce to peers if this revives any ports?
  for _, peer in pairs(storage.peers) do
    if peer.player ~= event.player_index then
      peer:send_peer_info()
    end
  end
end)

script.on_event(defines.events.on_tick, function()
  for player_id, player_ports in pairs(storage.remote_ports) do
    if next(player_ports) and (player_id==0 or game.get_player(player_id).connected) then
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
    string.format("bridge %8X", storage.address),
  }
  out[#out+1] = storage.router:status()
  for _, peer in pairs(storage.peers) do
    out[#out+1] = peer:status()
  end
  for _, node in pairs(storage.nodes) do
    out[#out+1] = node:status()
  end

  out[#out+1] = "\nneighbors:"
  for _, neighbor in pairs(storage.neighbors) do
    local port = neighbor.bridge_port and neighbor.bridge_port:label() or "-"
    out[#out+1] = string.format("addr %8X port %s last_seen %i last_sought %i", bit32.band(neighbor.address), port, game.tick-neighbor.last_seen, game.tick-neighbor.last_sought)
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
  player = tonumber(player)
  port = tonumber(port)
  ---@cast player integer
  ---@cast port integer

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
  if param.parameter=="close" then
    storage.router:set_tunnel(0,0)
  else
    local player,port = parse_player_and_port(param.parameter)
    if not player then return end
    ---@cast port -?
    storage.router:set_tunnel(player,port)
  end
end)