

---@class (exact) FBStorage
---@field address int32
---@field node FBNode
---@field id_to_signal {[integer]:SignalFilter}
---@field signal_to_id {[QualityID]:{[SignalIDType]:{[string]:integer}}} qual->sigtype->name->id
---@field rconbuffer string[] packets waiting to go out to rcon
storage = {}

---@class (exact) FBNode
---@field entity LuaEntity
---@field control LuaConstantCombinatorControlBehavior
---@field fcp_send_advertise boolean?
---@field tx_last_tick int32? protoid that did the tx
---@field fail_count number?
---@field next_retransmit number?
---@field txbuffer string[] packets waiting to go out to circuit

local protocol = require("protocol.protocol")

---@class FBProtocol
---@field receive fun(node:FBNode, net:LuaCircuitNetwork)
---@field try_send fun(node:FBNode):LogisticFilter[]?
---@field tx_good fun(node:FBNode)

---@type {[int32]:FBProtocol}
local protocols = {

  -- ipv6
  [1] = require("protocol.ipv6"),

  -- fcp
  [2] = require("protocol.fcp"),
}

---@param node FBNode
---@param reason string
local function node_disabled(node, reason)
  local entity = node.entity
  node.control.enabled = false
  entity.custom_status = {
    diode = defines.entity_status_diode.red,
    label = string.format("Disabled: %s", reason)
  }
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
    "FeatherBridge %8X on %s%i\ntxq:%i rxq:%i\nfail:%i retry:%i",
    storage.address, wire_tag[net.wire_type], net.network_id,
    #node.txbuffer, #storage.rconbuffer,
    node.fail_count or 0, node.next_retransmit or 0
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
      node_disabled(node, string.format("Multiple Connections [img=item/red-wire]%i [img=item/green-wire]%i", rnet.network_id, gnet.network_id))
      return
    end
    net = rnet or gnet

    if not net then
      node_disabled(node, "No Connection")
      return
    end
  end

  if node.tx_last_tick then
    -- read collision check signal
    local col = net.get_signal(protocol.signals.colsig)

    node.control.enabled = false
    if (col == nil or col == 1) then
      -- tx ok
      protocols[node.tx_last_tick].tx_good(node)
      node.fail_count = nil
    else
      -- tx fail
      node.fail_count = (node.fail_count or 0) + 1
      --TODO: protocol.tx_fail(count) -> bool should_retry
      node.next_retransmit = math.random(1, 2^(node.fail_count+2))
    end
    node.tx_last_tick = nil
  else
    local col = net.get_signal(protocol.signals.colsig)
    if col == 1 then -- got someone else's tx!
      local addr = net.get_signal(protocol.signals.addrsig)
      
      if addr == storage.address or addr == 0 then
        -- for me/bcast?
        local protoid = net.get_signal(protocol.signals.protosig)
        local proto = protocols[protoid]
        if proto then
          proto.receive(node, net)
        end
        --TODO: also forward broadcasts to all links?
      else
        -- forward it? to specific queue if known, or to all + ND if not?
      end
    end
    if node.next_retransmit then
      if node.next_retransmit == 1 then
        node.next_retransmit = nil
      else
        node.next_retransmit = node.next_retransmit - 1
      end
    else
      for protoid, proto in pairs(protocols) do
        local filters = proto.try_send(node)
        if filters then
          -- try tx...
          node.tx_last_tick = protoid
          node.control.sections[1].filters = filters
          node.control.enabled = true
          break
        end
      end
    end
  end

  node_active(node, net)
end

script.on_event(defines.events.on_tick, function()
  if storage.node then
    on_tick_node(storage.node)
  end
end)

commands.add_command("FBbind", "", function(param)
  -- bind to the selected constant combinator for data IO (always just one - one per surface?)
  local ent = game.get_player(param.player_index).selected
  if not ent or ent.type ~= "constant-combinator" then
    storage.node = nil
  else
    storage.node = {
      entity = ent,
      control = ent.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]],
      address = math.random(1,0x7fffffff),
      txbuffer = {}
    }
    storage.rconbuffer = {}
  end
end)

commands.add_command("FBtraff", "", function(param)
  -- exchange packets. in from parameter, out to rcon.print
  local data = param.parameter
  if data and #data > 0 and storage.node then
    --read packets
    local buff = storage.node.txbuffer
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
  if storage.rconbuffer then
    for _, packet in pairs(storage.rconbuffer) do
      rcon.print(packet)
    end
    storage.rconbuffer = {}
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