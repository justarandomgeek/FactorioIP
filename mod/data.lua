local meld = require('meld')
local item_sounds = require("__base__.prototypes.item_sounds")

local tint = { r=0.4, b=1, g=0.6 }

data:extend{
  meld.meld(table.deepcopy(data.raw['constant-combinator']['constant-combinator']), {
    name = "featherbridge-combinator",
    icon = meld.delete(),
    icons = meld.overwrite{
      {
        icon = "__base__/graphics/icons/constant-combinator.png",
        tint = tint,
      }
    },
    minable = { result = "featherbridge-combinator" },
    fast_replaceable_group = meld.delete(),
    sprites = meld.overwrite(make_4way_animation_from_spritesheet({ layers =
      {
        {
          scale = 0.5,
          filename = "__base__/graphics/entity/combinator/constant-combinator.png",
          width = 114,
          height = 102,
          shift = util.by_pixel(0, 5),
          tint = tint,
        },
        {
          scale = 0.5,
          filename = "__base__/graphics/entity/combinator/constant-combinator-shadow.png",
          width = 98,
          height = 66,
          shift = util.by_pixel(8.5, 5.5),
          draw_as_shadow = true
        }
      }
    })),
    created_effect = meld.overwrite{
      type = "direct",
      action_delivery = {
        type = "instant",
        source_effects = {
          {
            type = "script",
            effect_id = "featherbridge-created",
          },
        }
      }
    },
  }),
  {
    type = "item",
    name = "featherbridge-combinator",
    icons = {
      {
        icon = "__base__/graphics/icons/constant-combinator.png",
        tint = tint,
      },
    },
    subgroup = "circuit-network",
    place_result = "featherbridge-combinator",
    order = "c[combinators]-d[featherbridge-combinator]",
    inventory_move_sound = item_sounds.combinator_inventory_move,
    pick_sound = item_sounds.combinator_inventory_pickup,
    drop_sound = item_sounds.combinator_inventory_move,
    stack_size = 50
  },
  {
    type = "recipe",
    name = "featherbridge-combinator",
    enabled = false,
    ingredients =
    {
      {type = "item", name = "copper-cable", amount = 5},
      {type = "item", name = "electronic-circuit", amount = 2}
    },
    results = {{type="item", name="featherbridge-combinator", amount=1}},
  },
  {
    type = "mod-data",
    name = "FeatherBridge-utility-constants",
    data_type = "FeatherBridgeUtilityConstants",
    ---@class (exact) FeatherBridgeUtilityConstants
    ---@field neighbor_expire_port MapTick
    ---@field neighbor_expire_record MapTick
    ---@field route_expire MapTick
    data = {
      neighbor_expire_port = 60*60,
      neighbor_expire_record = 15*60*60,
      route_expire = 15*60*60,
    }
  },
  {
    type = "mod-data",
    name = "FeatherBridge-Nixie-Plugin",
    data_type = "NixieTubesPluginData",
    ---@type NixieTubesPluginData
    data = {
      numberType = {
        FNPR = {
          code = [[
            --TODO: remote.call fetch this on first use from runtime protocol lib
            local protoname = {
              [1] = "IPV6",
              [2] = "FCP",
              [3] = "MAPRQ",
              [4] = "MAPTX",
              [5] = "MAPTXX",
            }
            return {
              name = "FNET PROTO",
              format = make_enum_format(protoname, "PROT "),
            }
          ]]
        }
      }
    }
  }
}

meld.meld(data.raw["technology"]["circuit-network"], {
  effects = meld.append({
    {
      type = "unlock-recipe",
      recipe = "featherbridge-combinator"
    }
  })
})