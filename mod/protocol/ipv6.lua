local protocol = require("protocol.protocol")

---@param packet string
---@return LogisticFilter[]
local function packet_to_filters(packet)
  ---@type LogisticFilter[]
  local filters = {
    protocol.signal_value(protocol.signals.colsig, 1),
    protocol.signal_value(protocol.signals.protosig, 1), --TODO: type on incoming packets? anything other than ipv6?
    --TODO: dest address
  }
  -- pre-allocate...
  filters[400] = nil

  local len = #packet
  
  for i = 1,len,4 do
    local n = string.unpack(">i4", packet, i)
    local sig = storage.id_to_signal[((i-1)/4)+1]
    local index = #filters+1
    filters[index] = protocol.signal_value(sig, n)
  end
  return filters
end

---@type FBProtocol
return {
  receive = function(node, net)
    if not (storage.rconbuffer and storage.signal_to_id) then return end
    -- read to rcon buffer
    local sigs = net.signals
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
  tx_good = function(node)
    -- drop from buffer
    table.remove(node.txbuffer, 1)
  end,
}