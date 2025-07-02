local protocol = require("protocol.protocol")
local bridge = require("bridge")

---@type SignalID
local fcpmsgtype = {
  type = "virtual",
  name = "signal-0"
}

---@type SignalID
local fcpsubject = {
  type = "virtual",
  name = "signal-1"
}

---@type SignalID
local fcpflags = {
  type = "virtual",
  name = "signal-2"
}

---@return LogisticFilter[]
local function advertise()
  return {
    protocol.signal_value(fcpmsgtype, 2),
    protocol.signal_value(fcpsubject, storage.address),
    protocol.signal_value(fcpflags, 3),
  }
end

---@param address int32
---@return LogisticFilter[]
local function solicit(address)
  return {
    protocol.signal_value(fcpmsgtype, 1),
    protocol.signal_value(fcpsubject, address),
  }
end



---@type {[int32]: fun(packet:QueuedPacket)}
local msg_handlers = {
  -- solicit
  [1] = function(packet)
    local subject = protocol.find_signal(packet.payload, fcpsubject)
    if subject == storage.address or subject == 0 then
      -- got a solicit for me, so send an advertise back...
      bridge.send({
        proto = 2,
        src_addr = storage.address,
        dest_addr = packet.src_addr,
        retry_count = 4,
        payload = advertise()
      }, storage.router)
    end
  end,
}


protocol.handlers[2] = {
  dispatch = function(packet)
    local mtype = protocol.find_signal(packet.payload, fcpmsgtype)
    local handler = msg_handlers[mtype]
    if handler then
      handler(packet)
    end
  end,
}

return {
  advertise = advertise,
  solicit = solicit,
}