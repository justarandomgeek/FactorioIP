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
local function fcp_advertise(address)
  return {
    protocol.signal_value(protocol.signals.colsig, 1),
    protocol.signal_value(protocol.signals.protosig, 2),
    --TODO: send specifically to requester when responding to solicit
    -- but also just do this periodically anyway.
    protocol.signal_value(fcpmsgtype, 2),
    protocol.signal_value(fcpsubject, address),
    protocol.signal_value(fcpflags, 1),
  }
end


---@type FBProtocol
return {
  receive = function(node, net)
    local mtype = net.get_signal(fcpmsgtype)
    if mtype == 1 then -- solicit
      local subject = net.get_signal(fcpsubject)
      if subject == storage.address or subject == 0 then
        -- got a solicit for me, so send an advertise back...
        node.fcp_send_advertise = true
        node.fail_count = nil
        node.next_retransmit = nil
      end
    end
  end,
  try_send = function(node)
    if node.fcp_send_advertise then
      return fcp_advertise(storage.address)
    end
  end,
  tx_good = function(node)
    if node.fcp_send_advertise then
      node.fcp_send_advertise = nil
    end
  end,
}