-- VC CRAFT Voxel Renderer Client
-- Greedy-merged meshing with liquid surface optimisation and sparse Y scanning
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")

local Shared     = ReplicatedStorage:WaitForChild("Shared")
local C          = require(Shared.Constants)
local BT         = require(Shared.BlockTypes)
local WorldUtils = require(Shared.WorldUtils)

local B  = BT.B
local BD = BT.BD
local BC = BT.BC
local CS = C.CS
local CH = C.CH
local BS = C.BLOCK_SIZE
local WL = C.WL
local floor = math.floor
local abs   = math.abs

local player = Players.LocalPlayer

-- ─── Material map ─────────────────────────────────────────────────────────────
local BLOCK_MATERIAL = {}
do
	local M = Enum.Material
	-- Terrain
	BLOCK_MATERIAL[B.GRASS]        = M.Grass
	BLOCK_MATERIAL[B.DIRT]         = M.Ground
	BLOCK_MATERIAL[B.STONE]        = M.Rock
	BLOCK_MATERIAL[B.SAND]         = M.Sand
	BLOCK_MATERIAL[B.GRAV]         = M.Pebble
	BLOCK_MATERIAL[B.CLAY]         = M.Ground
	BLOCK_MATERIAL[B.RSAND]        = M.Sand
	BLOCK_MATERIAL[B.MUD]          = M.Ground
	BLOCK_MATERIAL[B.DEEP]         = M.Slate
	BLOCK_MATERIAL[B.MOSS]         = M.Grass
	BLOCK_MATERIAL[B.DRY_GRASS]    = M.Grass
	BLOCK_MATERIAL[B.VINE_STONE]   = M.Grass
	BLOCK_MATERIAL[B.WATCHER_SAND] = M.Sand
	BLOCK_MATERIAL[B.ASH_STONE]    = M.Rock
	BLOCK_MATERIAL[B.SCORCHED]     = M.Rock
	BLOCK_MATERIAL[B.BASALT]       = M.Basalt
	BLOCK_MATERIAL[B.OBSIDIAN]     = M.Slate
	BLOCK_MATERIAL[B.CANYON_STONE] = M.Rock
	BLOCK_MATERIAL[B.MONUMENT_STN] = M.Rock
	BLOCK_MATERIAL[B.COB]          = M.Cobblestone
	BLOCK_MATERIAL[B.SSTON]        = M.Sandstone
	BLOCK_MATERIAL[B.SBK]          = M.Cobblestone
	BLOCK_MATERIAL[B.BRK]          = M.Brick
	BLOCK_MATERIAL[B.MARBLE]       = M.SmoothPlastic
	BLOCK_MATERIAL[B.SEA_MARBLE]   = M.SmoothPlastic
	BLOCK_MATERIAL[B.COLUMN_BLK]   = M.SmoothPlastic
	BLOCK_MATERIAL[B.TEMPLE_STONE] = M.SmoothPlastic
	-- Ores (rock look)
	BLOCK_MATERIAL[B.COAL]         = M.Rock
	BLOCK_MATERIAL[B.IRON]         = M.Rock
	BLOCK_MATERIAL[B.GOLD]         = M.Rock
	BLOCK_MATERIAL[B.DIAM]         = M.Rock
	-- Wood
	BLOCK_MATERIAL[B.OLOG]         = M.Wood
	BLOCK_MATERIAL[B.SLOG]         = M.Wood
	BLOCK_MATERIAL[B.BLOG]         = M.Wood
	BLOCK_MATERIAL[B.DLOG]         = M.Wood
	BLOCK_MATERIAL[B.JLOG]         = M.Wood
	BLOCK_MATERIAL[B.ALOG]         = M.Wood
	BLOCK_MATERIAL[B.NICSHADE_LOG] = M.Wood
	BLOCK_MATERIAL[B.REDWOOD_LOG]  = M.Wood
	BLOCK_MATERIAL[B.PLNK]         = M.WoodPlanks
	BLOCK_MATERIAL[B.OLVS]         = M.Grass
	BLOCK_MATERIAL[B.SLVS]         = M.Grass
	BLOCK_MATERIAL[B.BLVS]         = M.Grass
	BLOCK_MATERIAL[B.DLVS]         = M.Grass
	BLOCK_MATERIAL[B.JLVS]         = M.Grass
	BLOCK_MATERIAL[B.ALVS]         = M.Grass
	BLOCK_MATERIAL[B.NICSHADE_LVS] = M.Grass
	BLOCK_MATERIAL[B.REDWOOD_LVS]  = M.Grass
	-- Glass
	BLOCK_MATERIAL[B.GLASS]        = M.Glass
	BLOCK_MATERIAL[B.GLASS_TOWER]  = M.Glass
	-- Ice/Snow
	BLOCK_MATERIAL[B.ICE]          = M.Ice
	BLOCK_MATERIAL[B.SNOW]         = M.Snow
	-- Metal/Urban
	BLOCK_MATERIAL[B.METAL_PANEL]  = M.Metal
	BLOCK_MATERIAL[B.BRONZE]       = M.Metal
	BLOCK_MATERIAL[B.RUSTED_METAL] = M.CorrodedMetal
	BLOCK_MATERIAL[B.ANCIENT_METAL]= M.Metal
	BLOCK_MATERIAL[B.DARK_PANEL]   = M.Metal
	BLOCK_MATERIAL[B.RAIL_BLK]     = M.Metal
	BLOCK_MATERIAL[B.RAIL_IRON]    = M.Metal
	BLOCK_MATERIAL[B.RAIL_POWERED] = M.Neon
	BLOCK_MATERIAL[B.PLATFORM_BLK] = M.Metal
	BLOCK_MATERIAL[B.LOCKER_BLK]   = M.Metal
	BLOCK_MATERIAL[B.CONCRETE]     = M.Concrete
	BLOCK_MATERIAL[B.ASPHALT]      = M.SmoothPlastic
	BLOCK_MATERIAL[B.SIDEWALK]     = M.Concrete
	BLOCK_MATERIAL[B.CRACK_PAVE]   = M.Concrete
	BLOCK_MATERIAL[B.DRIVEWAY]     = M.Concrete
	BLOCK_MATERIAL[B.STUCCO]       = M.SmoothPlastic
	BLOCK_MATERIAL[B.CONDO_WALL]   = M.SmoothPlastic
	BLOCK_MATERIAL[B.SCHOOL_WALL]  = M.SmoothPlastic
	BLOCK_MATERIAL[B.RESORT_WALL]  = M.SmoothPlastic
	BLOCK_MATERIAL[B.POOL_TILE]    = M.SmoothPlastic
	BLOCK_MATERIAL[B.CABIN_WALL]   = M.Wood
	BLOCK_MATERIAL[B.CHAPEL_STONE] = M.SmoothPlastic
	BLOCK_MATERIAL[B.SIDING]       = M.SmoothPlastic
	BLOCK_MATERIAL[B.SHINGLE]      = M.Brick
	BLOCK_MATERIAL[B.ROOF_TILE]    = M.Brick
	BLOCK_MATERIAL[B.CARPET]       = M.Fabric
	BLOCK_MATERIAL[B.SAIL_BLK]     = M.Fabric
	BLOCK_MATERIAL[B.SHIP_TIMBER]  = M.Wood
	BLOCK_MATERIAL[B.BARNACLE_WOOD]= M.Wood
	BLOCK_MATERIAL[B.PIRATE_PLNK]  = M.WoodPlanks
	BLOCK_MATERIAL[B.BOARDWALK]    = M.WoodPlanks
	BLOCK_MATERIAL[B.TRAIL_STONE]  = M.Rock
	BLOCK_MATERIAL[B.RAIL_BED]     = M.Rock
	BLOCK_MATERIAL[B.FURN]         = M.Rock
	BLOCK_MATERIAL[B.CHST]         = M.WoodPlanks
	-- Emissive
	BLOCK_MATERIAL[B.LAVA]         = M.Neon
	BLOCK_MATERIAL[B.NEON_BLK]     = M.Neon
	BLOCK_MATERIAL[B.NEON_TRIM]    = M.Neon
	BLOCK_MATERIAL[B.GLOW_CRYSTAL] = M.Neon
	BLOCK_MATERIAL[B.SEA_LANTERN]  = M.Neon
	BLOCK_MATERIAL[B.SIGNAL_STONE] = M.Neon
	-- Stairs
	BLOCK_MATERIAL[B.STAIR_COB]    = M.Cobblestone
	BLOCK_MATERIAL[B.STAIR_BRK]    = M.Brick
	BLOCK_MATERIAL[B.STAIR_SBK]    = M.Cobblestone
	BLOCK_MATERIAL[B.STAIR_STONE]  = M.Rock
	BLOCK_MATERIAL[B.STAIR_MARBLE] = M.SmoothPlastic
	BLOCK_MATERIAL[B.STAIR_PLNK]   = M.WoodPlanks
