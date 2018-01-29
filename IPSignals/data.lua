local signals = {
  {
      type = "item-subgroup",
      name = "virtual-signal-ip",
      group = "signals",
      order = "zz"
    }

}

for i = 249,319 do
  table.insert(signals, {
    type = "virtual-signal",
    name = "signal-" .. i,
    icon = "__base__/graphics/icons/signal/signal_1.png",
    icon_size = 32,
    subgroup = "virtual-signal-ip",
    order = "zz[ip]-[" .. i .. "]"
  })
end

data:extend(signals)
