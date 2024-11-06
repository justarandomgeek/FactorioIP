---@class (exact) FBStorage
---@field address int32 one address for the whole bridge - used as link layer dest for traffic to forward to external
---@field nodes {[integer]:FBNode}
---@field id_to_signal {[integer]:SignalFilter}
---@field signal_to_id {[QualityID]:{[SignalIDType]:{[string]:integer}}}
---@field out_queue string[] packets waiting to go out to rcon
---@field in_queue string[] packets from rcon waiting to go out to bridge dispatch
---@field neighbors {[int32]:Neighbor}
storage = {}

---@class (exact) QueuedPacket
---@field retry_count int32? # if non-nil, retry and decrement until 0 or txgood
---@field dest_addr int32
---@field payload LogisticFilter[]

---@class (exact) Neighbor
---@field bridge_port FBNode? # known port if any
---@field address int32 # neighbor's link layer address
---@field last_seen int32 # tick last seen advertise
---@field last_solicit int32 # tick last sent (queued) solicit

---@class (exact) FBNode
---@field entity LuaEntity
---@field unit_number integer
---@field control LuaConstantCombinatorControlBehavior
---@field next_advertise integer # send periodic unsolicited advertise
---@field did_tx_last_tick boolean?
---@field fail_count number?
---@field next_retransmit number?
---@field out_queue QueuedPacket[] # packets waiting to go out to circit

local protocol = require("protocol.protocol")
require("protocol.ipv6")
local fcp = require("protocol.fcp")


