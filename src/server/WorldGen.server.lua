-- VC CRAFT World Generation Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local BT = require(Shared.BlockTypes)
local BiomeData = require(Shared.BiomeData)
local Noise = require(Shared.Noise)
local WorldUtils = require(Shared.WorldUtils)

local B = BT.B
local BI = BiomeData.BI
local BDt = BiomeData.BDt
local CS = C.CS
local CH = C.CH
local WL = C.WL
local floor = math.floor
local abs = math.abs
local mn = math.min
local mx = math.max

-- World state
local World = {
	seed = 0,
	chunks = {},       -- [key] = {blk = {}, cx, cz, generated=false}
	pendingBlocks = {}, -- deferred structure blocks
	structChunks = {},  -- set of chunk keys that have structures
	structRegistry = {}, -- name -> [{x,y,z}]
	chestData = {},     -- "x,y,z" -> {27 slots}
	stations = {},      -- train station positions
	hasRail = {},       -- chunk keys with rails
}
_G.WorldGen = World -- expose globally for other scripts

-- RemoteEvents setup
local RE = {}
for _, name in pairs(WorldUtils.RE) do
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = ReplicatedStorage
	RE[name] = e
end

-- RemoteFunctions
local getRF = Instance.new("RemoteFunction")
getRF.Name = "GetBlock"
getRF.Parent = ReplicatedStorage

local getChunkRF = Instance.new("RemoteFunction")
getChunkRF.Name = "GetChunkData"
getChunkRF.Parent = ReplicatedStorage

-- ─── Chunk data structure ───────────────────────────────────────────────────
local function newChunk(cx, cz)
	return {
		cx = cx, cz = cz,
		blk = {},  -- sparse table [index] = blockId (default AIR=0)
		generated = false,
		hasSurface = false,
		dirty = false,
	}
end

local function chunkIdx(lx, y, lz)
	return y * CS * CS + lz * CS + lx
end

local function getBlock(chunk, lx, y, lz)
	if lx < 0 or lx >= CS or lz < 0 or lz >= CS or y < 0 or y >= CH then return B.AIR end
	return chunk.blk[chunkIdx(lx, y, lz)] or B.AIR
end

local function setBlock(chunk, lx, y, lz, v)
	if lx < 0 or lx >= CS or lz < 0 or lz >= CS or y < 0 or y >= CH then return end
	local idx = chunkIdx(lx, y, lz)
	if v == B.AIR then
		chunk.blk[idx] = nil
	else
		chunk.blk[idx] = v
	end
	chunk.dirty = true
end

local function getOrCreateChunk(cx, cz)
	local key = WorldUtils.chunkKey(cx, cz)
	if not World.chunks[key] then
		World.chunks[key] = newChunk(cx, cz)
		genChunk(World.chunks[key])
	end
	return World.chunks[key]
end

-- ─── Cross-chunk block setter ─────────────────────────────────────────────
local function dungeonSet(wx, wy, wz, bv, srcChunk)
	if wy < 0 or wy >= CH then return end
	local cx = floor(wx / CS)
	local cz = floor(wz / CS)
	local lx = wx % CS; if lx < 0 then lx = lx + CS end
	local lz = wz % CS; if lz < 0 then lz = lz + CS end
	if srcChunk and cx == srcChunk.cx and cz == srcChunk.cz then
		setBlock(srcChunk, lx, wy, lz, bv)
	else
		local key = WorldUtils.chunkKey(cx, cz)
		local tc = World.chunks[key]
		if tc then
			setBlock(tc, lx, wy, lz, bv)
			tc.dirty = true
		else
			if not World.pendingBlocks[key] then World.pendingBlocks[key] = {} end
			table.insert(World.pendingBlocks[key], {lx, wy, lz, bv})
		end
	end
end

local function ss(ck, x, y, z, bv)
	if y < 0 or y >= CH then return end
	if x >= 0 and x < CS and z >= 0 and z < CS then
		setBlock(ck, x, y, z, bv)
	else
		local wx = ck.cx * CS + x
		local wz = ck.cz * CS + z
		dungeonSet(wx, y, wz, bv, ck)
	end
end

-- Apply pending blocks when chunk is generated
local function applyPending(chunk)
	local key = WorldUtils.chunkKey(chunk.cx, chunk.cz)
	if World.pendingBlocks[key] then
		for _, entry in ipairs(World.pendingBlocks[key]) do
			setBlock(chunk, entry[1], entry[2], entry[3], entry[4])
		end
		World.pendingBlocks[key] = nil
		chunk.dirty = true
	end
end

-- ─── Ore placement ───────────────────────────────────────────────────────────
local function placeOre(wx, y, wz)
	local rv = WorldUtils.dh01(wx * 999 + y, wz * 777)
	if y < 84 and rv < 0.004 then return B.DIAM end
	if y < 116 and rv < 0.01 then return B.GOLD end
	if y < 160 and rv < 0.018 then return B.IRON end
	if y < 190 and rv < 0.022 then return B.COAL end
	return nil
end

-- ─── Terrain column generation ──────────────────────────────────────────────
local function genTerrainColumn(chunk, lx, lz)
	local wx = chunk.cx * CS + lx
	local wz = chunk.cz * CS + lz
	local bi = BiomeData.bio(wx, wz)
	local bd = BDt[bi]
	local h = BiomeData.htA(wx, wz, bi)
	local nT, nM, nE, nC, nD, nR, nS, nB = BiomeData.getNoise()

	for y = 0, CH - 1 do
		local bv = B.AIR
		if y == 0 then
			bv = B.BED
		elseif y < 5 then
			if WorldUtils.dh01(wx * 13 + y, wz * 17) < 0.5 then bv = B.BED
			else bv = B.DEEP end
		elseif y <= h then
			if y == h then
				-- Surface block
				if bi == BI.OC or bi == BI.BE then
					bv = B.SAND
				elseif bi == BI.MO and h > 200 then
					bv = B.SNOW
				elseif bi == BI.VOLCANO and h > 220 then
					bv = B.SCORCHED
				else
					bv = bd.sf
				end
			elseif y > h - 4 then
				-- Subsurface
				if bi == BI.VOLCANO then bv = B.BASALT
				else bv = bd.su end
			elseif y < 76 then
				if bi == BI.VOLCANO then bv = B.SCORCHED
				else bv = B.DEEP end
			else
				local ore = placeOre(wx, y, wz)
				bv = ore or B.STONE
			end
		elseif y <= WL then
			bv = B.WATER
		end

		if bv ~= B.AIR then
			setBlock(chunk, lx, y, lz, bv)
		end
	end
end

-- ─── Cave generation ─────────────────────────────────────────────────────────
local function carveCaves(chunk)
	local nT, nM, nE, nC, nD, nR, nS, nB = BiomeData.getNoise()

	for lx = 0, CS - 1 do
		for lz = 0, CS - 1 do
			local wx = chunk.cx * CS + lx
			local wz = chunk.cz * CS + lz
			local bi = BiomeData.bio(wx, wz)
			local h = BiomeData.htA(wx, wz, bi)

			for y = 1, mn(h - 2, CH - 1) do
				local bv = getBlock(chunk, lx, y, lz)
				if bv == B.AIR or bv == B.WATER or bv == B.BED then
					-- skip
				else
					local carve = false

					-- Swiss-cheese: tight worm-like tubes (~3% density)
					local c1 = nC:n3(wx*0.05, y*0.05, wz*0.05)
					local c2 = nC:n3(wx*0.08, y*0.10, wz*0.08)
					if c1*c1 + c2*c2 < 0.018 then carve = true end

					-- Worm tunnels: narrow branching passages (~2% density)
					if not carve and y > 5 and y < 160 then
						local w1 = nC:n3(wx*0.025, y*0.025, wz*0.025)
						local w2 = nC:n3(wx*0.030, y*0.030, wz*0.030)
						if w1*w1 + w2*w2 < 0.010 then carve = true end
					end

					-- Big cave rooms: require TWO noise fields both elevated (~4% density)
					if not carve and y < 190 and y > 10 then
						local b1 = nC:n3(wx*0.015, y*0.020, wz*0.015)
						local b2 = nC:n3(wx*0.020, y*0.015, wz*0.020)
						if b1 > 0.35 and b2 > 0.35 then carve = true end
					end

					-- Giant caverns: very high threshold, only deep (~3% density)
					if not carve and y > 8 and y < 150 then
						if nC:n3(wx*0.005, y*0.008, wz*0.005) > 0.78 then carve = true end
					end

					-- Deep caves: tighter threshold below y=100 (~5% density)
					if not carve and y < 100 then
						if nC:n3(wx*0.04, y*0.04, wz*0.04) > 0.70 then carve = true end
					end

					-- Ravines: thin vertical sheets (~2% density)
					if not carve and y > 5 and y < 170 then
						if abs(nC:n3(wx*0.03, y*0.005, wz*0.03)) < 0.020 then carve = true end
					end

					-- Biome-specific cave entrances near surface
					if not carve and y > h - 8 and y < h then
						local thr = 0.010
						if bi == BI.MO then thr = 0.030
						elseif bi == BI.VOLCANO then thr = 0.025
						elseif bi == BI.VC_BADLANDS or bi == BI.CAMGROVE then thr = 0.020
						end
						if abs(nC:n3(wx*0.04, y*0.04, wz*0.04)) < thr then carve = true end
					end

					if carve then
						setBlock(chunk, lx, y, lz, B.AIR)
					end
				end
			end

			-- Remove floating water; seed lava in deep cave floors
			local wx2 = chunk.cx * CS + lx
			local wz2 = chunk.cz * CS + lz
			for y = 1, CH - 2 do
				local bv2 = getBlock(chunk, lx, y, lz)
				if bv2 == B.WATER then
					if getBlock(chunk, lx, y-1, lz) == B.AIR then
						setBlock(chunk, lx, y, lz, B.AIR)
					end
				elseif bv2 == B.AIR and y <= 72 then
					if getBlock(chunk, lx, y-1, lz) ~= B.AIR then
						if WorldUtils.dh01(wx2*3+y, wz2*7) < 0.05 then
							setBlock(chunk, lx, y, lz, B.LAVA)
						end
					end
				end
			end
		end
	end
end