end

-- ─── Network setup ────────────────────────────────────────────────────────────
local getChunkRF = ReplicatedStorage:WaitForChild("GetChunkData", 30)
if not getChunkRF then
	warn("VoxelRenderer: GetChunkData RemoteFunction not found — server not ready?")
	return
end
local blockSetRE = ReplicatedStorage:WaitForChild("BlockSet", 30)

-- ─── State ────────────────────────────────────────────────────────────────────
local clientChunks  = {}   -- [key] = {cx, cz, blk={}, model, dirty, minY, maxY}
local loadingChunks = {}   -- [key] = true while request in flight
local renderDist    = math.min(C.RD or 5, 5)  -- cap at 5 for performance

local chunkFolder = Instance.new("Folder")
chunkFolder.Name   = "VCCraftChunks"
chunkFolder.Parent = Workspace

-- ─── Part pool ────────────────────────────────────────────────────────────────
local pool = {}
local function getPart()
	local p
	if #pool > 0 then
		p = table.remove(pool)
		-- Reset pooled part to defaults
		p.Transparency = 0
		p.CanCollide   = true
		p.CastShadow   = false
		p.Material     = Enum.Material.SmoothPlastic
		p.Anchored     = true
	else
		p = Instance.new("Part")
		p.TopSurface    = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow    = false
		p.Anchored      = true
		p.Locked        = true
	end
	return p
