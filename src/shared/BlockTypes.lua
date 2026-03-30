-- VC CRAFT Block Types and Definitions
local BlockTypes = {}

-- Block IDs
local B = {
	AIR = 0, GRASS = 1, DIRT = 2, STONE = 3, SAND = 4, WATER = 5, BED = 6,
	OLOG = 7, OLVS = 8, BLOG = 9, BLVS = 10, SLOG = 11, SLVS = 12,
	SNOW = 13, COB = 14, SSTON = 15, PLNK = 16, GLASS = 17, GRAV = 18,
	CLAY = 19, RSAND = 20, MUD = 21, CACT = 22, DEEP = 23,
	COAL = 24, IRON = 25, GOLD = 26, DIAM = 27, MOSS = 28,
	BRK = 29, SBK = 30, DLOG = 31, DLVS = 32, JLOG = 33, JLVS = 34,
	ALOG = 35, ALVS = 36, CRFT = 37, FURN = 38, CHST = 39, ICE = 40,
	STICK = 41, COAL_I = 42, IRON_I = 43, WPICK = 44, SPICK = 45, WSWD = 46,
	-- VC World blocks
	ASPHALT = 47, SIDEWALK = 48, CONCRETE = 49, STUCCO = 50, CONDO_WALL = 51,
	ROOF_TILE = 52, DRY_GRASS = 53, CRACK_PAVE = 54, STATUE_STONE = 55,
	BRONZE = 56, METAL_PANEL = 57, GLASS_TOWER = 58, NEON_BLK = 59,
	CITY_RUBBLE = 60, SHIP_TIMBER = 61, BARNACLE_WOOD = 62, SAIL_BLK = 63,
	MARBLE = 64, SEA_MARBLE = 65, COLUMN_BLK = 66, TEMPLE_STONE = 67,
	NICSHADE_LOG = 68, NICSHADE_LVS = 69, GLOW_FLOWER = 70, VINE_STONE = 71,
	CANYON_STONE = 72, MONUMENT_STN = 73, RUSTED_METAL = 74, GLOW_CRYSTAL = 75,
	DARK_PANEL = 76, SIGNAL_STONE = 77, RAIL_BLK = 78, RAIL_TIE = 79,
	PLATFORM_BLK = 80, SCHOOL_WALL = 81, LOCKER_BLK = 82, GYM_FLOOR = 83,
	BOARDWALK = 84, RESORT_WALL = 85, POOL_TILE = 86, CABIN_WALL = 87,
	TRAIL_STONE = 88, CHAPEL_STONE = 89, SIDING = 90, SHINGLE = 91,
	FENCE_BLK = 92, DRIVEWAY = 93, WATCHER_SAND = 94, TOWER_BRICK = 95,
	ANCIENT_METAL = 96, PIRATE_PLNK = 97, CORAL_PINK = 98, CORAL_BLUE = 99,
	CORAL_YELLOW = 100, KELP = 101, SEA_LANTERN = 102,
	RAIL_IRON = 103, RAIL_POWERED = 104, RAIL_BED = 105,
	TALL_GRASS = 106, FLOWER_RED = 107, FLOWER_BLUE = 108, FLOWER_YELLOW = 109,
	SHRUB = 110, REED = 111, FERN = 112, LAVA = 113,
	STAIR_COB = 114, STAIR_PLNK = 115, STAIR_BRK = 116, STAIR_SBK = 117,
	STAIR_STONE = 118, STAIR_MARBLE = 119, LADDER = 120,
	BASALT = 121, ASH_STONE = 122, SCORCHED = 123, OBSIDIAN = 124,
	LOCKER2 = 125, BOOTH_SEAT = 126, CABINET = 127, NEON_TRIM = 128,
	CARPET = 129, COUNTER_TOP = 130, MENU_BOARD = 131,
	REDWOOD_LOG = 132, REDWOOD_LVS = 133,
	WATER_BUCKET = 134, LAVA_BUCKET = 135,
	DOOR_OAK_C = 136, DOOR_OAK_O = 137, DOOR_IRON_C = 138, DOOR_IRON_O = 139,
	DOOR_DARK_C = 140, DOOR_DARK_O = 141,
	DESK = 142, SHELF = 143, TILE_FLOOR = 144, CARPET_RED = 145,
	DUNGEON_KEY = 146,
	-- Food & consumables
	APPLE = 147, WHEAT = 148, BREAD = 149,
	MEAT_RAW = 150, MEAT_COOKED = 151,
	-- Missing ore product
	GOLD_I = 152,
}

BlockTypes.B = B

-- Block definitions: name, solid, transparent, liquid, hardness, dropId, stackSize
-- {name, solid, transparent, liquid, hardness, dropId, stackSize}
local BD = {}

local function db(id, nm, opts)
	opts = opts or {}
	BD[id] = {
		name = nm,
		solid = opts.s ~= false,         -- default true
		transparent = opts.t == true,     -- default false
		liquid = opts.l == true,          -- default false
		hardness = opts.h or 1,           -- default 1
		dropId = opts.d or id,            -- default self
		stackSize = opts.st or 64,        -- default 64
		hunger = opts.hunger or 0,        -- hunger points restored (0 = not food)
	}
end

