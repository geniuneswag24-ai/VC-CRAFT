-- VC CRAFT World Utilities (shared between server and client)
local WorldUtils = {}
local C = require(script.Parent.Constants)

local CS = C.CS
local CH = C.CH
local floor = math.floor

-- Convert world coords to chunk key
function WorldUtils.chunkKey(cx, cz)
	return cx .. "," .. cz
end

-- Convert world xyz to chunk coords
function WorldUtils.worldToChunk(wx, wz)
	return floor(wx / CS), floor(wz / CS)
end

-- Convert world xyz to local chunk coords
function WorldUtils.worldToLocal(wx, wz)
	local lx = wx % CS
	local lz = wz % CS
	if lx < 0 then lx = lx + CS end
	if lz < 0 then lz = lz + CS end
	return lx, lz
end

-- Block array index
function WorldUtils.blockIndex(lx, y, lz)
	return y * CS * CS + lz * CS + lx + 1 -- 1-indexed for Lua
end

-- Check if block is a natural surface block
function WorldUtils.isNaturalSurface(b)
	local B = require(script.Parent.BlockTypes).B
	return b == B.GRASS or b == B.DIRT or b == B.SAND or b == B.DRY_GRASS
		or b == B.SNOW or b == B.MUD or b == B.RSAND or b == B.CLAY
		or b == B.WATCHER_SAND or b == B.BASALT or b == B.ASH_STONE
		or b == B.SCORCHED
end

-- Deterministic hash (same as JS version)
function WorldUtils.dh(x, z)
	local h = bit32.bxor(
		bit32.band(x * 2654435761, 0xFFFFFFFF),
		bit32.band(z * 2246822519, 0xFFFFFFFF)
	)
	h = bit32.band(bit32.bxor(bit32.rshift(h, 16), h) * 0x45d9f3b, 0xFFFFFFFF)
	h = bit32.band(bit32.bxor(bit32.rshift(h, 16), h) * 0x45d9f3b, 0xFFFFFFFF)
	return bit32.bxor(bit32.rshift(h, 16), h)
end

function WorldUtils.dh01(x, z)
	return (WorldUtils.dh(x, z) % 65536) / 65535
end

-- RemoteEvent names
WorldUtils.RE = {
	BLOCK_SET       = "BlockSet",
	CHUNK_REQUEST   = "ChunkRequest",
	CHUNK_DATA      = "ChunkData",
	PLAYER_UPDATE   = "PlayerUpdate",
	MOB_UPDATE      = "MobUpdate",
	MOB_DAMAGE      = "MobDamage",
	PLAYER_DAMAGE   = "PlayerDamage",
	GAME_STATE      = "GameState",
	INTERACT        = "Interact",
	CHEST_OPEN      = "ChestOpen",
	CHEST_DATA      = "ChestData",
	CHEST_UPDATE    = "ChestUpdate",
	SPAWN_BOSS      = "SpawnBoss",
	ITEM_DROP       = "ItemDrop",
	ITEM_PICKUP     = "ItemPickup",
	DAY_NIGHT       = "DayNight",
	TRAIN_UPDATE    = "TrainUpdate",
	TRAIN_MOUNT     = "TrainMount",
	CHAT            = "Chat",
}

return WorldUtils