-- ─── Tree generation ─────────────────────────────────────────────────────────
local function placeTree(chunk, lx, y, lz, treeType)
	local r2 = WorldUtils.dh01(chunk.cx*CS + lx + 3, chunk.cz*CS + lz + 7)
	local big = r2 > 0.75

	if treeType == "spruce" then
		local h = big and (8 + floor(r2*4)) or (5 + floor(r2*3))
		local logB, leafB = B.SLOG, B.SLVS
		for dy = 0, h do ss(chunk, lx, y+dy, lz, logB) end
		for dy = 2, h do
			local rad = dy < h/2 and 2 or 1
			for dx = -rad, rad do
				for dz = -rad, rad do
					if dx ~= 0 or dz ~= 0 then
						if abs(dx) + abs(dz) <= rad + 1 then
							ss(chunk, lx+dx, y+dy, lz+dz, leafB)
						end
					end
				end
			end
		end
		ss(chunk, lx, y+h+1, lz, leafB)

	elseif treeType == "nicshade" then
		local h = big and (9 + floor(r2*3)) or (6 + floor(r2*3))
		local logB, leafB = B.NICSHADE_LOG, B.NICSHADE_LVS
		for dy = 0, h do ss(chunk, lx, y+dy, lz, logB) end
		for dy = h-3, h+1 do
			local rad = big and 4 or 3
			for dx = -rad, rad do
				for dz = -rad, rad do
					if dx*dx + dz*dz <= rad*rad + 2 then
						ss(chunk, lx+dx, y+dy, lz+dz, leafB)
					end
				end
			end
		end
		ss(chunk, lx, y+1, lz+1, B.GLOW_FLOWER)

	elseif treeType == "jungle" then
		local h = big and (10 + floor(r2*4)) or (5 + floor(r2*3))
		local logB, leafB = B.JLOG, B.JLVS
		for dy = 0, h do ss(chunk, lx, y+dy, lz, logB) end
		if big then
			for _, off in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
				for dy = 0, 3 do ss(chunk, lx+off[1], y+dy, lz+off[2], logB) end
			end
		end
		for dy = h-2, h+1 do
			local rad = 3
			for dx = -rad, rad do
				for dz = -rad, rad do
					if dx*dx + dz*dz <= rad*rad + 1 then
						ss(chunk, lx+dx, y+dy, lz+dz, leafB)
					end
				end
			end
		end

	elseif treeType == "redwood" then
		local h = big and (28 + floor(r2*14)) or (18 + floor(r2*8))
		local logB, leafB = B.REDWOOD_LOG, B.REDWOOD_LVS
		local trunkW = big and 2 or 1
		for dy = 0, h do
			for tx = -trunkW, trunkW do
				for tz = -trunkW, trunkW do
					ss(chunk, lx+tx, y+dy, lz+tz, logB)
				end
			end
		end
		-- Buttress roots
		if big then
			for _, d in ipairs({{3,0},{-3,0},{0,3},{0,-3},{2,2},{-2,2},{2,-2},{-2,-2}}) do
				for dy = 0, 4 do
					local ox = floor(d[1] * (1 - dy/5))
					local oz = floor(d[2] * (1 - dy/5))
					ss(chunk, lx+ox, y+dy, lz+oz, logB)
				end
			end
		end
		-- Canopy
		for dy = floor(h*0.55), h do
			local rad = 4 + floor((dy - h*0.55)/(h*0.45) * 3)
			if dy > h - 4 then rad = 2 end
			for dx = -rad, rad do
				for dz = -rad, dz do
					if dx*dx + dz*dz <= rad*rad + 2 then
						ss(chunk, lx+dx, y+dy, lz+dz, leafB)
					end
				end
			end
		end

	else -- oak / birch / acacia / dark
		local logMap = {oak=B.OLOG, birch=B.BLOG, acacia=B.ALOG, dark=B.DLOG}
		local leafMap = {oak=B.OLVS, birch=B.BLVS, acacia=B.ALVS, dark=B.DLVS}
		local logB = logMap[treeType] or B.OLOG
		local leafB = leafMap[treeType] or B.OLVS
		local h = big and (7 + floor(r2*3)) or (4 + floor(r2*2))
		for dy = 0, h do ss(chunk, lx, y+dy, lz, logB) end
		local rad = big and 3 or 2
		for dy = h-2, h+1 do
			for dx = -rad, rad do
				for dz = -rad, rad do
					if abs(dx) + abs(dz) <= rad + 1 then
						ss(chunk, lx+dx, y+dy, lz+dz, leafB)
					end
				end
			end
		end
	end
end

-- ─── Structure helpers ────────────────────────────────────────────────────────
local function buildRoom(ck, x, y, z, w, d, h2, wallB, floorB, ceilB, hasWindow)
	for dy = 0, h2-1 do
		for dx = 0, w-1 do
			for dz = 0, d-1 do
				local isWall = dx==0 or dx==w-1 or dz==0 or dz==d-1
				local isFloor = dy == 0
				local isCeil = dy == h2-1
				if isFloor then
					ss(ck, x+dx, y+dy, z+dz, floorB)
				elseif isCeil then
					ss(ck, x+dx, y+dy, z+dz, ceilB)
				elseif isWall then
					if hasWindow and dy==2 and dx>0 and dx<w-1 and dz==0 and dx%3==1 then
						ss(ck, x+dx, y+dy, z+dz, B.GLASS)
					elseif hasWindow and dy==2 and dx>0 and dx<w-1 and dz==d-1 and dx%3==1 then
						ss(ck, x+dx, y+dy, z+dz, B.GLASS)
					else
						ss(ck, x+dx, y+dy, z+dz, wallB)
					end
				end
			end
		end
	end
end

local function clearVolume(ck, x, y, z, w, d, h)
	for dx = 0, w-1 do
		for dz = 0, d-1 do
			for dy = 0, h-1 do
				ss(ck, x+dx, y+dy, z+dz, B.AIR)
			end
		end
	end
	-- Fill any air/water holes below foundation
	for dx = -1, w do
		for dz = -1, d do
			for dy = -1, -4, -1 do
				local bx = x+dx; local bz = z+dz; local by = y+dy
				if bx >= 0 and bx < CS and bz >= 0 and bz < CS and by >= 0 then
					local ex = getBlock(ck, bx, by, bz)
					if ex == B.AIR or ex == B.WATER then
						ss(ck, bx, by, bz, B.DIRT)
					else break end
				end
			end
		end
	end
end

-- ─── Structure generation ────────────────────────────────────────────────────

local function genCondo(ck, x, y, z, r)
	local w = 10 + floor(r*3); local d = 8 + floor(r*3)
	local floors = 3 + floor(r*2); local fh = 4
	for f = 0, floors-1 do
		local fy = y + f*fh
		buildRoom(ck, x, fy, z, w, d, fh, B.STUCCO, f==0 and B.CONCRETE or B.PLNK, B.CONCRETE, true)
		local hw = floor(w/2)
		for dy = 1, fh-2 do
			for dz = 1, d-2 do ss(ck, x+hw, fy+dy, z+dz, B.CONDO_WALL) end
		end
		ss(ck, x+hw, fy+1, z+floor(d/2), B.AIR); ss(ck, x+hw, fy+2, z+floor(d/2), B.AIR)
		for dy = 1, fh-2 do
			for dx = 1, hw-1 do ss(ck, x+dx, fy+dy, z+floor(d/2), B.CONDO_WALL) end
			for dx = hw+1, w-2 do ss(ck, x+dx, fy+dy, z+floor(d/2), B.CONDO_WALL) end
		end
		ss(ck, x+floor(w/4), fy+1, z+floor(d/2), B.AIR); ss(ck, x+floor(w/4), fy+2, z+floor(d/2), B.AIR)
		ss(ck, x+floor(w*3/4), fy+1, z+floor(d/2), B.AIR); ss(ck, x+floor(w*3/4), fy+2, z+floor(d/2), B.AIR)
		for dx = 2, w-3 do ss(ck, x+dx, fy, z+d, B.CONCRETE); ss(ck, x+dx, fy+1, z+d, B.FENCE_BLK) end
		if f < floors-1 then for dy = 0, fh-1 do ss(ck, x+1, fy+dy, z+1, B.COB) end end
		ss(ck, x+2, fy+1, z+2, B.PLNK); ss(ck, x+w-3, fy+1, z+d-3, B.PLNK)
		ss(ck, x+hw-2, fy+1, z+2, B.FURN); ss(ck, x+hw+2, fy+1, z+d-3, B.FURN)
	end
	for dx = -1, w do for dz = -1, d+1 do ss(ck, x+dx, y+floors*fh, z+dz, B.ROOF_TILE) end end
	for dx = 0, w-1 do ss(ck, x+dx, y+floors*fh+1, z, B.FENCE_BLK); ss(ck, x+dx, y+floors*fh+1, z+d, B.FENCE_BLK) end
	ss(ck, x+floor(w/2), y+1, z, B.AIR); ss(ck, x+floor(w/2), y+2, z, B.AIR)
	for dx = -1, w do for dz = -3, -1 do ss(ck, x+dx, y-1, z+dz, B.ASPHALT) end end
	ss(ck, x+floor(w/2)-1, y+1, z-1, B.METAL_PANEL); ss(ck, x+floor(w/2)+1, y+1, z-1, B.METAL_PANEL)
end

local function genHouse(ck, x, y, z, r)
	local w = 8 + floor(r*4); local d = 7 + floor(r*3); local h2 = 5
	clearVolume(ck, x-1, y, z-3, w+2, d+6, h2+4)
	for dx = -1, w do for dz = -1, d do ss(ck, x+dx, y, z+dz, B.CONCRETE) end end
	buildRoom(ck, x, y, z, w, d, h2, B.SIDING, B.PLNK, B.PLNK, true)
	local mid = floor(w/2)
	for dy = 1, h2-2 do
		for dz = 1, d-2 do ss(ck, x+mid, y+dy, z+dz, B.SIDING) end
		for dx = mid+1, w-2 do ss(ck, x+dx, y+dy, z+floor(d/2), B.SIDING) end
	end
	ss(ck, x+mid, y+1, z+2, B.AIR); ss(ck, x+mid, y+2, z+2, B.AIR)
	ss(ck, x+mid+2, y+1, z+floor(d/2), B.AIR); ss(ck, x+mid+2, y+2, z+floor(d/2), B.AIR)
	ss(ck, x+2, y+1, z, B.DOOR_OAK_C); ss(ck, x+2, y+2, z, B.DOOR_OAK_C)
	for dx = -1, w do
		for dz = -1, d do
			local peak = mn(abs(dx - w/2), abs(w-1-dx - w/2))
			ss(ck, x+dx, y+h2+floor(peak/2), z+dz, B.SHINGLE)
		end
	end
	for dz = -3, -1 do for dx = 1, 3 do ss(ck, x+dx, y, z+dz, B.DRIVEWAY) end end
	for dx = -1, w do ss(ck, x+dx, y+1, z+d, B.FENCE_BLK) end
	for dx = mid+1, w-2 do ss(ck, x+dx, y+1, z+d-2, B.COB) end
end

