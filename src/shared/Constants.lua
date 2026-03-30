-- VC CRAFT Constants
local Constants = {}

Constants.CS = 16        -- Chunk size (width/depth)
Constants.CH = 320       -- Chunk height
Constants.WL = 124       -- Water level
Constants.TS = 16        -- Texture size
Constants.Y_OFF = 60     -- Y offset for display
Constants.RD = 6         -- Default render distance (in chunks)
Constants.BLOCK_SIZE = 4 -- Size of each voxel block in studs

-- Day/night cycle
Constants.DAY_LENGTH = 1200 -- seconds for full cycle (20 minutes)

-- Player defaults
Constants.PLAYER_HP = 20
Constants.PLAYER_HUNGER = 20
Constants.PLAYER_SPEED = 5.2
Constants.PLAYER_SPRINT_MUL = 1.6
Constants.PLAYER_JUMP_VEL = 7.5
Constants.PLAYER_GRAVITY = 22
Constants.PLAYER_REACH = 32       -- 8 blocks * 4 studs/block
Constants.PLAYER_ATTACK_RANGE = 16 -- 4 blocks * 4 studs/block
Constants.PLAYER_HITBOX_HW = 0.28

-- Fall damage
Constants.FALL_THRESHOLD = 3

-- Mob limits
Constants.MAX_MOBS = 15
Constants.MOB_SPAWN_INTERVAL = 10
Constants.MOB_DESPAWN_DIST_SQ = nil -- set dynamically based on RD

-- Train
Constants.MAX_TRAINS = 2
Constants.MAX_RAIL_CARTS = 3
Constants.TRAIN_FUEL_MAX = 100

return Constants