end
local function freePart(p)
	-- Remove any child lights before pooling
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	p.Parent = nil
	pool[#pool+1] = p
end

-- ─── Block access ─────────────────────────────────────────────────────────────
local function getCC(cx, cz, lx, y, lz)
	if y < 0 or y >= CH then return B.AIR end
	local ch = clientChunks[WorldUtils.chunkKey(cx, cz)]
	if not ch then return B.AIR end
	return ch.blk[y*CS*CS + lz*CS + lx] or B.AIR
end

local function getWorld(wx, wy, wz)
	if wy < 0 or wy >= CH then return B.AIR end
	local cx = floor(wx/CS); local cz = floor(wz/CS)
	local lx = wx%CS; if lx<0 then lx=lx+CS end
	local lz = wz%CS; if lz<0 then lz=lz+CS end
	return getCC(cx, cz, lx, wy, lz)
end
_G.VCGetBlock = getWorld

-- Immediate local block update for instant feedback
_G.VCSetClientBlock = function(wx, wy, wz, bv)
	if wy < 0 or wy >= CH then return end
	local cx = floor(wx/CS); local cz = floor(wz/CS)
	local lx = wx%CS; if lx<0 then lx=lx+CS end
	local lz = wz%CS; if lz<0 then lz=lz+CS end
	local key = WorldUtils.chunkKey(cx, cz)
	local ch  = clientChunks[key]
	if not ch then return end
	local idx = wy*CS*CS + lz*CS + lx
	if bv == B.AIR then ch.blk[idx] = nil else ch.blk[idx] = bv end
	ch.dirty = true
	-- Update Y bounds
	if bv ~= B.AIR then
		if wy < ch.minY then ch.minY = wy end
		if wy > ch.maxY then ch.maxY = wy end
	end
	-- Dirty neighbors if on border
	if lx==0    then local nk=WorldUtils.chunkKey(cx-1,cz);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
	if lx==CS-1 then local nk=WorldUtils.chunkKey(cx+1,cz);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
	if lz==0    then local nk=WorldUtils.chunkKey(cx,cz-1);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
	if lz==CS-1 then local nk=WorldUtils.chunkKey(cx,cz+1);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
end

-- ─── Neighbour lookup (handles cross-chunk borders) ───────────────────────────
local function getNeighbor(chunk, cx, cz, lx, y, lz)
	if      lx < 0   then return getCC(cx-1, cz,   lx+CS, y, lz)
	elseif  lx >= CS then return getCC(cx+1, cz,   lx-CS, y, lz)
	elseif  lz < 0   then return getCC(cx,   cz-1, lx, y, lz+CS)
	elseif  lz >= CS then return getCC(cx,   cz+1, lx, y, lz-CS)
	else return chunk.blk[y*CS*CS + lz*CS + lx] or B.AIR end
end

-- A block is "visually transparent" — any solid block next to it must show a face
local function isTransparent(bv)
	if bv == B.AIR then return true end
	local bd = BD[bv]
	return bd and (bd.transparent or bd.liquid) or false
end

-- ─── Greedy meshing ───────────────────────────────────────────────────────────
-- 2-D greedy merge per Y layer: collapses runs of the same block ID into
-- a single merged Part.  Liquid blocks are surface-only (huge perf win).

local DIRS6 = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}