local function genCabin(ck, x, y, z)
	clearVolume(ck, x-1, y, z-2, 9, 10, 8)
	buildRoom(ck, x, y, z, 7, 6, 4, B.CABIN_WALL, B.PLNK, B.CABIN_WALL, true)
	for dx = 0, 6 do ss(ck, x+dx, y, z-1, B.PLNK); ss(ck, x+dx, y, z-2, B.PLNK) end
	for dy = 1, 3 do ss(ck, x, y+dy, z-2, B.SLOG); ss(ck, x+6, y+dy, z-2, B.SLOG) end
	for dx = 0, 6 do ss(ck, x+dx, y+3, z-2, B.CABIN_WALL) end
	ss(ck, x+3, y+1, z, B.DOOR_OAK_C); ss(ck, x+3, y+2, z, B.DOOR_OAK_C)
	ss(ck, x+1, y+2, z, B.GLASS); ss(ck, x+5, y+2, z, B.GLASS)
	ss(ck, x, y+2, z+2, B.GLASS); ss(ck, x+6, y+2, z+2, B.GLASS)
	ss(ck, x+1, y+1, z+1, B.PLNK); ss(ck, x+2, y+1, z+1, B.PLNK)
	ss(ck, x+1, y+1, z+2, B.COB); ss(ck, x+2, y+1, z+2, B.COB)
	ss(ck, x+5, y+1, z+4, B.CHST); ss(ck, x+1, y+1, z+4, B.FURN)
	ss(ck, x+4, y+1, z+1, B.PLNK); ss(ck, x+5, y+1, z+1, B.PLNK)
	for dy = 0, 6 do ss(ck, x+6, y+dy, z+5, B.COB) end
	for dz = -2, 6 do
		for dx = -1, 7 do
			local dist = abs(dx-3)
			if dist <= 2 then ss(ck, x+dx, y+4+2-dist, z+dz, B.CABIN_WALL) end
		end
	end
	for dx = 0, 1 do ss(ck, x-1+dx, y+1, z+5, B.SLOG) end
end

local function genShrine(ck, x, y, z)
	for dx = -3, 3 do for dz = -3, 3 do ss(ck, x+dx, y, z+dz, B.TEMPLE_STONE) end end
	for _, p in ipairs({{-3,-3},{3,-3},{-3,3},{3,3}}) do
		for dy = 1, 4 do ss(ck, x+p[1], y+dy, z+p[2], B.COLUMN_BLK) end
	end
	for dx = -3, 3 do for dz = -3, 3 do ss(ck, x+dx, y+5, z+dz, B.TEMPLE_STONE) end end
	for dx = -1, 1 do for dz = -1, 1 do ss(ck, x+dx, y+1, z+dz, B.MARBLE) end end
	ss(ck, x, y+2, z, B.STATUE_STONE); ss(ck, x, y+3, z, B.STATUE_STONE)
	for dx = -3, 3 do
		ss(ck, x+dx, y, z-4, B.TEMPLE_STONE)
		ss(ck, x+dx, y, z+4, B.TEMPLE_STONE)
	end
end

local function genWatchtower(ck, x, y, z)
	local tH = 16
	for dy = 0, tH-1 do
		ss(ck, x-1, y+dy, z-1, B.SLOG); ss(ck, x+2, y+dy, z-1, B.SLOG)
		ss(ck, x-1, y+dy, z+2, B.SLOG); ss(ck, x+2, y+dy, z+2, B.SLOG)
	end
	for dy = 4, tH-1, 4 do
		for dx = -1, 2 do ss(ck, x+dx, y+dy, z-1, B.PLNK); ss(ck, x+dx, y+dy, z+2, B.PLNK) end
		for dz = 0, 1 do ss(ck, x-1, y+dy, z+dz, B.PLNK); ss(ck, x+2, y+dy, z+dz, B.PLNK) end
	end
	for dy = 0, tH-1 do ss(ck, x, y+dy, z, B.LADDER) end
	for dx = -2, 3 do for dz = -2, 3 do ss(ck, x+dx, y+tH, z+dz, B.PLNK) end end
	for dx = -2, 3 do
		ss(ck, x+dx, y+tH+1, z-2, B.FENCE_BLK)
		ss(ck, x+dx, y+tH+1, z+3, B.FENCE_BLK)
	end
	for dz = -2, 3 do
		ss(ck, x-2, y+tH+1, z+dz, B.FENCE_BLK)
		ss(ck, x+3, y+tH+1, z+dz, B.FENCE_BLK)
	end
	for dx = -1, 2 do for dz = -1, 2 do ss(ck, x+dx, y+tH+3, z+dz, B.PLNK) end end
	for dy = tH+1, tH+2 do
		ss(ck, x-1, y+dy, z-1, B.SLOG); ss(ck, x+2, y+dy, z-1, B.SLOG)
		ss(ck, x-1, y+dy, z+2, B.SLOG); ss(ck, x+2, y+dy, z+2, B.SLOG)
	end
	ss(ck, x, y+tH+4, z, B.GLOW_CRYSTAL)
end

local function genCityTower(ck, x, y, z, r)
	local w = 8+floor(r*4); local d = 8+floor(r*3)
	local floors = 5+floor(r*8); local fh = 4
	local totalH = floors*fh
	clearVolume(ck, x-1, y, z-1, w+2, d+2, mn(totalH+8, 120))
	buildRoom(ck, x, y, z, w, d, 5, B.CONCRETE, B.CONCRETE, B.METAL_PANEL, true)
	ss(ck, x+floor(w/2), y+1, z, B.DOOR_IRON_C); ss(ck, x+floor(w/2), y+2, z, B.DOOR_IRON_C)
	ss(ck, x+floor(w/2)-1, y+1, z, B.AIR); ss(ck, x+floor(w/2)-1, y+2, z, B.AIR)
	for dx = 2, w-3 do ss(ck, x+dx, y+1, z+3, B.METAL_PANEL) end
	for f = 1, floors-1 do
		local fy = y+5+(f-1)*fh
		for dy = 0, fh-1 do
			for dx = 0, w-1 do
				for dz = 0, d-1 do
					local isWall = dx==0 or dx==w-1 or dz==0 or dz==d-1
					if dy==0 then ss(ck, x+dx, fy+dy, z+dz, B.METAL_PANEL)
					elseif isWall then
						if dy==0 or dy==fh-1 then ss(ck, x+dx, fy+dy, z+dz, B.CONCRETE)
						else ss(ck, x+dx, fy+dy, z+dz, B.GLASS_TOWER) end
					end
				end
			end
		end
		for dy = 0, fh-1 do ss(ck, x+1, fy+dy, z+1, B.CONCRETE); ss(ck, x+1, fy+dy, z+2, B.LADDER) end
		local ft = f % 4
		if ft == 0 then
			for dy = 1, fh-2 do for dz = 2, d-3 do ss(ck, x+floor(w/2), fy+dy, z+dz, B.GLASS) end end
			ss(ck, x+floor(w/2), fy+1, z+floor(d/2), B.AIR); ss(ck, x+floor(w/2), fy+2, z+floor(d/2), B.AIR)
		elseif ft == 1 then
			for dx = 3, w-3, 2 do for dy = 1, fh-2 do ss(ck, x+dx, fy+dy, z+floor(d/2), B.DARK_PANEL) end end
		elseif ft == 2 then
			for dx = 3, w-3, 3 do ss(ck, x+dx, fy+1, z+floor(d/2), B.PLNK) end
			ss(ck, x+w-3, fy+1, z+2, B.FURN)
		else
			for dz = 2, d-3, 2 do ss(ck, x+2, fy+1, z+dz, B.METAL_PANEL) end
			ss(ck, x+w-3, fy+1, z+d-3, B.CHST)
		end
		ss(ck, x+2, fy+1, z+1, B.DOOR_IRON_C); ss(ck, x+2, fy+2, z+1, B.DOOR_IRON_C)
	end
	local roofY = y+5+(floors-1)*fh
	for dx = 0, w-1 do for dz = 0, d-1 do ss(ck, x+dx, roofY, z+dz, B.CONCRETE) end end
	ss(ck, x+2, roofY+1, z+2, B.METAL_PANEL); ss(ck, x+2, roofY+2, z+2, B.METAL_PANEL)
	ss(ck, x+w-3, roofY+1, z+d-3, B.METAL_PANEL)
end

local function genBrokenTower(ck, x, y, z)
	local h2 = 12 + floor(WorldUtils.dh01(x+77, z+77)*12)
	for dy = 0, h2-1 do
		local w = dy < h2*0.4 and 3 or (dy < h2*0.7 and 2 or 1)
		local intact = WorldUtils.dh01(dy*50+x, z*31) > 0.2
		local mat = dy < 4 and B.COB or B.TOWER_BRICK
		for dx = -w, w do
			for dz = -w, w do
				if abs(dx)==w and abs(dz)==w then -- skip corners
				elseif (abs(dx)==w or abs(dz)==w) and intact then ss(ck, x+dx, y+dy, z+dz, mat)
				elseif dy%5==0 and intact then ss(ck, x+dx, y+dy, z+dz, mat)
				end
			end
		end
	end
	for i = 0, 7 do
		local rx = x + floor(WorldUtils.dh01(i*33, z)*8) - 4
		local rz = z + floor(WorldUtils.dh01(x, i*33)*8) - 4
		ss(ck, rx, y, rz, B.CITY_RUBBLE)
	end
end

local function genTowerRuin(ck, x, y, z, r)
	local h2 = 12 + floor(r*15); local w = 3
	for dy = 0, h2-1 do
		local broken = dy > h2*0.5 and WorldUtils.dh01(dy*100+x, z) > 0.4
		for dx = -w, w do
			for dz = -w, w do
				if abs(dx)==w and abs(dz)==w then
				elseif (abs(dx)==w or abs(dz)==w) and not broken then
					ss(ck, x+dx, y+dy, z+dz, B.TOWER_BRICK)
				elseif dy%5==0 and not broken then
					ss(ck, x+dx, y+dy, z+dz, B.TOWER_BRICK)
				end
			end
		end
	end
	for i = 0, 7 do
		local rx = x + floor(WorldUtils.dh01(i*33, z)*8) - 4
		local rz = z + floor(WorldUtils.dh01(x, i*19)*8) - 4
		ss(ck, rx, y, rz, B.CITY_RUBBLE)
	end
end

local function genStatue(ck, x, y, z, member)
	local h2 = 10 + floor(WorldUtils.dh01(x*99, z*99)*6)
	local mat = member==0 and B.STATUE_STONE or (member==1 and B.MARBLE or B.BRONZE)
	for dx = -2, 2 do for dz = -2, 2 do for dy = 0, 2 do ss(ck, x+dx, y+dy, z+dz, B.CONCRETE) end end end
	ss(ck, x, y+2, z-2, B.BRONZE)
	for dy = 3, h2-4 do
		local w2 = dy < h2/2 and 1 or 0
		for dx = -w2, w2 do ss(ck, x+dx, y+dy, z, mat) end
		if dy > h2*0.4 and dy < h2*0.7 then ss(ck, x-1, y+dy, z, mat); ss(ck, x+1, y+dy, z, mat) end
	end
	for dx = -1, 1 do for dz = -1, 1 do for dy = h2-3, h2-1 do
		if not (abs(dx)+abs(dz) > 1 and dy==h2-1) then ss(ck, x+dx, y+dy, z+dz, mat) end
	end end end
