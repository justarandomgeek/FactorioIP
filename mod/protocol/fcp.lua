local protocol = require("protocol.protocol")

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

---@enum fcp_adv_flags
local adv_flags = {
  ip_tun = 1,
  map_trans = 2,
}

---@param dest int32
---@param flags fcp_adv_flags
---@return QueuedPacket
local function advertise(dest, flags)
  return {
    proto = 2,
    src_addr = storage.address,
    dest_addr = dest,
    retry_count = 4,
    payload = {
      protocol.signal_value(fcpmsgtype, 2),
      protocol.signal_value(fcpsubject, storage.address),
      protocol.signal_value(fcpflags, flags),
    }
  }
end

---@param address int32
---@return QueuedPacket
local function solicit(address)
  return {
    proto = 2,
    src_addr = storage.address,
    dest_addr = 0,
    retry_count = 2,
    payload = {
      protocol.signal_value(fcpmsgtype, 1),
      protocol.signal_value(fcpsubject, address),
    }
  }
end



---@type {[int32]: fun(router:FBRouterPort, packet:QueuedPacket)}
local msg_handlers = {
  -- solicit
  [1] = function(router, packet)
    local subject = protocol.find_signal(packet.payload, fcpsubject)
    if subject == storage.address or subject == 0 then
      -- got a solicit for me, so send an advertise back...
      router:advertise(packet.src_addr)
    end
  end,
}


protocol.handlers[2] = {
  dispatch = function(router, packet)
    local mtype = protocol.find_signal(packet.payload, fcpmsgtype)
    local handler = msg_handlers[mtype]
    if handler then
      handler(router, packet)
    end
  end,
  pack = function (packet)
    local mtype = protocol.find_signal(packet.payload, fcpmsgtype)
    local subject = protocol.find_signal(packet.payload, fcpsubject)
    if mtype == 2 then
      local flags = protocol.find_signal(packet.payload, fcpflags)
      return string.pack(">i4i4i4", mtype, subject, flags)
    else
      return string.pack(">i4i4", mtype, subject)
    end
  end,
  unpack = function (packet, data)
    if #data < 8 then return end
    local mtype, i = string.unpack(">i4", data, 1)
    local subject,flags = 0,0
    if mtype==2 then
      if #data < 12 then return end
      subject,flags,i = string.unpack(">i4i4", data, i)
    else
      subject,i = string.unpack(">i4", data, i)
    end

    packet.payload = {
      protocol.signal_value(fcpmsgtype, mtype),
      protocol.signal_value(fcpsubject, subject),
      protocol.signal_value(fcpflags, flags),
    }

    return packet
  end,
}

return {
  advertise = advertise,
  adv_flags = adv_flags,
  solicit = solicit,
}