local function buildChunkMesh(chunk)
	-- Destroy old model
	if chunk.model then
		for _, p in ipairs(chunk.model:GetChildren()) do
			if p:IsA("BasePart") then freePart(p) end
		end
		chunk.model:Destroy()
		chunk.model = nil
	end

	local model = Instance.new("Model")
	model.Name  = "Chunk_"..chunk.cx.."_"..chunk.cz
	chunk.model = model

	local cx = chunk.cx
	local cz = chunk.cz
	local ox = cx * CS * BS
	local oz = cz * CS * BS

	-- Compute tight Y range from sparse data to skip empty layers
	local minY = chunk.minY or 0
	local maxY = chunk.maxY or (CH - 1)
	-- Expand 1 above/below so face checks at extremes work
	if minY > 0 then minY = minY - 1 end
	if maxY < CH-1 then maxY = maxY + 1 end

	local grid    = {}   -- re-used each Y layer
	local visited = {}
	for lz2 = 0, CS-1 do
		grid[lz2]    = {}
		visited[lz2] = {}
	end

	for y = minY, maxY do
		-- Clear grid and visited for this layer
		for lz2 = 0, CS-1 do
			for lx2 = 0, CS-1 do
				grid[lz2][lx2]    = nil
				visited[lz2][lx2] = nil
			end
		end

		-- Build 2-D slice
		for lz2 = 0, CS-1 do
			for lx2 = 0, CS-1 do
				local bv = chunk.blk[y*CS*CS + lz2*CS + lx2]
				if bv and bv ~= B.AIR then
					local bd2 = BD[bv]
					if bd2 then
						local exposed = false
						if bd2.liquid then
							-- CRITICAL OPTIMISATION: liquids only render where they touch AIR.
							-- This reduces ocean chunks from ~31 000 parts to ~256.
							for _, d in ipairs(DIRS6) do
								local nb = getNeighbor(chunk, cx, cz, lx2+d[1], y+d[2], lz2+d[3])
								if nb == B.AIR then exposed = true; break end
							end
						else
							-- Solid/transparent: show face if any neighbour is see-through
							for _, d in ipairs(DIRS6) do
								local nb = getNeighbor(chunk, cx, cz, lx2+d[1], y+d[2], lz2+d[3])
								if isTransparent(nb) then exposed = true; break end
							end
						end
						if exposed then grid[lz2][lx2] = bv end
					end
				end
			end
		end

		-- Greedy merge: X first, then Z
		for lz2 = 0, CS-1 do
			for lx2 = 0, CS-1 do
				local bv = grid[lz2][lx2]
				if bv and not visited[lz2][lx2] then
					local bd2   = BD[bv]
					local colors = BC[bv]
					local color  = colors and colors[2] or Color3.fromRGB(128, 128, 128)

					-- Expand in X
					local w = 1
					while lx2+w < CS and grid[lz2][lx2+w] == bv and not visited[lz2][lx2+w] do
						w = w + 1
					end

					-- Expand in Z
					local dz = 1
					while lz2+dz < CS do
						local ok = true
						for dx = 0, w-1 do
							if grid[lz2+dz][lx2+dx] ~= bv or visited[lz2+dz][lx2+dx] then
								ok = false; break
							end
						end
						if not ok then break end
						dz = dz + 1
					end

					-- Mark visited
					for dz2 = 0, dz-1 do
						for dx = 0, w-1 do
							visited[lz2+dz2][lx2+dx] = true
						end
					end

					-- Create merged Part
					local p = getPart()
					p.Color = color
					p.Material = BLOCK_MATERIAL[bv] or Enum.Material.SmoothPlastic

					if bd2.liquid then
						-- Liquids: slightly shorter, semi-transparent, no collide
						p.Size         = Vector3.new(w*BS, BS*0.88, dz*BS)
						p.CFrame       = CFrame.new(ox+(lx2+w*0.5)*BS, y*BS+BS*0.44, oz+(lz2+dz*0.5)*BS)
						p.Transparency = (bv == B.WATER) and 0.45 or 0.2
						p.CanCollide   = false
						p.CastShadow   = false
					elseif bd2.transparent then
						p.Size         = Vector3.new(w*BS, BS, dz*BS)
						p.CFrame       = CFrame.new(ox+(lx2+w*0.5)*BS, y*BS+BS*0.5, oz+(lz2+dz*0.5)*BS)
						p.Transparency = 0.3
						p.CanCollide   = false
						p.CastShadow   = false
					else
						p.Size     = Vector3.new(w*BS, BS, dz*BS)
						p.CFrame   = CFrame.new(ox+(lx2+w*0.5)*BS, y*BS+BS*0.5, oz+(lz2+dz*0.5)*BS)
						p.CanCollide  = bd2.solid ~= false
						p.CastShadow = y > (chunk.minY or 0) + 2  -- skip shadow on deepest blocks
					end

					-- Emissive point lights (single blocks only)
					if w == 1 and dz == 1 then
						local emit = (bv == B.LAVA) and {Color3.fromRGB(255,140,0), 1.5, 14}
							or (bv == B.NEON_BLK) and {Color3.fromRGB(120,200,255), 1.0, 10}
							or (bv == B.NEON_TRIM) and {Color3.fromRGB(100,180,255), 0.6, 8}
							or (bv == B.GLOW_CRYSTAL) and {Color3.fromRGB(120,255,200), 0.8, 10}
							or (bv == B.SEA_LANTERN) and {Color3.fromRGB(180,240,255), 0.8, 12}
							or (bv == B.SIGNAL_STONE) and {Color3.fromRGB(180,100,255), 0.6, 8}
							or (bv == B.GLOW_FLOWER) and {Color3.fromRGB(200,255,150), 0.4, 6}
							or nil
						if emit then
							local lt = Instance.new("PointLight")
							lt.Color      = emit[1]
							lt.Brightness = emit[2]
							lt.Range      = emit[3]
							lt.Parent     = p
						end
					end

					p.Parent = model
				end
			end
		end
	end

	model.Parent = chunkFolder
	chunk.dirty  = false
