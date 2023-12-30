require("util")
require("config")

-- groups
data:extend(
{
  {
    type = "item-group",
    name = "routable-combinators-group",
    icon = "__RoutableCombinators__/graphics/tech.png",
    icon_size = 128,
    inventory_order = "f",
    order = "e"
  },
  {
    type = "item-subgroup",
    name = "signal-subgroup",
    group = "routable-combinators-group",
    order = "c"
  }
})


-- Virtual signals
data:extend{
  {
    type = "item-subgroup",
    name = "virtual-signal-routablecombinators",
    group = "routable-combinators-group",
    order = "e"
  },
  {
    type = "virtual-signal",
    name = "signal-srctick",
    icon = "__RoutableCombinators__/graphics/icons/signal_srctick.png",
    icon_size = 32,
    subgroup = "virtual-signal-routablecombinators",
    order = "e[routablecombinators]-1[srctick]"
  },
  {
    type = "virtual-signal",
    name = "signal-srcid",
    icon = "__RoutableCombinators__/graphics/icons/signal_srcid.png",
    icon_size = 32,
    subgroup = "virtual-signal-routablecombinators",
    order = "e[routablecombinators]-2[srcid]"
  },
  {
    type = "virtual-signal",
    name = "signal-dstid",
    icon = "__RoutableCombinators__/graphics/icons/signal_dstid.png",
    icon_size = 32,
    subgroup = "virtual-signal-routablecombinators",
    order = "e[routablecombinators]-3[dstid]"
  },
  {
    type = "virtual-signal",
    name = "signal-localid",
    icon = "__RoutableCombinators__/graphics/icons/signal_localid.png",
    icon_size = 32,
    subgroup = "virtual-signal-routablecombinators",
    order = "e[routablecombinators]-4[localid]"
  },
}

local function makeItemAndRecipe(ent,ingredients)  
  data:extend{
    ent,
    {
      type = "item",
      name = ent.name,
      icon = ent.icon,
      icon_size = ent.icon_size,
      subgroup = "signal-subgroup",
      place_result=ent.name,
      order = "a[items]-b["..ent.name.."]",
      stack_size = 50,
    },
    {
      type = "recipe",
      name = ent.name,
      enabled = false,
      ingredients = ingredients,
      result = ent.name,
      requester_paste_multiplier = 1
    },
  }
end


-- TX Combinator
local tx = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
tx.name = TX_COMBINATOR_NAME
tx.minable.result = TX_COMBINATOR_NAME
makeItemAndRecipe(tx, {
  {"decider-combinator", 1},
  {"electronic-circuit", 50}
})

-- RX and ID Combinators
local function copyCC(name,slotcount)
  local rx = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  rx.name = name
  rx.minable.result = name
  rx.item_slot_count = slotcount
  makeItemAndRecipe(rx, {
    {"constant-combinator", 1},
    {"electronic-circuit", 3},
    {"advanced-circuit", 1}
  })
end

copyCC(RX_COMBINATOR_NAME,settings.startup["routablecombinators-rx-frame-size"].value)
copyCC(ID_COMBINATOR_NAME,1)

-- technology
data:extend{
  {
    type = "technology",
    name = "routablecombinators",
    icon = "__RoutableCombinators__/graphics/tech.png",
    icon_size = 128,
    unit = {
      count=100,
      time=15,
      ingredients = {
          {"automation-science-pack", 1,},
          {"logistic-science-pack", 1,},
        },
    },
    prerequisites = {"circuit-network"},
    effects = {
      { type = "unlock-recipe", recipe = TX_COMBINATOR_NAME, },
      { type = "unlock-recipe", recipe = RX_COMBINATOR_NAME, },
      { type = "unlock-recipe", recipe = ID_COMBINATOR_NAME, },
    },
    order = "a-d-e",
  },
}

-- padding signals for IP
if settings.startup["routablecombinators-enable-padding"].value then
  local paddingsignals = {
  {
    type = "item-subgroup",
    name = "virtual-signal-padding",
    group = "routable-combinators-group",
    order = "zz"
    }
  }

  local start = settings.startup["routablecombinators-start-padding"].value
  local stop  = settings.startup["routablecombinators-stop-padding"].value

  if start < stop then
    for i = start,stop do
      table.insert(paddingsignals, {
        type = "virtual-signal",
        name = "signal-" .. i,
        icon = "__base__/graphics/icons/signal/signal_1.png",
        icon_size = 32,
        subgroup = "virtual-signal-padding",
        localised_name = {"virtual-signal-name.signal-padding-n",i},
        order = "e[routablecombinators]-z[padding]-[" .. i .. "]"
      })
    end
  else
    log(("start %d >= stop $d"):format(start,stop))
  end
  data:extend(paddingsignals)
end