-- Standard blocks
db(B.AIR, "Air", {s=false, t=true})
db(B.GRASS, "Grass Block", {h=0.6})
db(B.DIRT, "Dirt", {h=0.5})
db(B.STONE, "Stone", {h=1.5, d=B.COB})
db(B.SAND, "Sand", {h=0.5})
db(B.WATER, "Water", {s=false, t=true, l=true, h=-1})
db(B.BED, "Bedrock", {h=-1})
db(B.OLOG, "Oak Log", {h=2})
db(B.OLVS, "Oak Leaves", {h=0.2, t=true, d=B.APPLE})
db(B.BLOG, "Birch Log", {h=2})
db(B.BLVS, "Birch Leaves", {h=0.2, t=true})
db(B.SLOG, "Spruce Log", {h=2})
db(B.SLVS, "Spruce Leaves", {h=0.2, t=true})
db(B.SNOW, "Snow", {h=0.3})
db(B.COB, "Cobblestone", {h=1.5})
db(B.SSTON, "Sandstone", {h=1.2})
db(B.PLNK, "Oak Planks", {h=1.5})
db(B.GLASS, "Glass", {h=0.3, t=true, d=B.AIR})
db(B.GRAV, "Gravel", {h=0.6})
db(B.CLAY, "Clay", {h=0.6})
db(B.RSAND, "Red Sand", {h=0.5})
db(B.MUD, "Mud", {h=0.5})
db(B.CACT, "Cactus", {h=0.4})
db(B.DEEP, "Deepslate", {h=2})
db(B.COAL, "Coal Ore", {h=1.8, d=B.COAL_I})
db(B.IRON, "Iron Ore", {h=2.2})
db(B.GOLD, "Gold Ore", {h=2.5})
db(B.DIAM, "Diamond Ore", {h=3})
db(B.MOSS, "Mossy Stone", {h=1.5})
db(B.BRK, "Bricks", {h=2})
db(B.SBK, "Stone Bricks", {h=1.5})
db(B.DLOG, "Dark Oak Log", {h=2})
db(B.DLVS, "Dark Leaves", {h=0.2, t=true})
db(B.JLOG, "Jungle Log", {h=2})
db(B.JLVS, "Jungle Leaves", {h=0.2, t=true})
db(B.ALOG, "Acacia Log", {h=2})
db(B.ALVS, "Acacia Leaves", {h=0.2, t=true})
db(B.CRFT, "Crafting Table", {h=1.5})
db(B.FURN, "Furnace", {h=2})
db(B.CHST, "Chest", {h=1.5})
db(B.ICE, "Ice", {h=0.5, t=true})
db(B.STICK, "Stick", {s=false, t=true, st=64})
db(B.COAL_I, "Coal", {s=false, t=true, st=64})
db(B.IRON_I, "Iron Ingot", {s=false, t=true, st=64})
db(B.WPICK, "Wood Pickaxe", {s=false, t=true, st=1})
db(B.SPICK, "Stone Pickaxe", {s=false, t=true, st=1})
db(B.WSWD, "Wood Sword", {s=false, t=true, st=1})

