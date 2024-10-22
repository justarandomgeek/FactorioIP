

---@class FBStorage
---@field node FBNode
---@field id_to_signal {[integer]:SignalFilter}
---@field signal_to_id {[QualityID]:{[SignalIDType]:{[string]:integer}}} qual->sigtype->name->id
---@field rconbuffer string[] packets waiting to go out to rcon
storage = {}

---@class FBNode
---@field entity LuaEntity
---@field control LuaConstantCombinatorControlBehavior
---@field address int32
---@field fcp_send_advertise boolean?
---@field tx_last_tick boolean?
---@field fail_count number?
---@field next_retransmit number?
---@field txbuffer string[] packets waiting to go out to circuit


---@type SignalFilter
local colsig = {
  type = "virtual",
  name = "signal-check"
}

---@type SignalFilter
local protosig = {
  type = "virtual",
  name = "signal-info"
}


---@type SignalFilter
local addrsig = {
  type = "virtual",
  name = "signal-dot"
}


---@type SignalFilter
local fcpmsgtype = {
  type = "virtual",
  name = "signal-0"
}

---@type SignalFilter
local fcpsubject = {
  type = "virtual",
  name = "signal-1"
}

---@type SignalFilter
local fcpflags = {
  type = "virtual",
  name = "signal-2"
}

---@param signal SignalFilter
---@param value int32
---@return LogisticFilter
local function signal_value(signal, value)
  return {
    value = {
      type = signal.type or "item",
      name = signal.name,
      quality = signal.quality or "normal",
      comparator = "=",
    },
    min = value,
  }
end


---@param packet string
---@return LogisticFilter[]
local function packet_to_filters(packet)
  ---@type LogisticFilter[]
  local filters = {
    signal_value(colsig, 1),
    signal_value(protosig, 1), --TODO: type on incoming packets? anything other than ipv6?
  }
  -- pre-allocate...
  filters[400] = nil

  local len = #packet
  
  for i = 1,len,4 do
    local n = string.unpack(">i4", packet, i)
    local sig = storage.id_to_signal[((i-1)/4)+1]
    local index = #filters+1
    filters[index] = signal_value(sig, n)
  end
  return filters
end

---@param address int32
---@return LogisticFilter[]
local function fcp_advertise(address)
  return {
    signal_value(colsig, 1),
    signal_value(protosig, 2),
    signal_value(fcpmsgtype, 2),
    signal_value(fcpsubject, address),
    signal_value(fcpflags, 1),
  }
end


---@class FBProtocol
---@field receive fun(node:FBNode):string
---@field try_send fun(node:FBNode):LogisticFilter[]?

local protocols = {

  -- ipv6
  [1] = {
    receive = function (node)
      if not (storage.rconbuffer and storage.signal_to_id) then return end
      local entity = node.entity
      -- read to rcon buffer
      local sigs = entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
      ---@cast sigs -?
  
      local map = storage.signal_to_id
  
      local packet_values = {}
      packet_values[400] = nil
      local top = 0
  
      for _, sig in pairs(sigs) do
        local signal = sig.signal
        local qmap = map[signal.quality or "normal"]
        if not qmap then goto continue end
  
        local tmap = qmap[signal.type or "item"]
        if not tmap then goto continue end
  
        local id = tmap[signal.name]
        if not id then goto continue end
  
        packet_values[id] = string.pack(">i4", sig.count)
        if id > top then top = id end
        ::continue::
      end
  
      if top > 0 then
        for i = 1, top, 1 do
          if not packet_values[i] then
            packet_values[i] = "\0\0\0\0"
          end
        end
      end
  
      -- stick a 16 bit length (count of 32bit words) and 16 bit ethertype on the front
      table.insert(packet_values, 1, string.pack(">I2I2", top, 0x86dd))
  
      storage.rconbuffer[#storage.rconbuffer+1] = table.concat(packet_values)
    end,
    try_send = function(node)
      local packet = node.txbuffer[1]
      if packet then
        return packet_to_filters(packet)
      end
    end,
  },

  -- fcp
  [2] = {
    receive = function (node)
      local entity = node.entity
      local mtype = entity.get_signal(fcpmsgtype, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
      if mtype == 1 then -- solicit
        local subject = entity.get_signal(fcpsubject, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
        if subject == node.address or subject == 0 then
          -- got a solicit for me, so send an advertise back...
          node.fcp_send_advertise = true
          node.fail_count = nil
          node.next_retransmit = nil
        end
      end
    end,
    try_send = function (node)
      if node.fcp_send_advertise then
        return fcp_advertise(node.address)
      end
    end,
  }
}

---@param node FBNode
local function on_tick_node(node)
  local entity = node.entity

  if node.tx_last_tick then
    -- read collision check signal
    local rnet = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local gnet = entity.get_circuit_network(defines.wire_connector_id.circuit_green)
    local rcol = rnet and rnet.get_signal(colsig)
    local gcol = gnet and gnet.get_signal(colsig)

    node.control.enabled = false
    node.tx_last_tick = nil
    if (rcol == nil or rcol == 1) and (gcol == nil or gcol == 1) then
      -- tx ok on both wires
      node.fail_count = nil
      if node.fcp_send_advertise then
        node.fcp_send_advertise = nil
      else
        -- drop from buffer
        table.remove(node.txbuffer, 1)
      end
    else
      -- tx fail (on one or both wires)
      -- TODO: want to manage them separately? sounds messy..
      node.fail_count = (node.fail_count or 0) + 1
      node.next_retransmit = math.random(1, 2^(node.fail_count+2))
    end
  else
    local col = entity.get_signal(colsig, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
    if col == 1 then -- got someone else's tx!
      local addr = entity.get_signal(addrsig, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
      if addr == node.address or addr == 0 then
        local protoid = entity.get_signal(protosig, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)
        local proto = protocols[protoid]
        if proto then
          local f = proto.receive
          if f then f(node) end
        end
      end
    end
    if node.next_retransmit then
      if node.next_retransmit == 1 then
        node.next_retransmit = nil
      else
        node.next_retransmit = node.next_retransmit - 1
      end
    else
      for _, proto in pairs(protocols) do
        local filters = proto.try_send(node)
        if filters then
          node.tx_last_tick = true
          -- try tx advertise...
          node.control.sections[1].filters = filters
          node.control.enabled = true
          break
        end
      end
    end
  end

  entity.combinator_description = string.format(
    "FeatherBridge %8X\ntxq:%i rxq:%i\nfail:%i retry:%i",
    node.address, #node.txbuffer, #storage.rconbuffer,
    node.fail_count or 0, node.next_retransmit or 0
  )
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