local protocol = require("protocol.protocol")

local ipv6 = {}

protocol.handlers[1] = {
  dispatch = function(router, packet)
    local map = storage.signal_to_id
    if not map then return end
    if router.port == 0 then return end
    if not (router.player==0 or game.get_player(router.player).connected) then return end

    local packet_values = {}
    packet_values[400] = nil
    local top = 0

    for _, sig in pairs(packet.payload) do
      local signal = sig.value ---@cast signal -?
      local qmap = map[signal.quality or "normal"]
      if not qmap then goto continue end

      local tmap = qmap[signal.type or "item"]
      if not tmap then goto continue end

      local id = tmap[signal.name]
      if not id then goto continue end

      packet_values[id] = string.pack(">i4", sig.min)
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

    -- stick a gre header on the front...
    table.insert(packet_values, 1, string.pack(">I2I2", 0, 0x86dd))

    helpers.send_udp(storage.router.port, table.concat(packet_values), storage.router.player)
  end,
}

---@param packet string
---@return QueuedPacket packet
function ipv6.parse(packet)
  ---@type LogisticFilter[]
  local filters = {}
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
  
  local len = #packet
  
  for i = 1,len,4 do
    local n = string.unpack(">i4", packet, i)
    local sig = storage.id_to_signal[((i-1)/4)+1]
    filters[#filters+1] = protocol.signal_value(sig, n)
  end
  return {
    proto = 1,
    src_addr = storage.address,
    dest_addr = dest,
    retry_count = 4,
    payload = filters,
  }
end

return ipv6