end

local function genWaffle(ck, x, y, z)
	clearVolume(ck, x-2, y, z-4, 20, 16, 8)
	local w = 14; local d = 10
	buildRoom(ck, x, y, z, w, d, 5, B.STUCCO, B.CONCRETE, B.ROOF_TILE, true)
	for dx = 1, w-2 do ss(ck, x+dx, y+1, z+3, B.CONCRETE) end -- counter
	for dx = 2, w-3, 2 do ss(ck, x+dx, y+1, z+2, B.COB) end -- stools
	for dz = 1, d-2, 3 do
		for dx = 1, 3 do ss(ck, x+dx, y+1, z+dz, B.PLNK) end
		for dx = w-4, w-2 do ss(ck, x+dx, y+1, z+dz, B.PLNK) end
	end
	ss(ck, x+w-4, y+1, z+d-3, B.CHST)
	ss(ck, x+floor(w/2), y+1, z, B.DOOR_OAK_C); ss(ck, x+floor(w/2), y+2, z, B.DOOR_OAK_C)
	ss(ck, x+floor(w/2), y+5, z-1, B.NEON_BLK)
	for dx = -2, w+1 do for dz = -4, -1 do ss(ck, x+dx, y-1, z+dz, B.ASPHALT) end end
end

local function genChapel(ck, x, y, z)
	clearVolume(ck, x-1, y, z-1, 9, 11, 10)
	buildRoom(ck, x, y, z, 7, 9, 6, B.CHAPEL_STONE, B.STONE, B.CHAPEL_STONE, true)
	ss(ck, x+3, y+1, z, B.DOOR_OAK_C); ss(ck, x+3, y+2, z, B.DOOR_OAK_C)
	for dx = -1, 7 do for dz = -1, 9 do
		local peak = mn(abs(dx - 3), abs(6-dx-3))
		ss(ck, x+dx, y+6+floor(peak/2), z+dz, B.CHAPEL_STONE)
	end end
	for dy = 1, 3 do for dz = 2, 6 do ss(ck, x+2, y+dy, z+dz, B.PLNK) end end -- pews
	for dx = 2, 4 do for dz = 2, 4 do ss(ck, x+dx, y+1, z+6, B.MARBLE) end end
	ss(ck, x+3, y+2, z+8, B.STATUE_STONE); ss(ck, x+3, y+3, z+8, B.STATUE_STONE)
end

local function genMonument(ck, x, y, z, r)
	local h2 = 14 + floor(r*10)
	local member = floor(r*3)
	local mat = member==0 and B.MONUMENT_STN or (member==1 and B.MARBLE or B.BRONZE)
	for dx = -3, 3 do for dz = -3, 3 do for dy = 0, 3 do ss(ck, x+dx, y+dy, z+dz, B.CANYON_STONE) end end end
	for dy = 4, h2-4 do
		for dx = -1, 1 do for dz = -1, 1 do ss(ck, x+dx, y+dy, z+dz, mat) end end
		if dy > h2*0.3 and dy < h2*0.6 then
			ss(ck, x-2, y+dy, z, mat); ss(ck, x+2, y+dy, z, mat)
		end
	end
	for dx = -2, 2 do for dz = -2, 2 do for dy = h2-4, h2-1 do ss(ck, x+dx, y+dy, z+dz, mat) end end end
end

local function genBoardwalk(ck, x, y, z)
	local len = 12 + floor(WorldUtils.dh01(x*31, z*17)*6)
	for i = 0, len-1 do
		if WorldUtils.dh01(x+i*7, z*13) > 0.12 then -- intact section
			ss(ck, x+i, y+1, z, B.BOARDWALK); ss(ck, x+i, y+1, z+1, B.BOARDWALK)
			ss(ck, x+i, y+1, z+2, B.BOARDWALK)
			if i%2 == 0 then
				ss(ck, x+i, y+2, z, B.FENCE_BLK); ss(ck, x+i, y+2, z+2, B.FENCE_BLK)
			end
			-- Support posts
			if i%3 == 0 then
				for dy = -3, 0 do ss(ck, x+i, y+dy, z+1, B.SLOG) end
			end
		end
	end
end

local function genTemple(ck, x, y, z)
	local w = 12; local d = 10; local h2 = 8
	-- Stepped platform
	for step = 0, 2 do
		local sw = step*2; local sd = step*2
		for dx = sw, w-sw do for dz = sd, d-sd do ss(ck, x+dx-sw, y+step, z+dz-sd, B.TEMPLE_STONE) end end
	end
	buildRoom(ck, x+2, y+3, z+2, w-4, d-4, h2, B.TEMPLE_STONE, B.MARBLE, B.TEMPLE_STONE, true)
	for _, p in ipairs({{2,2},{w-3,2},{2,d-3},{w-3,d-3},{2,floor(d/2)},{w-3,floor(d/2)}}) do
		for dy = 4, h2+2 do ss(ck, x+p[1], y+dy, z+p[2], B.COLUMN_BLK) end
	end
	for dx = 0, 3 do ss(ck, x+dx, y+2, z+floor(d/2), B.STAIR_MARBLE) end
	ss(ck, x+w/2, y+4, z+d/2, B.MARBLE); ss(ck, x+w/2, y+5, z+d/2, B.STATUE_STONE)
	ss(ck, x+w/2, y+6, z+d/2, B.BRONZE)
	local sx, sz = x+w-4, z+4
	ss(ck, sx, y+4, sz, B.CHST)
	for _, p in ipairs({{2,2},{w-3,2},{2,d-3}}) do
		ss(ck, x+p[1], y+4, z+p[2], B.GLOW_CRYSTAL)
	end
end

local function genStadium(ck, x, y, z, r)
	local fw = 30; local fd = 20
	clearVolume(ck, x-8, y, z-8, fw+18, fd+18, 30)
	-- Field
	for dx = 0, fw-1 do for dz = 0, fd-1 do ss(ck, x+dx, y, z+dz, B.GYM_FLOOR) end end
	-- Markings
	for dx = 0, fw-1 do ss(ck, x+dx, y+1, z+floor(fd/2), B.SIDEWALK) end
	for dz = 0, fd-1 do ss(ck, x+floor(fw/2), y+1, z+dz, B.SIDEWALK) end
	-- Bleachers (4 sides, 6 tiers)
	for tier = 0, 5 do
		for dx = -1-tier, fw+tier do
			ss(ck, x+dx, y+1+tier, z-2-tier, B.STAIR_COB)
			ss(ck, x+dx, y+1+tier, z+fd+1+tier, B.STAIR_COB)
		end
		for dz = -1-tier, fd+tier do
			ss(ck, x-2-tier, y+1+tier, z+dz, B.STAIR_COB)
			ss(ck, x+fw+1+tier, y+1+tier, z+dz, B.STAIR_COB)
		end
	end
	-- Corner light towers
	for _, p in ipairs({{-8,-8},{fw+8,-8},{-8,fd+8},{fw+8,fd+8}}) do
		for dy = 0, 14 do ss(ck, x+p[1], y+dy, z+p[2], B.CONCRETE) end
		ss(ck, x+p[1], y+15, z+p[2], B.NEON_BLK)
	end
	-- Goal posts
	for _, gx in ipairs({2, fw-3}) do
		for dy = 0, 6 do ss(ck, x+gx, y+dy, z+floor(fd/2), B.METAL_PANEL) end
		for dz = -2, 2 do ss(ck, x+gx, y+6, z+floor(fd/2)+dz, B.METAL_PANEL) end
	end
	-- Entrance
	ss(ck, x+floor(fw/2), y+1, z-8, B.DOOR_IRON_C)
	ss(ck, x+floor(fw/2), y+2, z-8, B.DOOR_IRON_C)
end

local function genRestaurant(ck, x, y, z)
	local w = 20; local d = 14
	clearVolume(ck, x-2, y, z-2, w+4, d+8, 10)
	buildRoom(ck, x, y, z, w, d, 7, B.BRK, B.CARPET, B.CONCRETE, true)
	ss(ck, x+floor(w/2), y+1, z, B.DOOR_OAK_C); ss(ck, x+floor(w/2), y+2, z, B.DOOR_OAK_C)
	-- Tables and booths
	for i = 0, 4 do
		for dx = 2+i*3, 3+i*3 do
			for dz = 3, 5 do ss(ck, x+dx, y+1, z+dz, B.PLNK) end
			for dz = 8, 10 do ss(ck, x+dx, y+1, z+dz, B.PLNK) end
		end
	end
	-- Kitchen
	for dx = 0, w-1 do ss(ck, x+dx, y+1, z+d-3, B.COUNTER_TOP) end
	for i = 0, 3 do ss(ck, x+2+i*4, y+1, z+d-2, B.FURN) end
	ss(ck, x+w-2, y+1, z+d-2, B.CHST)
	-- Neon sign
	for dx = 2, w-3 do ss(ck, x+dx, y+7, z-1, B.NEON_BLK) end
	-- Parking
	for dx = -2, w+1 do for dz = d+1, d+5 do ss(ck, x+dx, y-1, z+dz, B.ASPHALT) end end
end

local function genArcade(ck, x, y, z)
	local w = 20; local d = 12
	clearVolume(ck, x-1, y, z-1, w+2, d+2, 9)
	buildRoom(ck, x, y, z, w, d, 7, B.DARK_PANEL, B.GYM_FLOOR, B.DARK_PANEL, false)
	-- Arcade cabinets (6 rows)
	for row = 0, 5 do
		local rx = x + 2 + row*3
		for dz = 2, d-3 do
			ss(ck, rx, y+1, z+dz, B.DARK_PANEL)
			ss(ck, rx, y+2, z+dz, B.GLASS)
			ss(ck, rx, y+3, z+dz, B.NEON_TRIM)
		end
	end
	-- Glow floor strips
	for dx = 0, w-1 do
		if dx%3 == 0 then
			for dz = 0, d-1 do ss(ck, x+dx, y, z+dz, B.GLOW_CRYSTAL) end
		end
	end
	ss(ck, x+floor(w/2), y+1, z, B.DOOR_DARK_C); ss(ck, x+floor(w/2), y+2, z, B.DOOR_DARK_C)
	ss(ck, x+w-3, y+1, z+d-3, B.CHST)
	-- Neon facade
	for dx = 1, w-2 do ss(ck, x+dx, y+7, z-1, B.NEON_BLK) end
	for dx = 3, w-4 do ss(ck, x+dx, y+8, z-1, B.NEON_TRIM) end
end

