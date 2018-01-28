signals = {}

for i = 259,320 do
  signals[#signals] = {
    type = "virtual-signal",
    name = "signal-"..i,
    icon = "__base__/graphics/icons/signal/signal_1.png",
    icon_size = 32,
    subgroup = "virtual-signal-number",
    order = "b[numbers]-["..i.."]"
  }
end

data:extend(signals)
