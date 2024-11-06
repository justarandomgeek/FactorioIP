local protocol = require("protocol.protocol")

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

---@param address int32
---@return LogisticFilter[]
local function advertise(address)
  return {
    protocol.signal_value(protocol.signals.collision, 1),
    protocol.signal_value(protocol.signals.protoid, 2),
    protocol.signal_value(fcpmsgtype, 2),
    protocol.signal_value(fcpsubject, address),
    protocol.signal_value(fcpflags, 1),
  }
end


---@param address int32
---@return LogisticFilter[]
local function solicit(address)
  return {
    protocol.signal_value(protocol.signals.collision, 1),
    protocol.signal_value(protocol.signals.protoid, 2),
    protocol.signal_value(fcpmsgtype, 1),
    protocol.signal_value(fcpsubject, address),
  }
end

protocol.handlers[2] = {
  receive = function(node, net)
    local mtype = net.get_signal(fcpmsgtype --[[@as SignalID]])
    if mtype == 1 then -- solicit
      local subject = net.get_signal(fcpsubject --[[@as SignalID]])
      if subject == storage.address or subject == 0 then
        -- got a solicit for me, so send an advertise back, and jump the line...
        table.insert(node.out_queue, 1, {
          dest_addr = 0,
          retry_count = 4,
          payload = advertise(storage.address)
        }--[[@as QueuedPacket]])
        node.fail_count = nil
        node.next_retransmit = nil
      end
    elseif mtype == 2 then -- advertise
      -- add or update a neighbor entry...
      local subject = net.get_signal(fcpsubject --[[@as SignalID]])
      local neighbor = storage.neighbors[subject]
      if neighbor then
        neighbor.bridge_port = node
        neighbor.last_seen = game.tick
      else
        neighbor = {
          address = subject,
          bridge_port = node,
          last_seen = game.tick,
          last_solicit = 0,
        }
        storage.neighbors[subject] = neighbor
      end
    end
  end,
}

return {
  advertise = advertise,
  solicit = solicit,
}