local function genMall(ck, x, y, z, r)
	local w = 36; local d = 24; local floors = 3; local fh = 6
	clearVolume(ck, x-2, y, z-2, w+4, d+4, floors*fh+6)
	-- Per floor
	for f = 0, floors-1 do
		local fy = y + f*fh
		-- Outer shell
		buildRoom(ck, x, fy, z, w, d, fh, B.CONCRETE, B.TILE_FLOOR, B.CONCRETE, true)
		-- Central atrium (open)
		for dx = floor(w/2)-3, floor(w/2)+3 do
			for dz = floor(d/2)-3, floor(d/2)+3 do
				ss(ck, x+dx, fy, z+dz, B.AIR) -- atrium hole
				ss(ck, x+dx, fy+fh-1, z+dz, B.GLASS) -- skylight on top floor
			end
		end
		-- Stores (5 each side)
		for i = 0, 4 do
			local sx1 = x+2+i*6; local sz1 = z+1
			local sz2 = z+d-7
			for dy = 1, fh-2 do
				for sdx = 0, 4 do
					ss(ck, sx1+sdx, fy+dy, sz1, B.CONCRETE)
					ss(ck, sx1+sdx, fy+dy, sz2, B.CONCRETE)
				end
			end
			-- Store windows
			ss(ck, sx1+2, fy+2, sz1, B.GLASS); ss(ck, sx1+2, fy+3, sz1, B.GLASS)
			ss(ck, sx1+2, fy+2, sz2, B.GLASS); ss(ck, sx1+2, fy+3, sz2, B.GLASS)
		end
		-- Stairs at both ends
		for si = 0, fh-1 do
			ss(ck, x+1, fy+si, z+si+1, B.STAIR_COB)
			ss(ck, x+w-2, fy+si, z+si+1, B.STAIR_COB)
		end
		-- Seating areas
		for i = 0, 3 do
			for dz = floor(d/2)-2, floor(d/2)+2 do
				ss(ck, x+4+i*7, fy+1, z+dz, B.PLNK)
			end
		end
	end
	-- Grand entrance
	ss(ck, x+floor(w/2)-2, y+1, z, B.DOOR_IRON_C)
	ss(ck, x+floor(w/2)-2, y+2, z, B.DOOR_IRON_C)
	ss(ck, x+floor(w/2)+2, y+1, z, B.DOOR_IRON_C)
	ss(ck, x+floor(w/2)+2, y+2, z, B.DOOR_IRON_C)
	-- Mall sign
	for dx = 4, w-5 do ss(ck, x+dx, y+floors*fh+2, z-2, B.NEON_BLK) end
	for dx = 6, w-7 do ss(ck, x+dx, y+floors*fh+3, z-2, B.NEON_TRIM) end
	-- Parking lot
	for dx = -2, w+1 do for dz = d+2, d+8 do ss(ck, x+dx, y-1, z+dz, B.ASPHALT) end end
	-- Anchor stores
	for dx = 0, 9 do for dz = 0, 7 do ss(ck, x+dx, y+1, z+d+1+dz, B.GLASS_TOWER) end end
end

local function genSchool(ck, x, y, z, r)
	local fh = 6; local mainW = 28; local mainD = 14
	clearVolume(ck, x-2, y, z-2, mainW+4, mainD+4, fh*2+6)
	-- Ground floor
	buildRoom(ck, x, y, z, mainW, mainD, fh, B.SCHOOL_WALL, B.GYM_FLOOR, B.CONCRETE, true)
	-- Second floor
	buildRoom(ck, x, y+fh, z, mainW, mainD, fh, B.SCHOOL_WALL, B.GYM_FLOOR, B.CONCRETE, true)
	-- Hallway
	for floor_n = 0, 1 do
		local fy = y + floor_n*fh
		for dx = 1, mainW-2 do
			for dy = 1, fh-2 do
				ss(ck, x+dx, fy+dy, z+floor(mainD/2), B.AIR)
			end
		end
		-- Classrooms (4 per side, ground floor)
		for i = 0, 3 do
			local cx2 = x + 2 + i*6
			-- Desks in each classroom
			for row = 0, 2 do
				for col = 0, 1 do
					ss(ck, cx2+1+col*2, fy+1, z+1+row*2, B.DESK)
				end
			end
			-- Lockers along hallway
			ss(ck, cx2, fy+1, z+floor(mainD/2)-1, B.LOCKER_BLK)
			ss(ck, cx2+1, fy+1, z+floor(mainD/2)-1, B.LOCKER2)
		end
	end
	-- Entrance
	ss(ck, x+floor(mainW/2), y+1, z, B.DOOR_IRON_C)
	ss(ck, x+floor(mainW/2), y+2, z, B.DOOR_IRON_C)
	ss(ck, x+floor(mainW/2), y+3, z, B.DOOR_IRON_C)
	-- Stairs between floors
	for si = 0, fh-1 do ss(ck, x+2, y+si, z+mainD-2, B.STAIR_COB) end
	-- Gym wing
	buildRoom(ck, x+mainW, y, z, 12, mainD, 8, B.SCHOOL_WALL, B.GYM_FLOOR, B.CONCRETE, true)
	-- Cafeteria
	buildRoom(ck, x-12, y, z, 12, mainD, fh, B.SCHOOL_WALL, B.TILE_FLOOR, B.CONCRETE, true)
	-- Football field
	for dx = -2, mainW+1 do for dz = mainD+2, mainD+20 do ss(ck, x+dx, y, z+dz, B.GRASS) end end
	-- Parking lot
	for dx = -2, mainW+1 do for dz = -8, -3 do ss(ck, x+dx, y-1, z+dz, B.ASPHALT) end end
	-- School sign
	for dx = 4, mainW-5 do ss(ck, x+dx, y+fh*2+2, z-2, B.NEON_BLK) end
	ss(ck, x+floor(mainW/2)-3, y+1, z+mainD-2, B.CHST)
end

local function genGomp(ck, x, y, z, r)
	local w = 11; local d = 11; local floors = 12 + floor(r*8); local fh = 4
	clearVolume(ck, x-1, y, z-1, w+2, d+2, mn(floors*fh+12, 140))
	-- Grand lobby (double-height)
	buildRoom(ck, x, y, z, w, d, 7, B.MARBLE, B.MARBLE, B.METAL_PANEL, true)
	ss(ck, x+floor(w/2), y+1, z, B.DOOR_IRON_C); ss(ck, x+floor(w/2), y+2, z, B.DOOR_IRON_C)
	ss(ck, x+floor(w/2), y+3, z, B.AIR); ss(ck, x+floor(w/2), y+4, z, B.AIR)
	-- Lobby pillars
	for _, p in ipairs({{1,1},{w-2,1},{1,d-2},{w-2,d-2}}) do
		for dy = 1, 6 do ss(ck, x+p[1], y+dy, z+p[2], B.COLUMN_BLK) end
	end
	-- Upper floors
	for f = 1, floors-1 do
		local fy = y+7+(f-1)*fh
		for dy = 0, fh-1 do
			for dx = 0, w-1 do
				for dz = 0, d-1 do
					local isWall = dx==0 or dx==w-1 or dz==0 or dz==d-1
					if dy==0 then ss(ck, x+dx, fy+dy, z+dz, B.METAL_PANEL)
					elseif isWall then
						if dy==fh-1 then ss(ck, x+dx, fy+dy, z+dz, B.CONCRETE)
						else ss(ck, x+dx, fy+dy, z+dz, B.GLASS_TOWER) end
					end
				end
			end
		end
		-- Elevator/stairwell
		for dy = 0, fh-1 do ss(ck, x+1, fy+dy, z+1, B.CONCRETE); ss(ck, x+1, fy+dy, z+2, B.LADDER) end
		-- Floor variation
		local ft = f % 5
		if ft == 0 then -- offices
			for dy = 1, fh-2 do for dz = 3, d-3 do ss(ck, x+floor(w/2), fy+dy, z+dz, B.GLASS) end end
		elseif ft == 1 then -- server room
			for dx = 3, w-3, 2 do for dy = 1, fh-2 do ss(ck, x+dx, fy+dy, z+floor(d/2), B.DARK_PANEL) end end
		elseif ft == 4 then -- executive floor
			ss(ck, x+w-3, fy+1, z+d-3, B.CHST)
			for dx = 2, w-3 do ss(ck, x+dx, fy+1, z+3, B.MARBLE) end
		end
	end
	-- Boss arena top floor
	local arenaY = y+7+(floors-1)*fh
	for dx = -2, w+1 do
		for dz = -2, d+1 do
			if dx == -2 or dx == w+1 or dz == -2 or dz == d+1 then
				for dy = 0, 13 do ss(ck, x+dx, arenaY+dy, z+dz, B.GLASS_TOWER) end
			end
		end
	end
	-- Pillar ring in arena
	for _, p in ipairs({{0,0},{w-1,0},{0,d-1},{w-1,d-1},{floor(w/2),2},{floor(w/2),d-3}}) do
		for dy = 0, 10 do ss(ck, x+p[1], arenaY+dy, z+p[2], B.COLUMN_BLK) end
	end
	ss(ck, x+floor(w/2), arenaY+1, z+floor(d/2), B.NEON_BLK) -- activation point
	ss(ck, x+floor(w/2)-1, arenaY+1, z+floor(d/2), B.CHST) -- treasure chest
	-- Spire
	for dy = 0, 7 do ss(ck, x+floor(w/2), arenaY+14+dy, z+floor(d/2), B.METAL_PANEL) end
	for dy = 8, 9 do ss(ck, x+floor(w/2), arenaY+14+dy, z+floor(d/2), B.NEON_BLK) end
end

