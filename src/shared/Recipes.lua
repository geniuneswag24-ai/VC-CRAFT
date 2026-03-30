-- VC CRAFT Crafting Recipes
local Recipes = {}
local BT = require(script.Parent.BlockTypes)
local B = BT.B

-- Recipes: {grid=2D array of block IDs (0=empty), result=id, count=n}
local RCP = {}

local function addR(g, r, n)
	table.insert(RCP, {g=g, r=r, n=n or 1})
end

-- Wood logs -> planks (1x1)
addR({{B.OLOG,0},{0,0}}, B.PLNK, 4)
addR({{B.SLOG,0},{0,0}}, B.PLNK, 4)
addR({{B.BLOG,0},{0,0}}, B.PLNK, 4)
addR({{B.DLOG,0},{0,0}}, B.PLNK, 4)
addR({{B.JLOG,0},{0,0}}, B.PLNK, 4)
addR({{B.ALOG,0},{0,0}}, B.PLNK, 4)
addR({{B.NICSHADE_LOG,0},{0,0}}, B.PLNK, 4)
addR({{B.REDWOOD_LOG,0},{0,0}}, B.PLNK, 4)

-- Planks -> sticks
addR({{B.PLNK,0},{B.PLNK,0}}, B.STICK, 4)

-- Crafting table
addR({{B.PLNK,B.PLNK},{B.PLNK,B.PLNK}}, B.CRFT, 1)

-- Stone bricks
addR({{B.COB,B.COB},{B.COB,B.COB}}, B.SBK, 4)

-- Tools (3x3 grid required)
addR({{B.PLNK,B.PLNK,B.PLNK},{0,B.STICK,0},{0,B.STICK,0}}, B.WPICK, 1)
addR({{B.COB,B.COB,B.COB},{0,B.STICK,0},{0,B.STICK,0}}, B.SPICK, 1)
addR({{0,B.PLNK,0},{0,B.STICK,0},{0,B.STICK,0}}, B.WSWD, 1)

-- Furnace
addR({{B.COB,B.COB,B.COB},{B.COB,0,B.COB},{B.COB,B.COB,B.COB}}, B.FURN, 1)

-- Chest
addR({{B.PLNK,B.PLNK,B.PLNK},{B.PLNK,0,B.PLNK},{B.PLNK,B.PLNK,B.PLNK}}, B.CHST, 1)

-- Stairs
addR({{B.COB,0,0},{B.COB,B.COB,0},{B.COB,B.COB,B.COB}}, B.STAIR_COB, 4)
addR({{B.PLNK,0,0},{B.PLNK,B.PLNK,0},{B.PLNK,B.PLNK,B.PLNK}}, B.STAIR_PLNK, 4)
addR({{B.BRK,0,0},{B.BRK,B.BRK,0},{B.BRK,B.BRK,B.BRK}}, B.STAIR_BRK, 4)
addR({{B.SBK,0,0},{B.SBK,B.SBK,0},{B.SBK,B.SBK,B.SBK}}, B.STAIR_SBK, 4)
addR({{B.STONE,0,0},{B.STONE,B.STONE,0},{B.STONE,B.STONE,B.STONE}}, B.STAIR_STONE, 4)
addR({{B.MARBLE,0,0},{B.MARBLE,B.MARBLE,0},{B.MARBLE,B.MARBLE,B.MARBLE}}, B.STAIR_MARBLE, 4)

-- Doors
addR({{B.PLNK,B.PLNK},{B.PLNK,B.PLNK},{B.PLNK,B.PLNK}}, B.DOOR_OAK_C, 3)
addR({{B.IRON_I,B.IRON_I},{B.IRON_I,B.IRON_I},{B.IRON_I,B.IRON_I}}, B.DOOR_IRON_C, 3)
addR({{B.DLOG,B.DLOG},{B.DLOG,B.DLOG},{B.DLOG,B.DLOG}}, B.DOOR_DARK_C, 3)

-- Fence
addR({{B.PLNK,B.STICK,B.PLNK},{B.PLNK,B.STICK,B.PLNK}}, B.FENCE_BLK, 3)

-- Ladder
addR({{B.STICK,0,B.STICK},{B.STICK,B.STICK,B.STICK},{B.STICK,0,B.STICK}}, B.LADDER, 3)

-- Bread (3 wheat in a row)
addR({{B.WHEAT,B.WHEAT,B.WHEAT}}, B.BREAD, 1)

-- Bucket (3 iron ingots in V)
addR({{B.IRON_I,0,B.IRON_I},{0,B.IRON_I,0}}, B.WATER_BUCKET, 1)

Recipes.RCP = RCP

-- ─── Smelting recipes ─────────────────────────────────────────────────────────
-- {input = blockId, fuel = blockId (or nil=any fuel), result = blockId, count = n}
local SMELT = {}
local function addS(inp, res, n)
	table.insert(SMELT, {input=inp, result=res, count=n or 1})
end

addS(B.COAL,      B.COAL_I,      1)   -- coal ore → coal
addS(B.IRON,      B.IRON_I,      1)   -- iron ore → iron ingot
addS(B.GOLD,      B.GOLD_I,      1)   -- gold ore → gold ingot
addS(B.MEAT_RAW,  B.MEAT_COOKED, 1)   -- raw beef → cooked beef
addS(B.SAND,      B.GLASS,       1)   -- sand → glass
addS(B.COB,       B.STONE,       1)   -- cobblestone → smooth stone
addS(B.DEEP,      B.BASALT,      1)   -- deepslate → basalt

Recipes.SMELT = SMELT

function Recipes.checkSmelt(inputId)
	for _, s in ipairs(SMELT) do
		if s.input == inputId then
			return {id = s.result, count = s.count}
		end
	end
	return nil
end

-- Check crafting grid for a matching recipe
-- grid: 2D array [row][col], sz: grid size (2 or 3)
-- Returns {id, count} or nil
function Recipes.check(grid, sz)
	for _, rec in ipairs(RCP) do
		local rH = #rec.g
		local rW = #rec.g[1]
		if rW <= sz and rH <= sz then
			for oy = 0, sz - rH do
				for ox = 0, sz - rW do
					local ok = true
					for y = 0, sz - 1 do
						if not ok then break end
						for x = 0, sz - 1 do
							local gv = (grid[y+1] and grid[y+1][x+1]) or 0
							local ry = y - oy
							local rx = x - ox
							local rv = 0
							if ry >= 0 and ry < rH and rx >= 0 and rx < rW then
								rv = rec.g[ry+1][rx+1] or 0
							end
							if gv ~= rv then ok = false; break end
						end
					end
					if ok then return {id = rec.r, count = rec.n} end
				end
			end
		end
	end
	return nil
end

return Recipes
