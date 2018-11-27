require("util")
require("config")

-- Do some magic nice stuffs
data:extend(
{
	{
		type = "item-group",
		name = "test-group",
		icon = "__routablecombinators__/graphics/tech.png",
		icon_size = 128,
		inventory_order = "f",
		order = "e"
	},
	{
		type = "item-subgroup",
		name = "signal-subgroup",
		group = "test-group",
		order = "c"
	}
})


-- Virtual signals
data:extend{
	{
		type = "item-subgroup",
		name = "virtual-signal-clusterio",
		group = "signals",
		order = "e"
	},
	{
		type = "virtual-signal",
		name = "signal-srctick",
		icon = "__routablecombinators__/graphics/icons/signal_srctick.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[1srctick]"
	},
	{
		type = "virtual-signal",
		name = "signal-srcid",
		icon = "__routablecombinators__/graphics/icons/signal_srcid.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[2srcid]"
	},
	{
		type = "virtual-signal",
		name = "signal-dstid",
		icon = "__routablecombinators__/graphics/icons/signal_dstid.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[3dstid]"
	},
	{
		type = "virtual-signal",
		name = "signal-localid",
		icon = "__routablecombinators__/graphics/icons/signal_localid.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[4localid]"
	},
	{
		type = "virtual-signal",
		name = "signal-unixtime",
		icon = "__routablecombinators__/graphics/icons/signal_unixtime.png",
		icon_size = 32,
		subgroup = "virtual-signal-clusterio",
		order = "e[clusterio]-[5unixtime]"
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


data:extend(
        {
            {
                type = "sprite",
                name = "clusterio",
                filename = "__routablecombinators__/graphics/icons/clusterio.png",
                priority = "medium",
                width = 128,
                height = 128,
                flags = { "icon" }
            }

        }
)