---@param packet string
---@return LogisticFilter[] payload
---@return int32 dest_addr
local function packet_to_filters(packet)
  ---@type LogisticFilter[]
  local filters = {
    protocol.signal_value(protocol.signals.collision, 1),
    protocol.signal_value(protocol.signals.protoid, 1),
  }
  -- pre-allocate...
  filters[400] = nil

  --dest address...
  local addrtype,dest = string.unpack(">Bxxxxxxxxxxxi4", packet, 25)
  ---@cast addrtype uint8
  ---@cast dest int32
  -- 0 for multicast traffic, low 32bits of dest ip for unicast
  if addrtype == 0xff then
    dest = 0
  end
  filters[#filters+1] = protocol.signal_value(protocol.signals.dest_addr, dest)

  local len = #packet
  
  for i = 1,len,4 do
    local n = string.unpack(">i4", packet, i)
    local sig = storage.id_to_signal[((i-1)/4)+1]
    filters[#filters+1] = protocol.signal_value(sig, n)
  end
  return filters,dest
end


---@param packet QueuedPacket
---@param from_port? FBNode
local function bridge_broadcast(packet, from_port)
  for _, node in pairs(storage.nodes) do
    if node ~= from_port then
      -- shallow-copy the packet for separate retry counts. sharing payload is fine, it's read-only.
      node.out_queue[#node.out_queue+1] = {
        dest_addr = packet.dest_addr,
        retry_count = packet.retry_count,
        payload = packet.payload,
      }
    end
  end
end

---@param neighbor Neighbor
local function bridge_solicit(neighbor)
  ---@type QueuedPacket
  local sol = { dest_addr = 0, payload = fcp.solicit(neighbor.address) }
  bridge_broadcast(sol)
  neighbor.last_solicit = game.tick
end

---@param packet QueuedPacket
---@param from_port? FBNode
local function bridge_send(packet, from_port)
  if packet.dest_addr ~= 0 then
    local neighbor = storage.neighbors[packet.dest_addr]
    if neighbor and neighbor.bridge_port then
      -- send it! (unless from_port == bridge_port)
      if from_port ~= neighbor.bridge_port then
        local out_queue = neighbor.bridge_port.out_queue
        out_queue[#out_queue+1] = packet
      end
      -- also broadcast a solicit if stale
      bridge_solicit(neighbor)
    else
      -- broadcast the packet...
      bridge_broadcast(packet, from_port)
      -- ... and a solicit, to know where for next time...
      neighbor = {
        address = packet.dest_addr,
        last_seen = 0,
        last_solicit = 0,
      }
      storage.neighbors[neighbor.address] = neighbor
      bridge_solicit(neighbor)
    end
  else
    -- broadcast the packet
    bridge_broadcast(packet, from_port)
  end
end

---@param node FBNode
---@param net LuaCircuitNetwork
---@param dest_addr? int32
local function bridge_forward(node, net, dest_addr)
  local signals = net.signals
  ---@cast signals -?
  ---@type LogisticFilter[]
  local payload = {}
  for _, signal in pairs(signals) do
    payload[#payload+1] = {
      value = signal.signal --[[@as SignalFilter.0]],
      min = signal.count,
    }
  end
  bridge_send({
    dest_addr = dest_addr or 0,
    retry_count = 2,
    payload = payload,
  }, node)
end

---@param node FBNode
---@p reason string
local function node_disabled(node, reason)
  local entity = node.entity
  node.control.enabled = false
  entity.custom_status = {
    diode = defines.entity_status_diode.red,
    label = string.format("Disabled: %s", reason)
  }
  --TODO: locale all these string.formats
  entity.combinator_description = string.format("FeatherBridge %8X\nDisabled: %s", storage.address, reason)
end


local wire_tag = {
  [defines.wire_type.red] = "[img=item/red-wire]",
  [defines.wire_type.green] = "[img=item/green-wire]",
}

---@param node FBNode
---@param net LuaCircuitNetwork
local function node_active(node, net)
  local entity = node.entity
  if node.fail_count then
    entity.custom_status = {
      diode = defines.entity_status_diode.yellow,
      label = "Waiting to Retransmit"
    }
  else
    entity.custom_status = {
      diode = defines.entity_status_diode.green,
      label = "Ready"
    }
  end
  entity.combinator_description = string.format(
    "FeatherBridge %8X on %s%i\nqueue:%i fail:%i retry:%i",
    storage.address, wire_tag[net.wire_type], net.network_id,
    #node.out_queue, node.fail_count or 0, node.next_retransmit or 0
  )
end

---@param node FBNode
local function on_tick_node(node)
  local entity = node.entity

  ---@type LuaCircuitNetwork?
  local net
  do
    local rnet = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local gnet = entity.get_circuit_network(defines.wire_connector_id.circuit_green)

    if rnet and gnet then
      node_disabled(node, string.format("Multiple Circuit Connections [img=item/red-wire]%i [img=item/green-wire]%i", rnet.network_id, gnet.network_id))
      return
    end
    net = rnet or gnet

    if not net then
      node_disabled(node, "No Circuit Connection")
      return
    end
  end

  -- read collision check signal
  local col = net.get_signal(protocol.signals.collision --[[@as SignalID]])

  if node.did_tx_last_tick then
    node.did_tx_last_tick = nil
    node.control.enabled = false
    if (col == nil or col == 1) then
      -- tx ok
      table.remove(node.out_queue, 1)
      node.fail_count = nil
      node.next_retransmit = nil
    else
      -- tx fail
      local pending = node.out_queue[1]
      local retry = true
      if pending.retry_count then
        pending.retry_count = pending.retry_count - 1
        if pending.retry_count <= 0 then
          retry = false
        end
      else
        retry = false
      end

      if retry then
        -- set retry delay
        node.fail_count = (node.fail_count or 0) + 1
        node.next_retransmit = math.random(1, 2^(node.fail_count+2))
      else
        -- drop
        table.remove(node.out_queue, 1)
        node.fail_count = nil
        node.next_retransmit = nil
      end
    end
  else
    if col == 1 then -- got someone else's tx!
      local addr = net.get_signal(protocol.signals.dest_addr --[[@as SignalID]])
      if addr == storage.address or addr == 0 then
        -- for me/bcast?
        local protoid = net.get_signal(protocol.signals.protoid --[[@as SignalID]])
        local proto = protocol.handlers[protoid]
        if proto then
          proto.receive(node, net)
        end
        if addr == 0  then
          --also forward broadcasts to other links?
          bridge_forward(node, net)
        end
      else
        --forward it, to specific queue if known, or to all + ND if not
        bridge_forward(node, net, addr)
      end
    end

    -- do tx activity...
    if node.next_retransmit then
      if node.next_retransmit == 1 then
      node.next_retransmit = nil
      else
        node.next_retransmit = node.next_retransmit - 1
      end
    else
      local filters = node.out_queue[1]
      if filters then
        -- try tx...
        node.did_tx_last_tick = true
        node.control.sections[1].filters = filters
        node.control.enabled = true
      end
    end
  end

  node_active(node, net)
end

script.on_nth_tick(30*60, function(e)
  bridge_broadcast({
    dest_addr = 0,
    payload = fcp.advertise(storage.address)
  })
end)


script.on_event(defines.events.on_tick, function()
  --dispatch one frame (or more?) from storage.in_queue before processing nodes...
  local packet = storage.in_queue[1]
  if packet then
    local filters,dest_addr = packet_to_filters(packet)
    bridge_send({
      dest_addr = dest_addr,
      retry_count = 4,
      payload = filters,
    })
    table.remove(storage.in_queue, 1)
  end

  for _,node in pairs(storage.nodes) do
    on_tick_node(node)
  end
end)

commands.add_command("FBbind", "", function(param)
  -- bind to the selected constant combinator for data IO (always just one - one per surface?)
  local ent = game.get_player(param.player_index).selected
  if ent and ent.type == "constant-combinator" then
    storage.nodes[ent.unit_number] = {
      entity = ent,
      unit_number = ent.unit_number,
      control = ent.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]],
      next_advertise = game.tick,
      out_queue = {},
    }
  end
end)

commands.add_command("FBtraff", "", function(param)
  -- exchange packets. in from parameter, out to rcon.print
  local data = param.parameter
  if data and #data > 0 then
    --read packets
    local buff = storage.in_queue
    local i = 1
    repeat
      ---@type uint16 size
      local size
      size,i = string.unpack(">I2", data, i)
      local j = i+(size*4)-1
      if j > #data then break end -- bad data size
      -- byte[size*4] packet
      local packet = data:sub(i, j)
      local nbuff = #buff+1
      buff[nbuff] = packet
      if nbuff > 20 then break end -- too may packets waiting already, just drop the rest...
      i = j
    until i >= #data
  end
  -- send packets
  if storage.out_queue then
    for _, packet in pairs(storage.out_queue) do
      rcon.print(packet)
    end
    storage.out_queue = {}
  end

end)


commands.add_command("FBtakemap", "", function(param)
  -- capture signal map from selected
  if not param.player_index then return end
  local player = game.get_player(param.player_index) --[[@as LuaPlayer]]
  local selected = player.selected
  if not selected then player.print("nothing selected") return end

  --TODO: select wire(s)
  local captured = selected.get_signals(defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
  if not captured then return end

  local by_value = {}
  for _, signal in pairs(captured) do
    local c = signal.count
    if not by_value[c] then by_value[c] = {} end
    by_value[c][#by_value[c]+1] = signal.signal
  end

  local map = {}
  local rmap = {}

  for _, group in pairs(by_value) do
    for _, signal in pairs(group) do
      local i = #map+1
      map[i] = signal

      local qual = rmap[signal.quality or "normal"]
      if not qual then
        qual = {}
        rmap[signal.quality or "normal"] = qual
      end

      local sigtype = qual[signal.type or "item"]
      if not sigtype then
        sigtype = {}
        qual[signal.type or "item"] = sigtype
      end
      sigtype[signal.name] = i

      -- stop at 375 signals = 1500 bytes
      if i >= 375 then goto map_finished end
    end
  end
  ::map_finished::
  storage.id_to_signal = map
  storage.signal_to_id = rmap
  player.print("took "..#storage.id_to_signal.." signals")
  helpers.write_file("feathermap.txt", serpent.block(storage.id_to_signal))
end)