end

-- ─── Y-bounds computation ─────────────────────────────────────────────────────
-- Scan the sparse blk table once to find the min/max occupied Y levels.
-- Used to skip empty layers in meshing (huge speedup for surface-only chunks).
local function computeYBounds(blk)
	local minY2, maxY2 = CH, 0
	for idx, _ in pairs(blk) do
		local y = floor(idx / (CS*CS))
		if y < minY2 then minY2 = y end
		if y > maxY2 then maxY2 = y end
	end
	return minY2, maxY2
end

-- ─── Async chunk loader ───────────────────────────────────────────────────────
local MAX_LOADS   = 16
local activeLoads = 0

local function loadChunkAsync(cx, cz)
	local key = WorldUtils.chunkKey(cx, cz)
	if clientChunks[key] or loadingChunks[key] then return end
	if activeLoads >= MAX_LOADS then return end
	loadingChunks[key] = true
	activeLoads        = activeLoads + 1

	task.spawn(function()
		local ok, data = pcall(function()
			return getChunkRF:InvokeServer(cx, cz)
		end)
		activeLoads        = activeLoads - 1
		loadingChunks[key] = nil

		if ok and data then
			if clientChunks[key] then return end  -- loaded by another path meanwhile
			local minY2, maxY2 = computeYBounds(data)
			clientChunks[key] = {
				cx   = cx, cz  = cz,
				blk  = data,
				model = nil,
				dirty = true,
				minY  = minY2,
				maxY  = maxY2,
			}
			-- Dirty neighbours so border faces update correctly
			local offsets = {{-1,0},{1,0},{0,-1},{0,1}}
			for _, off in ipairs(offsets) do
				local nk = WorldUtils.chunkKey(cx+off[1], cz+off[2])
				if clientChunks[nk] then clientChunks[nk].dirty = true end
			end
		else
			if not ok then
				warn("VoxelRenderer: chunk load failed ("..cx..","..cz.."): "..tostring(data))
			end
		end
	end)
