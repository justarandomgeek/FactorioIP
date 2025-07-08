
---@class (exact) FBProtocol
---@field public dispatch fun(router:FBRouterPort, packet:QueuedPacket) # handle a packet dispatched from the switch to the Router port
---@field public pack? fun(packet:QueuedPacket):string? # pack a payload for efficient transmission to a peer; return nil to refuse pack and send raw
---@field public unpack? fun(packet:QueuedPacket, data:string):QueuedPacket? # packet has header already set, just fill in the payload; return nil to drop

---@class FBProtocolLib
return {
---@type {[string]:SignalID}
  signals = {
    collision = {
        type = "virtual",
        name = "signal-check"
    },
    protoid = {
        type = "virtual",
        name = "signal-info"
    },
    dest_addr = {
        type = "virtual",
        name = "signal-input"
    },
    src_addr = {
        type = "virtual",
        name = "signal-output"
    },
  },

  ---@param signal SignalID
  ---@param value int32
  ---@return LogisticFilter
  signal_value = function(signal, value)
    return {
      value = {
        type = signal.type or "item",
        name = signal.name,
        quality = signal.quality or "normal",
        comparator = "=",
      },
      min = value,
    }
  end,


  ---@param payload LogisticFilter[]
  ---@param signal SignalID
  ---@return int32
  find_signal = function (payload, signal)
    for _, filter in pairs(payload) do
      local sig = filter.value ---@cast sig -?
      if (sig.quality or "normal") == (signal.quality or "normal") and
          (sig.type or "item") == (signal.type or "item") and
          sig.name == signal.name then
        return filter.min
      end
    end
    return 0
  end,

  ---@type {[int32]:FBProtocol}
  handlers = {

  }
}