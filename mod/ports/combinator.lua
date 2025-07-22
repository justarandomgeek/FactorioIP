local protocol = require("protocol.protocol")
local bridge = require("bridge")

---@class (exact) FBCombinatorPort : FBBridgePort
---@field private entity LuaEntity
---@field private unit_number integer
---@field private control LuaConstantCombinatorControlBehavior
---@field private did_tx_last_tick boolean?
---@field private fail_count number?
---@field private next_retransmit number?
---@field private out_queue QueuedPacket[] # packets waiting to go out to circuit
local port={}

---@type metatable
local port_meta = {
    __index = port,
}

script.register_metatable("FBCombinatorPort", port_meta)

---@param ent LuaEntity
---@return FBCombinatorPort
local function new(ent)
  return setmetatable({
    entity = ent,
    unit_number = ent.unit_number,
    control = ent.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]],
    out_queue = {},
  }, port_meta)
end

---@private
---@param reason string
function port:disabled(reason)
  local entity = self.entity
  self.control.enabled = false
  entity.custom_status = {
    diode = defines.entity_status_diode.red,
    label = string.format("Disabled: %s", reason)
  }
  --TODO: locale all these string.formats
  entity.combinator_description = string.format("FeatherBridge %8X\nDisabled: %s", bit32.band(storage.address), reason)
end


local wire_tag = {
  [defines.wire_type.red] = "[img=item/red-wire]",
  [defines.wire_type.green] = "[img=item/green-wire]",
}

---@private
---@param net LuaCircuitNetwork
function port:active(net)
  local entity = self.entity
  if self.fail_count then
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
    bit32.band(storage.address), wire_tag[net.wire_type], net.network_id,
    #self.out_queue, self.fail_count or 0, self.next_retransmit or 0
  )
end

---@public
function port:on_tick()
  local entity = self.entity

  ---@type LuaCircuitNetwork?
  local net
  do
    local rnet = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local gnet = entity.get_circuit_network(defines.wire_connector_id.circuit_green)

    if rnet and gnet then
      self:disabled(string.format("Multiple Circuit Connections [img=item/red-wire]%i [img=item/green-wire]%i", rnet.network_id, gnet.network_id))
      return
    end
    net = rnet or gnet

    if not net then
      self:disabled("No Circuit Connection")
      return
    end
  end

  -- read collision check signal
  local col = net.get_signal(protocol.signals.collision)

  if self.did_tx_last_tick then
    self.did_tx_last_tick = nil
    self.control.enabled = false
    if (col == nil or col == 1) then
      -- tx ok
      table.remove(self.out_queue, 1)
      self.fail_count = nil
      self.next_retransmit = nil
    else
      -- tx fail
      local pending = self.out_queue[1]
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
        local fail_count = (self.fail_count or 0) + 1
        self.fail_count = fail_count
        self.next_retransmit = math.random(2^(fail_count), 2^(fail_count+2))
      else
        -- drop
        table.remove(self.out_queue, 1)
        self.fail_count = nil
        self.next_retransmit = nil
      end
    end
  else
    if col == 1 then -- got someone else's tx!
      local src = net.get_signal(protocol.signals.src_addr)
      local dest_addr = net.get_signal(protocol.signals.dest_addr)
      local protoid = net.get_signal(protocol.signals.protoid)
      local signals = net.signals
      ---@cast signals -?
      ---@type LogisticFilter[]
      local payload = {}
      for _, signal in pairs(signals) do
        payload[#payload+1] = protocol.signal_value(signal.signal, signal.count)
      end
      bridge.send({
        proto = protoid,
        src_addr = src,
        dest_addr = dest_addr,
        retry_count = 2,
        payload = payload,
      }, self)
    end

    -- do tx activity...
    if self.next_retransmit then
      if self.next_retransmit <= 1 then
        self.next_retransmit = nil
      else
        self.next_retransmit = self.next_retransmit - 1
      end
    else
      local out_packet = self.out_queue[1]
      if out_packet then
        -- try tx...
        self.did_tx_last_tick = true
        local control = self.control
        while control.sections_count > 2 do
          control.remove_section(3)
        end
        while control.sections_count < 2 do
          control.add_section()
        end
        control.sections[1].filters = {
          protocol.signal_value(protocol.signals.collision, 1),
          protocol.signal_value(protocol.signals.protoid, out_packet.proto),
          protocol.signal_value(protocol.signals.src_addr, out_packet.src_addr),
          protocol.signal_value(protocol.signals.dest_addr, out_packet.dest_addr),
        }
        control.sections[2].filters = out_packet.payload
        control.enabled = true
      end
    end
  end

  self:active(net)
end

---@public
function port:status()
  local status = {}
    if self.did_tx_last_tick then
      status[#status+1] = "did_tx"
    end
    if self.fail_count then
      status[#status+1] = string.format("fail %i retrans %i", self.fail_count, self.next_retransmit)
    end
    return string.format("node %i %s queue %i %s", self.unit_number, self.entity.gps_tag, #self.out_queue, table.concat(status, " "))
end

---@public
---@param packet QueuedPacket
function port:send(packet)
  local n = #self.out_queue+1
  if n > 20 then return end -- limit queue size
  self.out_queue[n] = packet
end

function port:valid()
  return self.entity.valid
end

function port:label()
  return string.format("%i", self.unit_number)
end

return new