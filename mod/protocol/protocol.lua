
---@class FBProtocol
---@field receive fun(node:FBNode, net:LuaCircuitNetwork)
---@field forward? fun(node:FBNode, net:LuaCircuitNetwork)

---@class FBProtocolLib
return {
---@type {[string]:SignalFilter}
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
  ---@type {[int32]:FBProtocol}
  handlers = {

  }
}