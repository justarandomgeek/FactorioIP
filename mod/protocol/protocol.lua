return {
---@type {[string]:SignalFilter}
  signals = {
    colsig = {
        type = "virtual",
        name = "signal-check"
    },
    protosig = {
        type = "virtual",
        name = "signal-info"
    },
    addrsig = {
        type = "virtual",
        name = "signal-dot"
    },
  },
  ---@param signal SignalFilter
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
}