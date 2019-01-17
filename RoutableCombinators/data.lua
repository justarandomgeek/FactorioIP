require("util")
require("config")

-- Do some magic nice stuffs
data:extend(
{
	{
		type = "item-group",
		name = "routable-combinators-group",
		icon = "__routablecombinators__/graphics/tech.png",
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
		icon = "__routablecombinators__/graphics/icons/signal_srctick.png",
		icon_size = 32,
		subgroup = "virtual-signal-routablecombinators",
		order = "e[routablecombinators]-[1srctick]"
	},
	{
		type = "virtual-signal",
		name = "signal-srcid",
		icon = "__routablecombinators__/graphics/icons/signal_srcid.png",
		icon_size = 32,
		subgroup = "virtual-signal-routablecombinators",
		order = "e[routablecombinators]-[2srcid]"
	},
	{
		type = "virtual-signal",
		name = "signal-dstid",
		icon = "__routablecombinators__/graphics/icons/signal_dstid.png",
		icon_size = 32,
		subgroup = "virtual-signal-routablecombinators",
		order = "e[routablecombinators]-[3dstid]"
	},
	{
		type = "virtual-signal",
		name = "signal-localid",
		icon = "__routablecombinators__/graphics/icons/signal_localid.png",
		icon_size = 32,
		subgroup = "virtual-signal-routablecombinators",
		order = "e[routablecombinators]-[4localid]"
	},
}

-- TX Combinator
local tx = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
tx.name = TX_COMBINATOR_NAME
tx.minable.result = TX_COMBINATOR_NAME
data:extend{
	tx,
	{
		type = "item",
		name = TX_COMBINATOR_NAME,
		icon = tx.icon,
		icon_size = 32,
		flags = {"goes-to-quickbar"},
		subgroup = "signal-subgroup",
		place_result=TX_COMBINATOR_NAME,
		order = "a[items]-b["..TX_COMBINATOR_NAME.."]",
		stack_size = 50,
	},
	{
		type = "recipe",
		name = TX_COMBINATOR_NAME,
		enabled = true, -- TODO do this on a tech somewhere
		ingredients =
		{
			{"decider-combinator", 1},
			{"electronic-circuit", 50}
		},
		result = TX_COMBINATOR_NAME,
		requester_paste_multiplier = 1
	},
}

-- RX Combinator
local rx = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
rx.name = RX_COMBINATOR_NAME
rx.minable.result = RX_COMBINATOR_NAME
rx.item_slot_count = 500
data:extend{
	rx,
	{
		type = "item",
		name = RX_COMBINATOR_NAME,
		icon = rx.icon,
		icon_size = 32,
		flags = {"goes-to-quickbar"},
		subgroup = "signal-subgroup",
		place_result=RX_COMBINATOR_NAME,
		order = "a[items]-b["..RX_COMBINATOR_NAME.."]",
		stack_size = 50,
	},
	{
		type = "recipe",
		name = RX_COMBINATOR_NAME,
		enabled = true, -- TODO do this on a tech somewhere
		ingredients =
		{
			{"constant-combinator", 1},
			{"electronic-circuit", 3},
			{"advanced-circuit", 1}
		},
		result = RX_COMBINATOR_NAME,
		requester_paste_multiplier = 1
	},
}

-- ID Combinator
local id = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
id.name = ID_COMBINATOR_NAME
id.minable.result = ID_COMBINATOR_NAME
data:extend{
	id,
	{
		type = "item",
		name = ID_COMBINATOR_NAME,
		icon = id.icon,
		icon_size = 32,
		flags = {"goes-to-quickbar"},
		subgroup = "signal-subgroup",
		place_result=ID_COMBINATOR_NAME,
		order = "a[items]-b["..ID_COMBINATOR_NAME.."]",
		stack_size = 50,
	},
	{
		type = "recipe",
		name = ID_COMBINATOR_NAME,
		enabled = true, -- TODO do this on a tech somewhere
		ingredients =
		{
			{"constant-combinator", 1},
			{"electronic-circuit", 3},
			{"advanced-circuit", 1}
		},
		result = ID_COMBINATOR_NAME,
		requester_paste_multiplier = 1
	},
}



data:extend{
  {
  	type = "technology",
  	name = "routablecombinators",
    icon = "__routablecombinators__/graphics/tech.png",
    icon_size = 128,
  	unit = {
  		count=100,
      time=15,
      ingredients = {
          {"science-pack-1", 1,},
          {"science-pack-2", 1,},
        },
    },
    prerequisites = {"circuit-network"},
    effects = {
      {
        type = "unlock-recipe",
        recipe = TX_COMBINATOR_NAME,
      },
      {
        type = "unlock-recipe",
        recipe = RX_COMBINATOR_NAME,
      },
      {
        type = "unlock-recipe",
        recipe = ID_COMBINATOR_NAME,
      },
    },
    order = "a-d-e",
  },
}