local function genGarfDungeon(ck, x, y, z)
	local wx = ck.cx * CS + x
	local wz = ck.cz * CS + z
	-- Entry breach
	for dx = -6, 6 do for dz = -4, 4 do for dy = 0, 12 do
		dungeonSet(wx+dx, y+dy, wz+dz, B.DEEP, ck)
	end end end
	for dx = -4, 4 do for dz = -2, 2 do for dy = 1, 11 do
		dungeonSet(wx+dx, y+dy, wz+dz, B.AIR, ck)
	end end end
	-- Entry shaft
	for dy = 0, 10 do dungeonSet(wx, y+dy, wz, B.LADDER, ck) end
	-- Main corridor
	for dx = -7, 7 do for dz = -2, 2 do for dy = 0, 5 do
		local bv = (abs(dx)==7 or abs(dz)==2 or dy==0 or dy==5) and B.RUSTED_METAL or B.AIR
		dungeonSet(wx+dx, y-10+dy, wz+dz, bv, ck)
	end end end
	-- Neon conduits along corridor
	for dx = -6, 6, 3 do
		dungeonSet(wx+dx, y-10+4, wz-2, B.NEON_BLK, ck)
		dungeonSet(wx+dx, y-10+4, wz+2, B.NEON_BLK, ck)
	end
	-- Central arena chamber
	for dx = -12, 12 do for dz = -7, 7 do for dy = 0, 14 do
		local isWall = abs(dx)==12 or abs(dz)==7 or dy==0 or dy==14
		dungeonSet(wx+dx, y-20+dy, wz+dz, isWall and B.DEEP or B.AIR, ck)
	end end end
	-- Arena pillars
	for _, p in ipairs({{-8,-4},{8,-4},{-8,4},{8,4},{-4,0},{4,0}}) do
		for dy = 1, 12 do dungeonSet(wx+p[1], y-20+dy, wz+p[2], B.COLUMN_BLK, ck) end
	end
	-- Central mechanism platform
	for dx = -3, 3 do for dz = -3, 3 do
		dungeonSet(wx+dx, y-20, wz+dz, B.DEEP, ck)
		dungeonSet(wx+dx, y-19, wz+dz, B.MARBLE, ck)
	end end
	dungeonSet(wx, y-18, wz, B.NEON_BLK, ck) -- activation point
	-- Lava channels
	for dx = -11, 11 do
		dungeonSet(wx+dx, y-21, wz-6, B.LAVA, ck)
		dungeonSet(wx+dx, y-21, wz+6, B.LAVA, ck)
	end
	-- Machine hall
	for dx = -14, -8 do for dz = -6, 6 do for dy = 0, 8 do
		local isWall = abs(dz)==6 or dy==0 or dy==8
		dungeonSet(wx+dx, y-20+dy, wz+dz, isWall and B.RUSTED_METAL or B.AIR, ck)
	end end end
	-- Storage vault with chests
	for dx = 14, 20 do for dz = -4, 4 do for dy = 0, 7 do
		local isWall = abs(dz)==4 or dx==14 or dx==20 or dy==0 or dy==7
		dungeonSet(wx+dx, y-20+dy, wz+dz, isWall and B.DEEP or B.AIR, ck)
	end end end
	for _, off in ipairs({{15,1},{17,3},{19,-3}}) do
		dungeonSet(wx+off[1], y-19, wz+off[2], B.CHST, ck)
		-- Pre-seed chest with dungeon key
		local chestKey = (wx+off[1]) .. "," .. (y-19) .. "," .. (wz+off[2])
		if not World.chestData[chestKey] then
			World.chestData[chestKey] = {}
			World.chestData[chestKey][1] = {id=B.DUNGEON_KEY, count=1}
		end
	end
	-- Barracks/dormancy
	for dx = -6, 6 do for dz = 8, 18 do for dy = 0, 6 do
		local isWall = abs(dx)==6 or dz==8 or dz==18 or dy==0 or dy==6
		dungeonSet(wx+dx, y-20+dy, wz+dz, isWall and B.DEEP or B.AIR, ck)
	end end end
	-- Bunk beds
	for i = -4, 4, 4 do
		dungeonSet(wx+i, y-19, wz+10, B.PLNK, ck)
		dungeonSet(wx+i, y-18, wz+10, B.PLNK, ck)
		dungeonSet(wx+i, y-17, wz+10, B.PLNK, ck)
	end
	-- Control room
	for dx = -10, -4 do for dz = -18, -10 do for dy = 0, 6 do
		local isWall = abs(dx-(-7))==3 or abs(dz-(-14))==4 or dy==0 or dy==6
		dungeonSet(wx+dx, y-20+dy, wz+dz, isWall and B.DARK_PANEL or B.AIR, ck)
	end end end
	for dz = -17, -11 do dungeonSet(wx-9, y-19, wz+dz, B.SIGNAL_STONE, ck) end
	-- Garfbot spawn markers (18 positions)
	local spawnPositions = {
		{0,-19,0}, {-6,-15,0}, {6,-15,0}, {0,-15,-5}, {0,-15,5},
		{-10,-19,-3}, {10,-19,-3}, {0,-19,12}, {-4,-19,8}, {4,-19,8},
		{-8,-19,-8}, {8,-19,-8}, {-10,-15,-5}, {10,-15,-5},
		{-8,-15,0}, {8,-15,0}, {0,-15,-10}, {0,-23,0},
	}
	for _, sp in ipairs(spawnPositions) do
		-- Store spawn positions for mob manager to use
		local key = "dungeon_spawn"
		if not World.structRegistry[key] then World.structRegistry[key] = {} end
		table.insert(World.structRegistry[key], {x=wx+sp[1], y=y+sp[2], z=wz+sp[3]})
	end
end

-- ─── Structure dispatch ──────────────────────────────────────────────────────
local _structQ = {}