-- VC World blocks
db(B.ASPHALT, "Asphalt", {h=1.5})
db(B.SIDEWALK, "Sidewalk", {h=1.2})
db(B.CONCRETE, "Concrete", {h=2})
db(B.STUCCO, "Stucco Wall", {h=1.5})
db(B.CONDO_WALL, "Condo Wall", {h=1.5})
db(B.ROOF_TILE, "Roof Tile", {h=1})
db(B.DRY_GRASS, "Dry Grass", {h=0.5})
db(B.CRACK_PAVE, "Cracked Pavement", {h=1})
db(B.STATUE_STONE, "Statue Stone", {h=3})
db(B.BRONZE, "Bronze Block", {h=2.5})
db(B.METAL_PANEL, "Metal Panel", {h=2})
db(B.GLASS_TOWER, "Tower Glass", {h=0.5, t=true})
db(B.NEON_BLK, "Neon Block", {h=1})
db(B.CITY_RUBBLE, "City Rubble", {h=1})
db(B.SHIP_TIMBER, "Ship Timber", {h=1.5})
db(B.BARNACLE_WOOD, "Barnacle Wood", {h=1.5})
db(B.SAIL_BLK, "Sail Block", {h=0.3})
db(B.MARBLE, "Marble", {h=2})
db(B.SEA_MARBLE, "Sea Marble", {h=2})
db(B.COLUMN_BLK, "Column Block", {h=2.5})
db(B.TEMPLE_STONE, "Temple Stone", {h=2})
db(B.NICSHADE_LOG, "Nicshade Log", {h=2})
db(B.NICSHADE_LVS, "Nicshade Leaves", {h=0.2, t=true})
db(B.GLOW_FLOWER, "Glow Flower", {h=0.2, t=true})
db(B.VINE_STONE, "Vine Stone", {h=1.5})
db(B.CANYON_STONE, "Canyon Stone", {h=2})
db(B.MONUMENT_STN, "Monument Stone", {h=3})
db(B.RUSTED_METAL, "Rusted Metal", {h=2})
db(B.GLOW_CRYSTAL, "Glow Crystal", {h=1, t=true})
db(B.DARK_PANEL, "Dark Panel", {h=2})
db(B.SIGNAL_STONE, "Signal Stone", {h=2})
db(B.RAIL_BLK, "Rail", {h=0.5})
db(B.RAIL_TIE, "Rail Tie", {h=1})
db(B.PLATFORM_BLK, "Platform", {h=1.5})
db(B.SCHOOL_WALL, "School Wall", {h=1.5})
db(B.LOCKER_BLK, "Locker", {h=1})
db(B.GYM_FLOOR, "Gym Floor", {h=1})
db(B.BOARDWALK, "Boardwalk", {h=1})
db(B.RESORT_WALL, "Resort Wall", {h=1.5})
db(B.POOL_TILE, "Pool Tile", {h=1})
db(B.CABIN_WALL, "Cabin Wall", {h=1.5})
db(B.TRAIL_STONE, "Trail Stone", {h=1})
db(B.CHAPEL_STONE, "Chapel Stone", {h=2})
db(B.SIDING, "House Siding", {h=1.5})
db(B.SHINGLE, "Roof Shingle", {h=1})
db(B.FENCE_BLK, "Fence", {h=1})
db(B.DRIVEWAY, "Driveway", {h=1})
db(B.WATCHER_SAND, "Watcher Sand", {h=0.5})
db(B.TOWER_BRICK, "Tower Brick", {h=2})
db(B.ANCIENT_METAL, "Ancient Metal", {h=2.5})
db(B.PIRATE_PLNK, "Pirate Planks", {h=1.5})
db(B.CORAL_PINK, "Pink Coral", {h=0.3})
db(B.CORAL_BLUE, "Blue Coral", {h=0.3})
db(B.CORAL_YELLOW, "Yellow Coral", {h=0.3})
db(B.KELP, "Kelp", {h=0.2, t=true, s=false})
db(B.SEA_LANTERN, "Sea Lantern", {h=1})
db(B.RAIL_IRON, "Iron Rail", {h=0.5, s=false, t=true})
db(B.RAIL_POWERED, "Powered Rail", {h=0.5, s=false, t=true})
db(B.RAIL_BED, "Rail Bed", {h=1, s=false, t=true})
db(B.TALL_GRASS, "Tall Grass", {h=0.1, s=false, t=true, d=B.WHEAT})
db(B.FLOWER_RED, "Red Flower", {h=0.1, s=false, t=true})
db(B.FLOWER_BLUE, "Blue Flower", {h=0.1, s=false, t=true})
db(B.FLOWER_YELLOW, "Yellow Flower", {h=0.1, s=false, t=true})
db(B.SHRUB, "Shrub", {h=0.2, s=false, t=true})
db(B.REED, "Reed", {h=0.2, s=false, t=true})
db(B.FERN, "Fern", {h=0.1, s=false, t=true})
db(B.LAVA, "Lava", {s=false, t=true, l=true, h=-1})
db(B.STAIR_COB, "Cobblestone Stairs", {h=1.5})
db(B.STAIR_PLNK, "Oak Plank Stairs", {h=1})
db(B.STAIR_BRK, "Brick Stairs", {h=2})
db(B.STAIR_SBK, "Stone Brick Stairs", {h=1.5})
db(B.STAIR_STONE, "Stone Stairs", {h=1.5})
db(B.STAIR_MARBLE, "Marble Stairs", {h=2})
db(B.LADDER, "Ladder", {h=0.5, s=false, t=true})
db(B.BASALT, "Basalt", {h=2})
db(B.ASH_STONE, "Ash Stone", {h=1.5})
db(B.SCORCHED, "Scorched Rock", {h=2})
db(B.OBSIDIAN, "Obsidian", {h=3})
db(B.LOCKER2, "Locker", {h=1})
db(B.BOOTH_SEAT, "Booth Seat", {h=1})
db(B.CABINET, "Cabinet", {h=1})
db(B.NEON_TRIM, "Neon Trim", {h=1})
db(B.CARPET, "Carpet", {h=0.5, s=false, t=true})
db(B.COUNTER_TOP, "Counter Top", {h=1.5})
db(B.MENU_BOARD, "Menu Board", {h=1})
db(B.REDWOOD_LOG, "Redwood Log", {h=2.5})
db(B.REDWOOD_LVS, "Redwood Leaves", {h=0.2, t=true})
db(B.WATER_BUCKET, "Water Bucket", {s=false, t=true, st=1})
db(B.LAVA_BUCKET, "Lava Bucket", {s=false, t=true, st=1})
db(B.DOOR_OAK_C, "Oak Door", {h=1.5})
db(B.DOOR_OAK_O, "Oak Door (Open)", {h=0.5, s=false, t=true})
db(B.DOOR_IRON_C, "Iron Door", {h=2})
db(B.DOOR_IRON_O, "Iron Door (Open)", {h=0.5, s=false, t=true})
db(B.DOOR_DARK_C, "Dark Door", {h=1.5})
db(B.DOOR_DARK_O, "Dark Door (Open)", {h=0.5, s=false, t=true})
db(B.DESK, "Desk", {h=1})
db(B.SHELF, "Bookshelf", {h=1.5})
db(B.TILE_FLOOR, "Tile Floor", {h=1})
db(B.CARPET_RED, "Red Carpet", {h=0.5, s=false, t=true})
db(B.DUNGEON_KEY, "Dungeon Key", {s=false, t=true, st=1})
-- Food items (s=false so they don't render as blocks)
db(B.APPLE,       "Apple",        {s=false, t=true, st=64, hunger=4})
db(B.WHEAT,       "Wheat",        {s=false, t=true, st=64})
db(B.BREAD,       "Bread",        {s=false, t=true, st=64, hunger=5})
db(B.MEAT_RAW,    "Raw Beef",     {s=false, t=true, st=64, hunger=2})
db(B.MEAT_COOKED, "Cooked Beef",  {s=false, t=true, st=64, hunger=8})
-- Ore products
db(B.GOLD_I,      "Gold Ingot",   {s=false, t=true, st=64})

BlockTypes.BD = BD

-- Block colors for rendering (Color3 values)
-- Maps block ID to {top, side, bottom} colors
local BC = {}
BC[B.GRASS]        = {Color3.fromRGB(58, 152, 40),  Color3.fromRGB(139, 107, 58), Color3.fromRGB(139, 107, 58)}
BC[B.DIRT]         = {Color3.fromRGB(139, 107, 58),  Color3.fromRGB(139, 107, 58), Color3.fromRGB(139, 107, 58)}
BC[B.STONE]        = {Color3.fromRGB(112, 116, 120), Color3.fromRGB(112, 116, 120), Color3.fromRGB(112, 116, 120)}
BC[B.SAND]         = {Color3.fromRGB(219, 200, 130), Color3.fromRGB(219, 200, 130), Color3.fromRGB(219, 200, 130)}
BC[B.WATER]        = {Color3.fromRGB(26, 80, 144),   Color3.fromRGB(26, 80, 144),  Color3.fromRGB(26, 80, 144)}
BC[B.BED]          = {Color3.fromRGB(34, 34, 34),    Color3.fromRGB(34, 34, 34),   Color3.fromRGB(34, 34, 34)}
BC[B.OLOG]         = {Color3.fromRGB(158, 126, 78),  Color3.fromRGB(107, 72, 38),  Color3.fromRGB(158, 126, 78)}
BC[B.OLVS]         = {Color3.fromRGB(58, 120, 40),   Color3.fromRGB(58, 120, 40),  Color3.fromRGB(58, 120, 40)}
BC[B.BLOG]         = {Color3.fromRGB(216, 208, 192), Color3.fromRGB(216, 208, 192), Color3.fromRGB(216, 208, 192)}
BC[B.BLVS]         = {Color3.fromRGB(100, 160, 80),  Color3.fromRGB(100, 160, 80), Color3.fromRGB(100, 160, 80)}
BC[B.SLOG]         = {Color3.fromRGB(60, 42, 26),    Color3.fromRGB(60, 42, 26),   Color3.fromRGB(60, 42, 26)}
BC[B.SLVS]         = {Color3.fromRGB(40, 70, 45),    Color3.fromRGB(40, 70, 45),   Color3.fromRGB(40, 70, 45)}
BC[B.SNOW]         = {Color3.fromRGB(238, 244, 248), Color3.fromRGB(238, 244, 248), Color3.fromRGB(238, 244, 248)}
BC[B.COB]          = {Color3.fromRGB(114, 114, 114), Color3.fromRGB(114, 114, 114), Color3.fromRGB(114, 114, 114)}
BC[B.SSTON]        = {Color3.fromRGB(196, 170, 106), Color3.fromRGB(196, 170, 106), Color3.fromRGB(196, 170, 106)}
BC[B.PLNK]         = {Color3.fromRGB(176, 136, 72),  Color3.fromRGB(176, 136, 72), Color3.fromRGB(176, 136, 72)}
BC[B.GLASS]        = {Color3.fromRGB(180, 220, 250), Color3.fromRGB(180, 220, 250), Color3.fromRGB(180, 220, 250)}
BC[B.GRAV]         = {Color3.fromRGB(106, 106, 106), Color3.fromRGB(106, 106, 106), Color3.fromRGB(106, 106, 106)}
BC[B.CLAY]         = {Color3.fromRGB(144, 152, 168), Color3.fromRGB(144, 152, 168), Color3.fromRGB(144, 152, 168)}
BC[B.RSAND]        = {Color3.fromRGB(196, 112, 48),  Color3.fromRGB(196, 112, 48), Color3.fromRGB(196, 112, 48)}
BC[B.MUD]          = {Color3.fromRGB(74, 56, 40),    Color3.fromRGB(74, 56, 40),   Color3.fromRGB(74, 56, 40)}
BC[B.CACT]         = {Color3.fromRGB(42, 122, 42),   Color3.fromRGB(42, 122, 42),  Color3.fromRGB(42, 122, 42)}
BC[B.DEEP]         = {Color3.fromRGB(58, 58, 66),    Color3.fromRGB(58, 58, 66),   Color3.fromRGB(58, 58, 66)}
BC[B.COAL]         = {Color3.fromRGB(100, 100, 100), Color3.fromRGB(100, 100, 100), Color3.fromRGB(100, 100, 100)}
BC[B.IRON]         = {Color3.fromRGB(140, 130, 120), Color3.fromRGB(140, 130, 120), Color3.fromRGB(140, 130, 120)}
BC[B.GOLD]         = {Color3.fromRGB(200, 180, 80),  Color3.fromRGB(200, 180, 80), Color3.fromRGB(200, 180, 80)}
BC[B.DIAM]         = {Color3.fromRGB(74, 240, 232),  Color3.fromRGB(100, 120, 130), Color3.fromRGB(100, 120, 130)}
BC[B.MOSS]         = {Color3.fromRGB(96, 112, 96),   Color3.fromRGB(96, 112, 96),  Color3.fromRGB(96, 112, 96)}
BC[B.BRK]          = {Color3.fromRGB(155, 64, 64),   Color3.fromRGB(155, 64, 64),  Color3.fromRGB(155, 64, 64)}
BC[B.SBK]          = {Color3.fromRGB(114, 114, 114), Color3.fromRGB(114, 114, 114), Color3.fromRGB(114, 114, 114)}
BC[B.DLOG]         = {Color3.fromRGB(42, 26, 10),    Color3.fromRGB(42, 26, 10),   Color3.fromRGB(42, 26, 10)}
BC[B.DLVS]         = {Color3.fromRGB(30, 60, 20),    Color3.fromRGB(30, 60, 20),   Color3.fromRGB(30, 60, 20)}
BC[B.JLOG]         = {Color3.fromRGB(90, 74, 42),    Color3.fromRGB(90, 74, 42),   Color3.fromRGB(90, 74, 42)}
BC[B.JLVS]         = {Color3.fromRGB(40, 100, 40),   Color3.fromRGB(40, 100, 40),  Color3.fromRGB(40, 100, 40)}
BC[B.ALOG]         = {Color3.fromRGB(106, 106, 106), Color3.fromRGB(106, 106, 106), Color3.fromRGB(106, 106, 106)}
BC[B.ALVS]         = {Color3.fromRGB(80, 120, 40),   Color3.fromRGB(80, 120, 40),  Color3.fromRGB(80, 120, 40)}
BC[B.CRFT]         = {Color3.fromRGB(160, 128, 80),  Color3.fromRGB(160, 128, 80), Color3.fromRGB(176, 136, 72)}
BC[B.FURN]         = {Color3.fromRGB(112, 116, 120), Color3.fromRGB(100, 100, 100), Color3.fromRGB(112, 116, 120)}
BC[B.CHST]         = {Color3.fromRGB(138, 96, 32),   Color3.fromRGB(138, 96, 32),  Color3.fromRGB(138, 96, 32)}
BC[B.ICE]          = {Color3.fromRGB(138, 196, 232), Color3.fromRGB(138, 196, 232), Color3.fromRGB(138, 196, 232)}

-- VC World block colors
BC[B.ASPHALT]      = {Color3.fromRGB(46, 46, 50),    Color3.fromRGB(46, 46, 50),   Color3.fromRGB(46, 46, 50)}
BC[B.SIDEWALK]     = {Color3.fromRGB(187, 184, 172), Color3.fromRGB(187, 184, 172), Color3.fromRGB(187, 184, 172)}
BC[B.CONCRETE]     = {Color3.fromRGB(154, 154, 152), Color3.fromRGB(154, 154, 152), Color3.fromRGB(154, 154, 152)}
BC[B.STUCCO]       = {Color3.fromRGB(216, 200, 168), Color3.fromRGB(216, 200, 168), Color3.fromRGB(216, 200, 168)}
BC[B.CONDO_WALL]   = {Color3.fromRGB(192, 176, 144), Color3.fromRGB(192, 176, 144), Color3.fromRGB(192, 176, 144)}
BC[B.ROOF_TILE]    = {Color3.fromRGB(139, 69, 19),   Color3.fromRGB(139, 69, 19),  Color3.fromRGB(139, 69, 19)}
BC[B.DRY_GRASS]    = {Color3.fromRGB(139, 136, 96),  Color3.fromRGB(139, 136, 96), Color3.fromRGB(139, 136, 96)}
BC[B.CRACK_PAVE]   = {Color3.fromRGB(136, 136, 132), Color3.fromRGB(136, 136, 132), Color3.fromRGB(136, 136, 132)}
BC[B.STATUE_STONE] = {Color3.fromRGB(176, 168, 152), Color3.fromRGB(176, 168, 152), Color3.fromRGB(176, 168, 152)}
BC[B.BRONZE]       = {Color3.fromRGB(139, 105, 20),  Color3.fromRGB(139, 105, 20), Color3.fromRGB(139, 105, 20)}
BC[B.METAL_PANEL]  = {Color3.fromRGB(94, 94, 104),   Color3.fromRGB(94, 94, 104),  Color3.fromRGB(94, 94, 104)}
BC[B.GLASS_TOWER]  = {Color3.fromRGB(70, 130, 180),  Color3.fromRGB(70, 130, 180), Color3.fromRGB(70, 130, 180)}
BC[B.NEON_BLK]     = {Color3.fromRGB(255, 34, 136),  Color3.fromRGB(255, 34, 136), Color3.fromRGB(255, 34, 136)}
BC[B.CITY_RUBBLE]  = {Color3.fromRGB(85, 85, 88),    Color3.fromRGB(85, 85, 88),   Color3.fromRGB(85, 85, 88)}
BC[B.SHIP_TIMBER]  = {Color3.fromRGB(107, 72, 38),   Color3.fromRGB(107, 72, 38),  Color3.fromRGB(107, 72, 38)}
BC[B.BARNACLE_WOOD]= {Color3.fromRGB(90, 64, 32),    Color3.fromRGB(90, 64, 32),   Color3.fromRGB(90, 64, 32)}
BC[B.SAIL_BLK]     = {Color3.fromRGB(232, 224, 208), Color3.fromRGB(232, 224, 208), Color3.fromRGB(232, 224, 208)}
BC[B.MARBLE]       = {Color3.fromRGB(228, 224, 220), Color3.fromRGB(228, 224, 220), Color3.fromRGB(228, 224, 220)}
BC[B.SEA_MARBLE]   = {Color3.fromRGB(184, 200, 192), Color3.fromRGB(184, 200, 192), Color3.fromRGB(184, 200, 192)}
BC[B.COLUMN_BLK]   = {Color3.fromRGB(216, 212, 204), Color3.fromRGB(216, 212, 204), Color3.fromRGB(216, 212, 204)}
BC[B.TEMPLE_STONE] = {Color3.fromRGB(168, 160, 152), Color3.fromRGB(168, 160, 152), Color3.fromRGB(168, 160, 152)}
BC[B.NICSHADE_LOG] = {Color3.fromRGB(58, 40, 72),    Color3.fromRGB(58, 40, 72),   Color3.fromRGB(58, 40, 72)}
BC[B.NICSHADE_LVS] = {Color3.fromRGB(30, 70, 70),    Color3.fromRGB(30, 70, 70),   Color3.fromRGB(30, 70, 70)}
BC[B.GLOW_FLOWER]  = {Color3.fromRGB(60, 220, 200),  Color3.fromRGB(60, 220, 200), Color3.fromRGB(60, 220, 200)}
BC[B.VINE_STONE]   = {Color3.fromRGB(96, 112, 96),   Color3.fromRGB(96, 112, 96),  Color3.fromRGB(96, 112, 96)}
BC[B.CANYON_STONE] = {Color3.fromRGB(154, 104, 72),   Color3.fromRGB(138, 88, 56),  Color3.fromRGB(122, 72, 48)}
BC[B.MONUMENT_STN] = {Color3.fromRGB(168, 160, 152), Color3.fromRGB(168, 160, 152), Color3.fromRGB(168, 160, 152)}
BC[B.RUSTED_METAL] = {Color3.fromRGB(138, 85, 48),   Color3.fromRGB(138, 85, 48),  Color3.fromRGB(138, 85, 48)}
BC[B.GLOW_CRYSTAL] = {Color3.fromRGB(80, 200, 240),  Color3.fromRGB(80, 200, 240), Color3.fromRGB(80, 200, 240)}
BC[B.DARK_PANEL]   = {Color3.fromRGB(20, 20, 32),    Color3.fromRGB(20, 20, 32),   Color3.fromRGB(20, 20, 32)}
BC[B.SIGNAL_STONE] = {Color3.fromRGB(80, 80, 96),    Color3.fromRGB(80, 80, 96),   Color3.fromRGB(80, 80, 96)}
BC[B.RAIL_BLK]     = {Color3.fromRGB(112, 112, 112), Color3.fromRGB(112, 112, 112), Color3.fromRGB(112, 112, 112)}
BC[B.RAIL_TIE]     = {Color3.fromRGB(107, 72, 38),   Color3.fromRGB(107, 72, 38),  Color3.fromRGB(107, 72, 38)}
BC[B.PLATFORM_BLK] = {Color3.fromRGB(136, 136, 128), Color3.fromRGB(136, 136, 128), Color3.fromRGB(136, 136, 128)}
BC[B.SCHOOL_WALL]  = {Color3.fromRGB(192, 168, 128), Color3.fromRGB(192, 168, 128), Color3.fromRGB(192, 168, 128)}
BC[B.LOCKER_BLK]   = {Color3.fromRGB(85, 85, 101),   Color3.fromRGB(85, 85, 101),  Color3.fromRGB(85, 85, 101)}
BC[B.GYM_FLOOR]    = {Color3.fromRGB(184, 144, 80),  Color3.fromRGB(184, 144, 80), Color3.fromRGB(184, 144, 80)}
BC[B.BOARDWALK]    = {Color3.fromRGB(160, 128, 80),  Color3.fromRGB(160, 128, 80), Color3.fromRGB(160, 128, 80)}
BC[B.RESORT_WALL]  = {Color3.fromRGB(208, 200, 184), Color3.fromRGB(208, 200, 184), Color3.fromRGB(208, 200, 184)}
BC[B.POOL_TILE]    = {Color3.fromRGB(51, 136, 187),  Color3.fromRGB(51, 136, 187), Color3.fromRGB(51, 136, 187)}
BC[B.CABIN_WALL]   = {Color3.fromRGB(90, 56, 24),    Color3.fromRGB(90, 56, 24),   Color3.fromRGB(90, 56, 24)}
BC[B.TRAIL_STONE]  = {Color3.fromRGB(128, 128, 120), Color3.fromRGB(128, 128, 120), Color3.fromRGB(128, 128, 120)}
BC[B.CHAPEL_STONE] = {Color3.fromRGB(144, 144, 136), Color3.fromRGB(144, 144, 136), Color3.fromRGB(144, 144, 136)}
BC[B.SIDING]       = {Color3.fromRGB(200, 192, 176), Color3.fromRGB(200, 192, 176), Color3.fromRGB(200, 192, 176)}
BC[B.SHINGLE]      = {Color3.fromRGB(85, 85, 96),    Color3.fromRGB(85, 85, 96),   Color3.fromRGB(85, 85, 96)}
BC[B.FENCE_BLK]    = {Color3.fromRGB(176, 160, 144), Color3.fromRGB(176, 160, 144), Color3.fromRGB(176, 160, 144)}
BC[B.DRIVEWAY]     = {Color3.fromRGB(152, 152, 144), Color3.fromRGB(152, 152, 144), Color3.fromRGB(152, 152, 144)}
BC[B.WATCHER_SAND] = {Color3.fromRGB(216, 184, 104), Color3.fromRGB(216, 184, 104), Color3.fromRGB(216, 184, 104)}
BC[B.TOWER_BRICK]  = {Color3.fromRGB(138, 120, 104), Color3.fromRGB(138, 120, 104), Color3.fromRGB(138, 120, 104)}
BC[B.ANCIENT_METAL]= {Color3.fromRGB(96, 96, 88),    Color3.fromRGB(96, 96, 88),   Color3.fromRGB(96, 96, 88)}
BC[B.PIRATE_PLNK]  = {Color3.fromRGB(90, 64, 32),    Color3.fromRGB(90, 64, 32),   Color3.fromRGB(90, 64, 32)}
BC[B.CORAL_PINK]   = {Color3.fromRGB(221, 85, 136),  Color3.fromRGB(221, 85, 136), Color3.fromRGB(221, 85, 136)}
BC[B.CORAL_BLUE]   = {Color3.fromRGB(51, 136, 204),  Color3.fromRGB(51, 136, 204), Color3.fromRGB(51, 136, 204)}
BC[B.CORAL_YELLOW] = {Color3.fromRGB(204, 170, 51),  Color3.fromRGB(204, 170, 51), Color3.fromRGB(204, 170, 51)}
BC[B.KELP]         = {Color3.fromRGB(30, 100, 50),   Color3.fromRGB(30, 100, 50),  Color3.fromRGB(30, 100, 50)}
BC[B.SEA_LANTERN]  = {Color3.fromRGB(136, 204, 221), Color3.fromRGB(136, 204, 221), Color3.fromRGB(136, 204, 221)}
BC[B.RAIL_IRON]    = {Color3.fromRGB(112, 112, 112), Color3.fromRGB(112, 112, 112), Color3.fromRGB(112, 112, 112)}
BC[B.RAIL_POWERED] = {Color3.fromRGB(170, 112, 48),  Color3.fromRGB(170, 112, 48), Color3.fromRGB(170, 112, 48)}
BC[B.RAIL_BED]     = {Color3.fromRGB(107, 72, 38),   Color3.fromRGB(107, 72, 38),  Color3.fromRGB(107, 72, 38)}
BC[B.TALL_GRASS]   = {Color3.fromRGB(60, 140, 40),   Color3.fromRGB(60, 140, 40),  Color3.fromRGB(60, 140, 40)}
BC[B.FLOWER_RED]   = {Color3.fromRGB(220, 40, 40),   Color3.fromRGB(40, 120, 30),  Color3.fromRGB(40, 120, 30)}
BC[B.FLOWER_BLUE]  = {Color3.fromRGB(60, 80, 200),   Color3.fromRGB(40, 120, 30),  Color3.fromRGB(40, 120, 30)}
BC[B.FLOWER_YELLOW]= {Color3.fromRGB(230, 200, 40),  Color3.fromRGB(40, 120, 30),  Color3.fromRGB(40, 120, 30)}
BC[B.SHRUB]        = {Color3.fromRGB(50, 100, 30),   Color3.fromRGB(50, 100, 30),  Color3.fromRGB(50, 100, 30)}
BC[B.REED]         = {Color3.fromRGB(100, 140, 60),  Color3.fromRGB(100, 140, 60), Color3.fromRGB(100, 140, 60)}
BC[B.FERN]         = {Color3.fromRGB(40, 120, 40),   Color3.fromRGB(40, 120, 40),  Color3.fromRGB(40, 120, 40)}
BC[B.LAVA]         = {Color3.fromRGB(255, 68, 0),    Color3.fromRGB(255, 68, 0),   Color3.fromRGB(255, 68, 0)}
BC[B.STAIR_COB]    = BC[B.COB]
BC[B.STAIR_PLNK]   = BC[B.PLNK]
BC[B.STAIR_BRK]    = BC[B.BRK]
BC[B.STAIR_SBK]    = BC[B.SBK]
BC[B.STAIR_STONE]  = BC[B.STONE]
BC[B.STAIR_MARBLE] = BC[B.MARBLE]
BC[B.LADDER]       = BC[B.PLNK]
BC[B.BASALT]       = {Color3.fromRGB(42, 42, 48),    Color3.fromRGB(42, 42, 48),   Color3.fromRGB(42, 42, 48)}
BC[B.ASH_STONE]    = {Color3.fromRGB(90, 90, 90),    Color3.fromRGB(90, 90, 90),   Color3.fromRGB(90, 90, 90)}
BC[B.SCORCHED]     = {Color3.fromRGB(58, 32, 32),    Color3.fromRGB(58, 32, 32),   Color3.fromRGB(58, 32, 32)}
BC[B.OBSIDIAN]     = {Color3.fromRGB(16, 16, 24),    Color3.fromRGB(16, 16, 24),   Color3.fromRGB(16, 16, 24)}
BC[B.LOCKER2]      = {Color3.fromRGB(85, 102, 136),  Color3.fromRGB(85, 102, 136), Color3.fromRGB(85, 102, 136)}
BC[B.BOOTH_SEAT]   = {Color3.fromRGB(122, 48, 48),   Color3.fromRGB(122, 48, 48),  Color3.fromRGB(122, 48, 48)}
BC[B.CABINET]      = {Color3.fromRGB(184, 144, 80),  Color3.fromRGB(184, 144, 80), Color3.fromRGB(184, 144, 80)}
BC[B.NEON_TRIM]    = {Color3.fromRGB(255, 51, 170),  Color3.fromRGB(255, 51, 170), Color3.fromRGB(255, 51, 170)}
BC[B.CARPET]       = {Color3.fromRGB(136, 34, 34),   Color3.fromRGB(136, 34, 34),  Color3.fromRGB(136, 34, 34)}
BC[B.COUNTER_TOP]  = {Color3.fromRGB(176, 176, 176), Color3.fromRGB(176, 176, 176), Color3.fromRGB(176, 176, 176)}
BC[B.MENU_BOARD]   = {Color3.fromRGB(34, 34, 34),    Color3.fromRGB(34, 34, 34),   Color3.fromRGB(34, 34, 34)}
BC[B.REDWOOD_LOG]  = {Color3.fromRGB(122, 58, 42),   Color3.fromRGB(107, 42, 26),  Color3.fromRGB(122, 58, 42)}
BC[B.REDWOOD_LVS]  = {Color3.fromRGB(40, 70, 30),    Color3.fromRGB(40, 70, 30),   Color3.fromRGB(40, 70, 30)}
BC[B.DOOR_OAK_C]   = {Color3.fromRGB(154, 112, 64),  Color3.fromRGB(154, 112, 64), Color3.fromRGB(154, 112, 64)}
BC[B.DOOR_OAK_O]   = {Color3.fromRGB(154, 112, 64),  Color3.fromRGB(154, 112, 64), Color3.fromRGB(154, 112, 64)}
BC[B.DOOR_IRON_C]  = {Color3.fromRGB(138, 138, 144), Color3.fromRGB(138, 138, 144), Color3.fromRGB(138, 138, 144)}
BC[B.DOOR_IRON_O]  = {Color3.fromRGB(138, 138, 144), Color3.fromRGB(138, 138, 144), Color3.fromRGB(138, 138, 144)}
BC[B.DOOR_DARK_C]  = {Color3.fromRGB(58, 40, 24),    Color3.fromRGB(58, 40, 24),   Color3.fromRGB(58, 40, 24)}
BC[B.DOOR_DARK_O]  = {Color3.fromRGB(58, 40, 24),    Color3.fromRGB(58, 40, 24),   Color3.fromRGB(58, 40, 24)}
BC[B.DESK]         = BC[B.PLNK]
BC[B.SHELF]        = BC[B.PLNK]
BC[B.TILE_FLOOR]   = BC[B.CONCRETE]
BC[B.CARPET_RED]   = {Color3.fromRGB(136, 34, 34),   Color3.fromRGB(136, 34, 34),  Color3.fromRGB(136, 34, 34)}
BC[B.DUNGEON_KEY]  = BC[B.NEON_BLK]
BC[B.STICK]        = {Color3.fromRGB(138, 108, 58),   Color3.fromRGB(138, 108, 58), Color3.fromRGB(138, 108, 58)}
BC[B.COAL_I]       = {Color3.fromRGB(51, 51, 51),     Color3.fromRGB(51, 51, 51),   Color3.fromRGB(51, 51, 51)}
BC[B.IRON_I]       = {Color3.fromRGB(216, 208, 200),  Color3.fromRGB(216, 208, 200), Color3.fromRGB(216, 208, 200)}
BC[B.WPICK]        = {Color3.fromRGB(176, 136, 72),   Color3.fromRGB(138, 108, 58), Color3.fromRGB(138, 108, 58)}
BC[B.SPICK]        = {Color3.fromRGB(128, 128, 128),  Color3.fromRGB(138, 108, 58), Color3.fromRGB(138, 108, 58)}
BC[B.WSWD]         = {Color3.fromRGB(176, 136, 72),   Color3.fromRGB(138, 108, 58), Color3.fromRGB(138, 108, 58)}
BC[B.WATER_BUCKET] = BC[B.WATER]
BC[B.LAVA_BUCKET]  = BC[B.LAVA]
-- Food colors (used in inventory icon)
BC[B.APPLE]        = {Color3.fromRGB(210, 50, 50),    Color3.fromRGB(210, 50, 50),   Color3.fromRGB(210, 50, 50)}
BC[B.WHEAT]        = {Color3.fromRGB(220, 190, 80),   Color3.fromRGB(220, 190, 80),  Color3.fromRGB(220, 190, 80)}
BC[B.BREAD]        = {Color3.fromRGB(190, 145, 70),   Color3.fromRGB(190, 145, 70),  Color3.fromRGB(190, 145, 70)}
BC[B.MEAT_RAW]     = {Color3.fromRGB(200, 90, 70),    Color3.fromRGB(200, 90, 70),   Color3.fromRGB(200, 90, 70)}
BC[B.MEAT_COOKED]  = {Color3.fromRGB(130, 65, 30),    Color3.fromRGB(130, 65, 30),   Color3.fromRGB(130, 65, 30)}
BC[B.GOLD_I]       = {Color3.fromRGB(225, 190, 60),   Color3.fromRGB(225, 190, 60),  Color3.fromRGB(225, 190, 60)}

BlockTypes.BC = BC

-- Emissive blocks (for PointLight attachment)
BlockTypes.EMISSIVE = {
	[B.GLOW_CRYSTAL] = {color = Color3.fromRGB(80, 200, 240), brightness = 1, range = 12},
	[B.GLOW_FLOWER]  = {color = Color3.fromRGB(60, 220, 200), brightness = 0.8, range = 8},
	[B.SEA_LANTERN]  = {color = Color3.fromRGB(136, 204, 221), brightness = 1, range = 14},
	[B.NEON_BLK]     = {color = Color3.fromRGB(255, 34, 136), brightness = 1.2, range = 10},
	[B.NEON_TRIM]    = {color = Color3.fromRGB(255, 51, 170), brightness = 1, range = 8},
	[B.LAVA]         = {color = Color3.fromRGB(255, 100, 0), brightness = 1.5, range = 16},
}

-- Door pairs: closed -> open, open -> closed
BlockTypes.DOOR_TOGGLE = {
	[B.DOOR_OAK_C]  = B.DOOR_OAK_O,
	[B.DOOR_OAK_O]  = B.DOOR_OAK_C,
	[B.DOOR_IRON_C] = B.DOOR_IRON_O,
	[B.DOOR_IRON_O] = B.DOOR_IRON_C,
	[B.DOOR_DARK_C] = B.DOOR_DARK_O,
	[B.DOOR_DARK_O] = B.DOOR_DARK_C,
}

return BlockTypes
