--the chest that a player put things in
INPUT_CHEST_NAME = "put-chest"
INPUT_CHEST_PICTURE_PATH = "__clusterio__/graphics/putChest.png"
INPUT_CHEST_ICON_SIZE = 32
INPUT_CHEST_ICON_PATH = "__clusterio__/graphics/icons/putChest.png"

--the chest that the player get things from
OUTPUT_CHEST_NAME = "get-chest"
OUTPUT_CHEST_PICTURE_PATH = "__clusterio__/graphics/getChest.png"
OUTPUT_CHEST_ICON_SIZE = 32
OUTPUT_CHEST_ICON_PATH = "__clusterio__/graphics/icons/getChest.png"

--the tank that a player put things in
INPUT_TANK_NAME = "put-tank"
INPUT_TANK_PICTURE_PATH = nil
INPUT_TANK_ICON_PATH = nil

--the tank that the player get things from
OUTPUT_TANK_NAME = "get-tank"
OUTPUT_TANK_PICTURE_PATH = nil
OUTPUT_TANK_ICON_PATH = nil

CRAFTING_FLUID_CATEGORY_NAME = "crafting-fluids"

--put electricty into this thing
INPUT_ELECTRICITY_NAME = "put-electricity"
INPUT_ELECTRICITY_PICTURE_PATH = nil
INPUT_ELECTRICITY_ICON_PATH = nil

--get electricity from this thing
OUTPUT_ELECTRICITY_NAME = "get-electricity"
OUTPUT_ELECTRICITY_PICTURE_PATH = nil
OUTPUT_ELECTRICITY_ICON_PATH = nil

--item name that electricity uses
ELECTRICITY_ITEM_NAME = "electricity"
ELECTRICITY_RATIO = 1000000 -- 1.000.000,  1 = 1MJ

MAX_RX_BUFFER_SIZE = 40 -- slightly more than one second
RX_COMBINATOR_NAME = "get-combinator"
TX_COMBINATOR_NAME = "put-combinator"
INV_COMBINATOR_NAME = "inventory-combinator"

OUTPUT_FILE = "output.txt"
ORDER_FILE  = "orders.txt"
TX_BUFFER_FILE = "txbuffer.txt"
FLOWS_FILE = "flows.txt"

MAX_FLUID_AMOUNT = 25000
TICKS_TO_COLLECT_REQUESTS = 40
TICKS_TO_FULFILL_REQUESTS = 20

ENTITY_TELEPORTATION_RESTRICTION = true
ENTITY_TELEPORTATION_RESTRICTION_RANGE = 200