local function genStructure(chunk, ox, oz, wx, wz, h, bi)
	local bd = BDt[bi]
	if not bd.structs then return end
	local ck = WorldUtils.chunkKey(chunk.cx, chunk.cz)
	if World.structChunks[ck] then return end
	if World.hasRail[ck] then return end
	if wx ~= ox + 8 or wz ~= oz + 8 then return end -- only check chunk center
	local sr = WorldUtils.dh01(chunk.cx*7+13, chunk.cz*11+7)
	local threshold = 0.975
	if bi == BI.VC_SUBURB then threshold = 0.965
	elseif bi == BI.SA_PLAINS then threshold = 0.97
	elseif bi == BI.GARFBOT_CITY then threshold = 0.94
	elseif bi == BI.DISCORD_DEEP then threshold = 0.96
	end
	if sr < threshold then return end
	-- Inter-structure spacing
	for sk, _ in pairs(World.structChunks) do
		local parts = sk:split(",")
		local scx = tonumber(parts[1]); local scz = tonumber(parts[2])
		local ddx = abs(chunk.cx - scx); local ddz = abs(chunk.cz - scz)
		if ddx <= 2 and ddz <= 2 and (ddx + ddz) > 0 then return end
	end
	World.structChunks[ck] = true
	local structs = bd.structs
	local stype = structs[floor(WorldUtils.dh01(chunk.cx+999, chunk.cz+999) * #structs) + 1]
	local r = WorldUtils.dh01(chunk.cx+50, chunk.cz+50)
	-- Rejection for major structures
	local rejMap = {school=0.90, stadium=0.93, mall=0.88, gomp=0.85, restaurant=0.75,
		waffle=0.72, temple=0.88, monument=0.90, arcade=0.78, house=0.40}
	if rejMap[stype] and WorldUtils.dh01(chunk.cx*31, chunk.cz*37) < rejMap[stype] then return end
	local lx = 8; local lz = 8
	chunk._hasStruct = true
	local wx2 = chunk.cx*CS+lx; local wz2 = chunk.cz*CS+lz
	if stype == "condo" then table.insert(_structQ, function() genCondo(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "statue" then table.insert(_structQ, function() genStatue(chunk,lx,h+1,lz,floor(WorldUtils.dh01(chunk.cx+77,chunk.cz+77)*3)) chunk.dirty=true end)
	elseif stype == "house" then table.insert(_structQ, function() genHouse(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "cabin" then table.insert(_structQ, function() genCabin(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "tower_ruin" then table.insert(_structQ, function() genTowerRuin(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "shrine" then table.insert(_structQ, function() genShrine(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "watchtower" then table.insert(_structQ, function() genWatchtower(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "tower" then table.insert(_structQ, function() genCityTower(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "broken_tower" then table.insert(_structQ, function() genBrokenTower(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "waffle" then table.insert(_structQ, function() genWaffle(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "school" then table.insert(_structQ, function() genSchool(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "gomp" then table.insert(_structQ, function() genGomp(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "boardwalk" then table.insert(_structQ, function() genBoardwalk(chunk,lx,h,lz) chunk.dirty=true end)
	elseif stype == "chapel" then table.insert(_structQ, function() genChapel(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "monument" then table.insert(_structQ, function() genMonument(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "stadium" then table.insert(_structQ, function() genStadium(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "restaurant" then table.insert(_structQ, function() genRestaurant(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "arcade" then table.insert(_structQ, function() genArcade(chunk,lx,h+1,lz) chunk.dirty=true end)
	elseif stype == "mall" then table.insert(_structQ, function() genMall(chunk,lx,h+1,lz,r) chunk.dirty=true end)
	elseif stype == "temple" then table.insert(_structQ, function() genTemple(chunk,lx,h+1,lz) chunk.dirty=true end)
	end
end

-- ─── Pirate Ship generation ──────────────────────────────────────────────────
local function genPirateShip(ck, x, y, z, tier)
	local sizes = {8, 12, 16, 22}
	local depths = {3, 4, 5, 7}
	local heights = {6, 8, 11, 15}
	local w = sizes[tier+1]; local hd = depths[tier+1]; local sh = heights[tier+1]
	local d = w - 4

	-- Hull
	for dy = 0, hd-1 do
		for dx = 0, w-1 do
			for dz = 0, d-1 do
				local isWall = dx==0 or dx==w-1 or dz==0 or dz==d-1
				local mat = dy < 2 and B.BARNACLE_WOOD or B.SHIP_TIMBER
				if isWall or dy == 0 then ss(ck, x+dx, y-dy, z+dz, mat) end
			end
		end
	end
	-- Deck
	for dx = 0, w-1 do for dz = 0, d-1 do ss(ck, x+dx, y+1, z+dz, B.PIRATE_PLNK) end end
	-- Rails
	for dx = 0, w-1 do ss(ck, x+dx, y+2, z, B.FENCE_BLK); ss(ck, x+dx, y+2, z+d, B.FENCE_BLK) end
	for dz = 0, d do ss(ck, x, y+2, z+dz, B.FENCE_BLK); ss(ck, x+w, y+2, z+dz, B.FENCE_BLK) end
	-- Mast
	local mastH = sh
	for dy = 2, mastH+2 do ss(ck, x+floor(w/2), y+dy, z+floor(d/2), B.SLOG) end
	-- Sails
	for dy = 4, mastH do
		local rad = mn(dy - 3, mastH - dy + 2, 4)
		for dx = -rad, rad do ss(ck, x+floor(w/2)+dx, y+dy, z+floor(d/2)-1, B.SAIL_BLK) end
	end
	-- Captain cabin (tier 1+)
	if tier >= 1 then
		buildRoom(ck, x+w-5, y+1, z+1, 4, d-2, 4, B.SHIP_TIMBER, B.PIRATE_PLNK, B.SHIP_TIMBER, true)
		ss(ck, x+w-3, y+2, z+floor(d/2), B.CHST)
	end
	-- Lower deck (tier 1+)
	if tier >= 1 then
		for dx = 1, w-2 do for dz = 1, d-2 do
			for dy = 1, hd-2 do ss(ck, x+dx, y-dy, z+dz, B.AIR) end
		end end
		for dy = 1, hd-2 do ss(ck, x+2, y-dy, z+floor(d/2), B.LADDER) end
		ss(ck, x+3, y-2, z+2, B.FURN); ss(ck, x+w-4, y-2, z+d-3, B.CHST)
	end
end

-- ─── Rail system ─────────────────────────────────────────────────────────────
local function genRails(chunk)
	local cx = chunk.cx; local cz = chunk.cz
	local ck_key = WorldUtils.chunkKey(cx, cz)

	local doEW = (cz % 16 == 0)
	local doNS = (cx % 20 == 0)
	if not doEW and not doNS then return end

	-- Skip in certain biomes and structures
	local midWX = cx*CS + 8; local midWZ = cz*CS + 8
	local bi = BiomeData.bio(midWX, midWZ)
	if bi == BI.OC or bi == BI.VCLANTIS or bi == BI.PROPS_ISLAND then return end
	if World.structChunks[ck_key] then return end

	World.hasRail[ck_key] = true

	if doEW then
		-- East-West rail at z=8
		local prevH = nil
		for lx = 0, CS-1 do
			local wx = cx*CS + lx; local wz = cz*CS + 8
			local bi2 = BiomeData.bio(wx, wz)
			local h = BiomeData.htA(wx, wz, bi2)
			-- Check if water
			if h < WL then
				-- Bridge over water
				local railY = WL + 1
				if prevH then railY = prevH end
				ss(chunk, lx, railY, 8, lx%8==0 and B.RAIL_POWERED or B.RAIL_IRON)
				ss(chunk, lx, railY-1, 8, B.GRAV)
			else
				local railY = h + 1
				if prevH then railY = mn(prevH + 1, mx(prevH - 1, railY)) end
				ss(chunk, lx, railY, 8, lx%8==0 and B.RAIL_POWERED or B.RAIL_IRON)
				ss(chunk, lx, railY-1, 8, B.GRAV)
				prevH = railY
			end
		end
	end

	if doNS then
		-- North-South rail at x=8
		local prevH = nil
		for lz = 0, CS-1 do
			local wx = cx*CS + 8; local wz = cz*CS + lz
			local bi2 = BiomeData.bio(wx, wz)
			local h = BiomeData.htA(wx, wz, bi2)
			if h < WL then
				local railY = WL + 1
				if prevH then railY = prevH end
				ss(chunk, 8, railY, lz, lz%8==0 and B.RAIL_POWERED or B.RAIL_IRON)
				ss(chunk, 8, railY-1, lz, B.GRAV)
			else
				local railY = h + 1
				if prevH then railY = mn(prevH + 1, mx(prevH - 1, railY)) end
				ss(chunk, 8, railY, lz, lz%8==0 and B.RAIL_POWERED or B.RAIL_IRON)
				ss(chunk, 8, railY-1, lz, B.GRAV)
				prevH = railY
			end
		end
	end

	-- Station at intersections (EW and NS cross)
	if doEW and doNS then
		local stationX = 8; local stationZ = 8
		local h = BiomeData.htA(cx*CS+stationX, cz*CS+stationZ, bi)
		if h >= WL then
			-- Platform
			for dx = 4, 12 do for dz = 4, 12 do ss(chunk, dx, h+2, dz, B.PLATFORM_BLK) end end
			-- Shelter
			for dy = 1, 3 do
				for dx = 5, 11 do ss(chunk, dx, h+2+dy, 4, B.METAL_PANEL) end
				ss(chunk, 5, h+2+dy, 4, B.CONCRETE); ss(chunk, 11, h+2+dy, 4, B.CONCRETE)
			end
			for dx = 5, 11 do ss(chunk, dx, h+5, 4, B.METAL_PANEL) end
			-- Bench
			for dx = 6, 10 do ss(chunk, dx, h+3, 5, B.PLNK) end
			-- Sign
			ss(chunk, 8, h+6, 4, B.NEON_BLK)
			table.insert(World.stations, {x=cx*CS+stationX, y=h+2, z=cz*CS+stationZ})
		end
	end
end

-- ─── Decoration pass ─────────────────────────────────────────────────────────
local function deco(chunk)
	local nT, nM, nE, nC, nD, nR, nS, nB = BiomeData.getNoise()

	for lx = 0, CS-1 do
		for lz = 0, CS-1 do
		  repeat -- used as continue-block; break = skip rest
			local wx = chunk.cx * CS + lx
			local wz = chunk.cz * CS + lz
			local bi = BiomeData.bio(wx, wz)
			local bd = BDt[bi]
			local h = BiomeData.htA(wx, wz, bi)
			if h < 0 or h >= CH-2 then break end

			local surfaceB = getBlock(chunk, lx, h, lz)
			if surfaceB == B.AIR or surfaceB == B.WATER then break end

			-- Structure generation (checked only at chunk center)
			genStructure(chunk, chunk.cx*CS, chunk.cz*CS, wx, wz, h, bi)

			-- Trees
			if bd.tr and bd.tc then
				local treeRoll = WorldUtils.dh01(wx*771 + 3, wz*991 + 7)
				local tc = bd.tc
				-- Biome mixing
				local ttype = bd.tr
				local r3 = WorldUtils.dh01(wx*221, wz*331)
				if bi == BI.NICSHADE then
					if r3 < 0.08 then ttype = "oak"
					elseif r3 < 0.12 then ttype = "dark" end
				elseif bi == BI.PLAINS then
					if r3 < 0.20 then ttype = "birch"
					elseif r3 < 0.45 then ttype = "oak"
					else ttype = "acacia" end
				end
				if treeRoll < tc and not chunk._hasStruct then
					if h > WL and surfaceB ~= B.SNOW and surfaceB ~= B.STONE then
						placeTree(chunk, lx, h+1, lz, ttype)
					end
				end
			end

			-- Cactus in desert biomes
			if bd.ca and WorldUtils.dh01(wx*333, wz*444) < bd.ca then
				if h > WL then
					local cactH = 2 + floor(WorldUtils.dh01(wx*55, wz*66) * 3)
					for dy = 1, cactH do ss(chunk, lx, h+dy, lz, B.CACT) end
				end
			end

			-- Biome-specific decorations
			if bi == BI.OC then
				-- Coral reefs
				if h < WL - 3 and WorldUtils.dh01(wx*111, wz*222) < 0.04 then
					local ctype = ({B.CORAL_PINK, B.CORAL_BLUE, B.CORAL_YELLOW})[floor(WorldUtils.dh01(wx,wz)*3)+1]
					ss(chunk, lx, h+1, lz, ctype)
				end
				if h < WL - 2 and WorldUtils.dh01(wx*333, wz*555) < 0.06 then
					for dy = 1, 3 do
						if h + dy < WL then ss(chunk, lx, h+dy, lz, B.KELP) end
					end
				end
				if h < WL and WorldUtils.dh01(wx*777, wz*888) < 0.008 then
					ss(chunk, lx, h+1, lz, B.SEA_LANTERN)
				end
				-- Pirate ship (rare)
				if WorldUtils.dh01(wx*9999, wz*8888) < 0.002 and lx == 8 and lz == 8 then
					local tier = floor(WorldUtils.dh01(chunk.cx*41, chunk.cz*53)*4)
					genPirateShip(chunk, lx-6, WL, lz-4, tier)
				end

			elseif bi == BI.VOLCANO then
				-- Obsidian/basalt spires
				if h > 220 and WorldUtils.dh01(wx*555, wz*666) < 0.03 then
					for dy = 1, 4+floor(WorldUtils.dh01(wx,wz)*6) do ss(chunk, lx, h+dy, lz, B.OBSIDIAN) end
				end
				if WorldUtils.dh01(wx*123, wz*456) < 0.015 then
					for dy = 1, 3 do ss(chunk, lx, h+dy, lz, B.BASALT) end
				end
				-- Lava pools
				if h <= WL and WorldUtils.dh01(wx*789, wz*012) < 0.04 then
					ss(chunk, lx, h, lz, B.LAVA)
				end

			elseif bi == BI.VCLANTIS then
				-- Underwater ruins handled in main deco path
				-- Grand hall columns
				if WorldUtils.dh01(wx*777, wz*999) < 0.04 and h < WL - 10 then
					for dy = 1, 8 do ss(chunk, lx, h+dy, lz, B.COLUMN_BLK) end
					ss(chunk, lx, h+9, lz, B.TEMPLE_STONE)
				end
				if WorldUtils.dh01(wx*444, wz*666) < 0.02 and h < WL - 5 then
					ss(chunk, lx, h+1, lz, B.SEA_LANTERN)
				end

			elseif bi == BI.DISCORD_DEEP then
				-- Glow crystals
				if WorldUtils.dh01(wx*321, wz*654) < 0.05 then
					for dy = 1, 2+floor(WorldUtils.dh01(wx,wz)*3) do ss(chunk, lx, h+dy, lz, B.GLOW_CRYSTAL) end
				end
				if WorldUtils.dh01(wx*987, wz*123) < 0.04 then
					ss(chunk, lx, h+1, lz, B.SIGNAL_STONE)
				end
				if WorldUtils.dh01(wx*147, wz*258) < 0.03 then
					ss(chunk, lx, h+1, lz, B.NEON_BLK)
				end

			elseif bi == BI.RIO_LAGOON then
				-- Jungle floor flora
				if WorldUtils.dh01(wx*113, wz*447) < 0.18 then ss(chunk, lx, h+1, lz, B.TALL_GRASS) end
				if WorldUtils.dh01(wx*229, wz*334) < 0.06 then ss(chunk, lx, h+1, lz, B.FERN) end
				if WorldUtils.dh01(wx*771, wz*882) < 0.04 then ss(chunk, lx, h+1, lz, B.SHRUB) end
				if WorldUtils.dh01(wx*662, wz*991) < 0.03 then ss(chunk, lx, h+1, lz, B.GLOW_FLOWER) end
				if h <= WL + 2 and WorldUtils.dh01(wx*554, wz*443) < 0.05 then ss(chunk, lx, h+1, lz, B.REED) end
				if WorldUtils.dh01(wx*332, wz*221) < 0.04 then ss(chunk, lx, h+1, lz, B.VINE_STONE) end

			elseif bi == BI.NICSHADE then
				if WorldUtils.dh01(wx*881, wz*772) < 0.08 then ss(chunk, lx, h+1, lz, B.GLOW_FLOWER) end
				if WorldUtils.dh01(wx*443, wz*556) < 0.04 then ss(chunk, lx, h+1, lz, B.VINE_STONE) end
				if WorldUtils.dh01(wx*225, wz*338) < 0.06 then ss(chunk, lx, h+1, lz, B.MOSS) end
				if WorldUtils.dh01(wx*119, wz*447) < 0.12 then ss(chunk, lx, h+1, lz, B.SHRUB) end

			elseif bi == BI.CAMGROVE then
				if WorldUtils.dh01(wx*663, wz*774) < 0.04 then ss(chunk, lx, h+1, lz, B.TRAIL_STONE) end
				if WorldUtils.dh01(wx*119, wz*228) < 0.12 then ss(chunk, lx, h+1, lz, B.TALL_GRASS) end
				if WorldUtils.dh01(wx*337, wz*449) < 0.05 then ss(chunk, lx, h+1, lz, B.SHRUB) end

			elseif bi == BI.TAIGA or bi == BI.SNOWY then
				if WorldUtils.dh01(wx*551, wz*662) < 0.06 then ss(chunk, lx, h+1, lz, B.TALL_GRASS) end

			elseif bi == BI.PLAINS then
				local fr = WorldUtils.dh01(wx*119, wz*337)
				if fr < 0.10 then ss(chunk, lx, h+1, lz, B.TALL_GRASS)
				elseif fr < 0.13 then ss(chunk, lx, h+1, lz, B.FLOWER_RED)
				elseif fr < 0.16 then ss(chunk, lx, h+1, lz, B.FLOWER_BLUE)
				elseif fr < 0.18 then ss(chunk, lx, h+1, lz, B.FLOWER_YELLOW)
				elseif fr < 0.21 then ss(chunk, lx, h+1, lz, B.SHRUB)
				end

			elseif bi == BI.WATCHER then
				if WorldUtils.dh01(wx*441, wz*552) < 0.02 then ss(chunk, lx, h+1, lz, B.TOWER_BRICK) end
				if WorldUtils.dh01(wx*883, wz*994) < 0.01 then ss(chunk, lx, h+1, lz, B.ANCIENT_METAL) end

			elseif bi == BI.DRY_COAST then
				if WorldUtils.dh01(wx*559, wz*661) < 0.03 then ss(chunk, lx, h+1, lz, B.BOARDWALK) end
				if WorldUtils.dh01(wx*773, wz*884) < 0.02 then ss(chunk, lx, h+1, lz, B.POOL_TILE) end

			elseif bi == BI.REDWOOD then
				if WorldUtils.dh01(wx*331, wz*442) < 0.06 then ss(chunk, lx, h+1, lz, B.SHRUB) end
				if WorldUtils.dh01(wx*553, wz*664) < 0.04 then ss(chunk, lx, h+1, lz, B.FERN) end

			elseif bi == BI.BE then
				if h <= WL + 2 and WorldUtils.dh01(wx*221, wz*332) < 0.04 then ss(chunk, lx, h+1, lz, B.REED) end
			end

			-- Garfbot dungeon (rare underground)
			if WorldUtils.dh01(wx*12345, wz*67890) < 0.008 and lx == 4 and lz == 4 then
				local dungeonY = h - 15
				if dungeonY > 20 and dungeonY < 60 then
					genGarfDungeon(chunk, lx, dungeonY, lz)
				end
			end

		  until true  -- end of continue-block
		end
	end

	-- Cave decorations (only below terrain surface to prevent surface leakage)
	for lx = 0, CS-1 do
		for lz = 0, CS-1 do
			local wx = chunk.cx * CS + lx
			local wz = chunk.cz * CS + lz
			local bi_c = BiomeData.bio(wx, wz)
			local h_surf = BiomeData.htA(wx, wz, bi_c)
			for y = 5, math.min(180, h_surf - 3) do
				local bv = getBlock(chunk, lx, y, lz)
				if bv == B.AIR then
					-- Check cave biome
					local cv = nC:n3(wx*0.008, y*0.01, wz*0.008)
					-- Lush cave: glow flowers, moss
					if cv > 0.3 then
						if getBlock(chunk, lx, y-1, lz) ~= B.AIR then
							if WorldUtils.dh01(wx*11+y, wz*13) < 0.03 then
								ss(chunk, lx, y, lz, B.GLOW_FLOWER)
							elseif WorldUtils.dh01(wx*17+y, wz*19) < 0.04 then
								ss(chunk, lx, y-1, lz, B.MOSS)
							end
						end
					-- Crystal cave: glow crystals
					elseif cv < -0.3 then
						if getBlock(chunk, lx, y-1, lz) ~= B.AIR then
							if WorldUtils.dh01(wx*23+y, wz*29) < 0.04 then
								for dy = 0, 1+floor(WorldUtils.dh01(wx,wz+y)*3) do
									ss(chunk, lx, y+dy, lz, B.GLOW_CRYSTAL)
								end
							end
						end
					end
					-- Lava pools in deep caves
					if cv > 0.2 and y < 80 then
						if getBlock(chunk, lx, y-1, lz) ~= B.AIR then
							if WorldUtils.dh01(wx*31+y, wz*37) < 0.01 then
								ss(chunk, lx, y, lz, B.LAVA)
							end
						end
					end
				end
			end
		end
	end

	chunk.dirty = true
end

-- ─── Main chunk generator ──────────────────────────────────────────────────
function genChunk(chunk)
	if chunk.generated then return end
	chunk.generated = true

	-- Terrain fill (yield every 4 columns to avoid timeout)
	for lx = 0, CS-1 do
		for lz = 0, CS-1 do
			genTerrainColumn(chunk, lx, lz)
		end
		if lx % 4 == 3 then task.wait() end
	end

	carveCaves(chunk)
	task.wait()

	genRails(chunk)
	deco(chunk)
	task.wait()

	applyPending(chunk)
	chunk.dirty = true
end

-- ─── Async chunk generation (used for pre-generation) ────────────────────────
local generating = {}  -- keys currently being generated

local function genChunkAsync(cx, cz)
	local key = WorldUtils.chunkKey(cx, cz)
	if World.chunks[key] or generating[key] then return end
	generating[key] = true
	task.spawn(function()
		local chunk = newChunk(cx, cz)
		local ok, err = pcall(genChunk, chunk)
		if not ok then warn("genChunk error:", cx, cz, err) end
		World.chunks[key] = chunk
		generating[key]   = nil
	end)
end

-- ─── Public world API ─────────────────────────────────────────────────────────
function World.getBlock(wx, wy, wz)
	if wy < 0 or wy >= CH then return B.AIR end
	local cx = floor(wx / CS); local cz = floor(wz / CS)
	local lx = wx % CS; if lx < 0 then lx = lx + CS end
	local lz = wz % CS; if lz < 0 then lz = lz + CS end
	local key = WorldUtils.chunkKey(cx, cz)
	local chunk = World.chunks[key]
	if not chunk then return B.AIR end
	return getBlock(chunk, lx, wy, lz)
end

function World.setBlock(wx, wy, wz, bv)
	if wy < 0 or wy >= CH then return end
	local cx = floor(wx / CS); local cz = floor(wz / CS)
	local lx = wx % CS; if lx < 0 then lx = lx + CS end
	local lz = wz % CS; if lz < 0 then lz = lz + CS end
	local key = WorldUtils.chunkKey(cx, cz)
	local chunk = World.chunks[key]
	if not chunk then return end
	setBlock(chunk, lx, wy, lz, bv)
	chunk.dirty = true
	-- Broadcast to clients
	RE[WorldUtils.RE.BLOCK_SET]:FireAllClients(wx, wy, wz, bv)
end

-- ─── Network handlers ─────────────────────────────────────────────────────────

-- Client requests chunk data
getChunkRF.OnServerInvoke = function(player, cx, cz)
	local key = WorldUtils.chunkKey(cx, cz)
	-- Start async gen if not already underway
	if not World.chunks[key] then
		genChunkAsync(cx, cz)
	end
	-- Wait up to 15s for it to be ready
	local deadline = tick() + 15
	while not World.chunks[key] and tick() < deadline do
		task.wait(0.05)
	end
	if not World.chunks[key] then
		-- Emergency flat fallback
		warn("WorldGen: timeout generating chunk", cx, cz)
		local chunk = newChunk(cx, cz)
		for lx = 0, CS-1 do
			for lz = 0, CS-1 do
				for y = 0, 125 do
					local bv = (y < 3) and B.BED or (y < 122) and B.STONE or (y == 122) and B.DIRT or (y >= 123 and y <= 124) and B.DIRT or B.GRASS
					chunk.blk[y*CS*CS + lz*CS + lx] = bv
				end
			end
		end
		World.chunks[key] = chunk
	end
	return World.chunks[key].blk
end

-- Client sets block
RE[WorldUtils.RE.BLOCK_SET].OnServerEvent:Connect(function(player, wx, wy, wz, bv)
	World.setBlock(wx, wy, wz, bv)
	-- Broadcast to all OTHER clients
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			RE[WorldUtils.RE.BLOCK_SET]:FireClient(p, wx, wy, wz, bv)
		end
	end
end)

-- Interact with block
RE[WorldUtils.RE.INTERACT].OnServerEvent:Connect(function(player, wx, wy, wz, action, data)
	local bv = World.getBlock(wx, wy, wz)
	local BTP = require(Shared.BlockTypes)
	local Bx = BTP.B

	-- Door toggle
	if BTP.DOOR_TOGGLE[bv] then
		local newB = BTP.DOOR_TOGGLE[bv]
		World.setBlock(wx, wy, wz, newB)
		return
	end

	-- Chest open
	if bv == Bx.CHST then
		local key = wx .. "," .. wy .. "," .. wz
		if not World.chestData[key] then World.chestData[key] = {} end
		RE[WorldUtils.RE.CHEST_DATA]:FireClient(player, wx, wy, wz, World.chestData[key])
		return
	end

	-- Boss activation
	if bv == Bx.NEON_BLK and action == "boss_activate" then
		RE[WorldUtils.RE.SPAWN_BOSS]:FireAllClients(wx, wy, wz)
		return
	end
end)

-- Chest update
RE[WorldUtils.RE.CHEST_UPDATE].OnServerEvent:Connect(function(player, wx, wy, wz, slotData)
	local key = wx .. "," .. wy .. "," .. wz
	World.chestData[key] = slotData
end)

-- ─── Initialize ───────────────────────────────────────────────────────────────
local function init()
	World.seed = Random.new():NextInteger(1, 2147483647)
	BiomeData.initNoise(World.seed)
	-- Pre-generate spawn area asynchronously (7x7 around origin)
	for cx = -3, 3 do
		for cz = -3, 3 do
			genChunkAsync(cx, cz)
		end
	end
	print("VC CRAFT World initialized. Seed: " .. World.seed)
end

-- Players joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Send world seed and initial data
		task.wait(1)
		RE[WorldUtils.RE.GAME_STATE]:FireClient(player, {
			seed = World.seed,
			dayTime = 0.25,
		})
	end)
end)

-- Process structure queue every frame (budget limited)
RunService.Heartbeat:Connect(function(dt)
	if #_structQ > 0 then
		local start = tick()
		while #_structQ > 0 and tick() - start < 0.005 do
			local fn = table.remove(_structQ, 1)
			local ok, err = pcall(fn)
			if not ok then warn("Structure error: " .. tostring(err)) end
		end
	end
end)

init()
