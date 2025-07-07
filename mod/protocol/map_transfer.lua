local protocol = require("protocol.protocol")
local bridge = require("bridge")

-- map request
protocol.handlers[3] = {
  dispatch = function(router, packet)
    if packet.dest_addr == 0 then return end

    local mapid = protocol.find_signal(packet.payload, {type="entity", name="item-request-proxy"})
    if mapid ~= 0 then return end

    ---@type LogisticFilter[]
    local map_out = {}

    for i, signal in pairs(storage.id_to_signal) do
      map_out[#map_out+1] = protocol.signal_value(signal, i)
    end

    bridge.send({
      proto = 4,
      src_addr = storage.address,
      dest_addr = packet.src_addr,
      retry_count = 4,
      payload = map_out }, storage.router)
  end,
}


---@type {[QualityID]:{[SignalIDType]:{[string]:boolean}}}
local map_skip_list = {
  normal = {
    virtual = {
      ["signal-check"] = true,
      ["signal-info"] = true,
      ["signal-input"] = true,
      ["signal-output"] = true,
    },
    entity = {
      ["item-request-proxy"] = true,
    }
  }
}


---@param signal SignalID
---@return boolean?
local function map_skip(signal)
  local qual = map_skip_list[signal.quality or "normal"]
  if not qual then return end
  local stype = qual[signal.type or "item"]
  if not stype then return end
  return stype[signal.name]
end

-- map transfer
protocol.handlers[4] = {
  dispatch = function(router, packet)
    if packet.dest_addr == 0 then return end

    local mapid = protocol.find_signal(packet.payload, {type="entity", name="item-request-proxy"})
    if mapid ~= 0 then return end

    -- load new map
    local by_value = {}
    for _, signal in pairs(packet.payload) do
      if map_skip(signal.value --[[@as SignalID]]) then goto skip end
      local c = signal.min ---@cast c -?
      if not by_value[c] then by_value[c] = {} end
      by_value[c][#by_value[c]+1] = signal.value
      ::skip::
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
    helpers.write_file("featherbridge_map.txt", serpent.block(storage.id_to_signal))
  end,
}