end

-- ─── Chunk unload ─────────────────────────────────────────────────────────────
local function unloadChunk(key)
	local ch = clientChunks[key]
	if not ch then return end
	if ch.model then
		for _, p in ipairs(ch.model:GetChildren()) do
			if p:IsA("BasePart") then freePart(p) end
		end
		ch.model:Destroy()
	end
	clientChunks[key] = nil
end

-- ─── Main render loop ─────────────────────────────────────────────────────────
local BUILDS_PER_FRAME = 6

RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not _G.VCGameRunning then return end  -- don't load before game starts

	local px = floor(hrp.Position.X / (CS*BS))
	local pz = floor(hrp.Position.Z / (CS*BS))
	local rd = renderDist

	-- Queue chunk loads within circular render distance
	for dcx = -rd, rd do
		for dcz = -rd, rd do
			if dcx*dcx + dcz*dcz <= rd*rd then
				local cx2 = px+dcx; local cz2 = pz+dcz
				local key = WorldUtils.chunkKey(cx2, cz2)
				if not clientChunks[key] and not loadingChunks[key] then
					loadChunkAsync(cx2, cz2)
				end
			end
		end
	end

	-- Build dirty chunks (budget-limited per frame)
	local built = 0
	for _, ch in pairs(clientChunks) do
		if ch.dirty and built < BUILDS_PER_FRAME then
			local ok, err = pcall(buildChunkMesh, ch)
			if not ok then
				warn("VoxelRenderer: mesh error: "..tostring(err))
				ch.dirty = false  -- prevent infinite retry of broken chunk
			end
			built = built + 1
		end
	end

	-- Unload far chunks (beyond rd+2)
	local limitSq = (rd+2)^2
	for key, ch in pairs(clientChunks) do
		local dx = ch.cx - px; local dz = ch.cz - pz
		if dx*dx + dz*dz > limitSq then
			unloadChunk(key)
		end
	end
end)

-- ─── Spawn readiness ──────────────────────────────────────────────────────────
-- Called by MainMenu to determine when to let the player in

_G.VCSpawnReady = function()
	for dcx = -1, 1 do
		for dcz = -1, 1 do
			local key = WorldUtils.chunkKey(dcx, dcz)
			local ch  = clientChunks[key]
			if not ch or ch.dirty then return false end
		end
	end
	return true
end

_G.VCSpawnProgress = function()
	local loaded = 0
	for dcx = -1, 1 do
		for dcz = -1, 1 do
			local key = WorldUtils.chunkKey(dcx, dcz)
			if clientChunks[key] and not clientChunks[key].dirty then
				loaded = loaded + 1
			end
		end
	end
	return loaded / 9
end

-- ─── Block set from server (other players / world events) ─────────────────────
if blockSetRE then
	blockSetRE.OnClientEvent:Connect(function(wx, wy, wz, bv)
		local cx = floor(wx/CS); local cz = floor(wz/CS)
		local lx = wx%CS; if lx<0 then lx=lx+CS end
		local lz = wz%CS; if lz<0 then lz=lz+CS end
		local key   = WorldUtils.chunkKey(cx, cz)
		local ch    = clientChunks[key]
		if not ch then return end
		local idx = wy*CS*CS + lz*CS + lx
		if bv == B.AIR then ch.blk[idx] = nil else ch.blk[idx] = bv end
		ch.dirty = true
		if bv ~= B.AIR then
			if wy < ch.minY then ch.minY = wy end
			if wy > ch.maxY then ch.maxY = wy end
		end
		-- Border dirty propagation
		if lx==0    then local nk=WorldUtils.chunkKey(cx-1,cz);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
		if lx==CS-1 then local nk=WorldUtils.chunkKey(cx+1,cz);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
		if lz==0    then local nk=WorldUtils.chunkKey(cx,cz-1);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
		if lz==CS-1 then local nk=WorldUtils.chunkKey(cx,cz+1);   if clientChunks[nk] then clientChunks[nk].dirty=true end end
	end)
end

_G.VCSetRenderDist = function(v) renderDist = math.clamp(v, 2, 7) end

print("VC CRAFT VoxelRenderer initialised (liquid-surface-only optimisation active)")
