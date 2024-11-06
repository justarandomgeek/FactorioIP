local protocol = require("protocol.protocol")


protocol.handlers[1] = {
  receive = function(node, net)
    if not (storage.out_queue and storage.signal_to_id) then return end
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

    storage.out_queue[#storage.out_queue+1] = table.concat(packet_values)
  end,
}