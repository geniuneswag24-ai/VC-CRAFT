-- VC CRAFT Player Controller Client
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local BT = require(Shared.BlockTypes)
local WorldUtils = require(Shared.WorldUtils)
local Recipes = require(Shared.Recipes)

local B = BT.B
local BD = BT.BD
local CS = C.CS
local CH = C.CH
local BS = C.BLOCK_SIZE
local WL = C.WL
local floor = math.floor
local abs = math.abs
local pi = math.pi

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local RE = {}
for _, name in pairs(WorldUtils.RE) do
	RE[name] = ReplicatedStorage:WaitForChild(name, 10)
end

-- ─── Player state ─────────────────────────────────────────────────────────────
local ps = {
	-- Inventory
	hotbar = {}, -- 9 slots: {id, count} or nil
	inventory = {}, -- 27 slots
	sel = 1, -- selected hotbar slot (1-9)
	mode = "survival", -- "survival" or "creative"
	flying = false,

	-- Stats
	hp = C.PLAYER_HP,
	hunger = C.PLAYER_HUNGER,
	hurtTimer = 0,

	-- Physics state (mirrors Roblox character but used for voxel interaction)
	inWater = false,
	headInWater = false,
	onLadder = false,
	fallDist = 0,
	lastAirY = 0,
	grounded = false,

	-- Mining
	breakBlock = nil,  -- {wx, wy, wz} target
	breakProgress = 0, -- 0-1
	breakTimer = 0,

	-- Train mounting
	trainMount = nil,

	-- Interaction cooldown
	rightClickTimer = 0,

	-- Sprint
	sprinting = false,
	sprintTapTimer = 0,
	lastWTap = 0,
}
_G.PlayerState = ps

-- ─── Inventory helpers ────────────────────────────────────────────────────────
local function getSlot(idx)
	if idx <= 9 then return ps.hotbar[idx]
	else return ps.inventory[idx - 9] end
end

local function setSlot(idx, item)
	if idx <= 9 then ps.hotbar[idx] = item
	else ps.inventory[idx - 9] = item end
end

local function addItem(id, count)
	local bd = BD[id]
	local maxStack = (bd and bd.stackSize) or 64
	-- Try to stack on existing hotbar
	for i = 1, 9 do
		local sl = ps.hotbar[i]
		if sl and sl.id == id and sl.count < maxStack then
			local canAdd = math.min(count, maxStack - sl.count)
			sl.count = sl.count + canAdd
			count = count - canAdd
			if count <= 0 then return end
		end
	end
	-- Try to stack on existing inventory
	for i = 1, 27 do
		local sl = ps.inventory[i]
		if sl and sl.id == id and sl.count < maxStack then
			local canAdd = math.min(count, maxStack - sl.count)
			sl.count = sl.count + canAdd
			count = count - canAdd
			if count <= 0 then return end
		end
	end
	-- Find empty hotbar slot
	for i = 1, 9 do
		if not ps.hotbar[i] then
			ps.hotbar[i] = {id=id, count=math.min(count, maxStack)}
			count = count - math.min(count, maxStack)
			if count <= 0 then return end
		end
	end
	-- Find empty inventory slot
	for i = 1, 27 do
		if not ps.inventory[i] then
			ps.inventory[i] = {id=id, count=math.min(count, maxStack)}
			count = count - math.min(count, maxStack)
			if count <= 0 then return end
		end
	end
	-- Inventory full - drop on ground
	if count > 0 then
		-- Item lost for now
	end
end
_G.VCAddItem = addItem

-- ─── World interaction ────────────────────────────────────────────────────────
local function getWorldBlock(wx, wy, wz)
	if _G.VCGetBlock then return _G.VCGetBlock(wx, wy, wz) end
	return B.AIR
end

local function setWorldBlock(wx, wy, wz, bv)
	if _G.VCSetClientBlock then _G.VCSetClientBlock(wx, wy, wz, bv) end
	RE[WorldUtils.RE.BLOCK_SET]:FireServer(wx, wy, wz, bv)
end

-- ─── Raycast for block targeting ──────────────────────────────────────────────
local function raycastBlocks(origin, direction, maxDist)
	-- DDA raycast through voxel grid
	local ox = origin.X / BS; local oy = origin.Y / BS; local oz = origin.Z / BS
	local dx = direction.X; local dy = direction.Y; local dz = direction.Z
	local mag = math.sqrt(dx*dx + dy*dy + dz*dz)
	if mag < 0.001 then return nil end
	dx = dx/mag; dy = dy/mag; dz = dz/mag

	local stepX = dx > 0 and 1 or -1
	local stepY = dy > 0 and 1 or -1
	local stepZ = dz > 0 and 1 or -1

	local ix = floor(ox); local iy = floor(oy); local iz = floor(oz)
	local tMaxX = dx ~= 0 and (dx > 0 and (ix+1-ox) or (ox-ix)) / abs(dx) or math.huge
	local tMaxY = dy ~= 0 and (dy > 0 and (iy+1-oy) or (oy-iy)) / abs(dy) or math.huge
	local tMaxZ = dz ~= 0 and (dz > 0 and (iz+1-oz) or (oz-iz)) / abs(dz) or math.huge
	local tDeltaX = dx ~= 0 and 1/abs(dx) or math.huge
	local tDeltaY = dy ~= 0 and 1/abs(dy) or math.huge
	local tDeltaZ = dz ~= 0 and 1/abs(dz) or math.huge

	local prevX, prevY, prevZ = ix, iy, iz
	local dist = 0

	while dist < maxDist / BS do
		local bv = getWorldBlock(ix, iy, iz)
		if bv ~= B.AIR then
			local bd = BD[bv]
			if bd and bd.solid and not bd.liquid then
				return {
					wx=ix, wy=iy, wz=iz,
					prevX=prevX, prevY=prevY, prevZ=prevZ,
					blockId=bv,
					dist=dist*BS,
				}
			end
		end
		prevX=ix; prevY=iy; prevZ=iz
		if tMaxX < tMaxY and tMaxX < tMaxZ then
			ix = ix + stepX; dist = tMaxX; tMaxX = tMaxX + tDeltaX
		elseif tMaxY < tMaxZ then
			iy = iy + stepY; dist = tMaxY; tMaxY = tMaxY + tDeltaY
		else
			iz = iz + stepZ; dist = tMaxZ; tMaxZ = tMaxZ + tDeltaZ
		end
	end
	return nil
end

-- ─── Block break / place ──────────────────────────────────────────────────────
local function startBreak(wx, wy, wz)
	if ps.mode == "creative" then
		-- Instant break
		local bv = getWorldBlock(wx, wy, wz)
		if bv == B.AIR then return end
		local bd = BD[bv]
		if bd and bd.hardness < 0 then return end -- bedrock
		setWorldBlock(wx, wy, wz, B.AIR)
		-- Drop item
		local dropId = (bd and bd.dropId) or bv
		if dropId ~= B.AIR then addItem(dropId, 1) end
		return
	end

	local bv = getWorldBlock(wx, wy, wz)
	if bv == B.AIR then return end
	local bd = BD[bv]
	if bd and bd.hardness < 0 then return end

	if ps.breakBlock and ps.breakBlock.wx == wx and ps.breakBlock.wy == wy and ps.breakBlock.wz == wz then
		return -- already breaking
	end
	ps.breakBlock = {wx=wx, wy=wy, wz=wz}
	ps.breakProgress = 0
	ps.breakTimer = 0
end

local function continueBreak(dt, wx, wy, wz)
	if not ps.breakBlock then return end
	if ps.breakBlock.wx ~= wx or ps.breakBlock.wy ~= wy or ps.breakBlock.wz ~= wz then
		ps.breakBlock = {wx=wx, wy=wy, wz=wz}
		ps.breakProgress = 0
	end
	local bv = getWorldBlock(wx, wy, wz)
	local bd = BD[bv]
	if not bd or bd.hardness < 0 then ps.breakBlock = nil; return end

	local hd = bd.hardness
	ps.breakProgress = ps.breakProgress + dt / hd
	ps.breakTimer = ps.breakTimer + dt

	if ps.breakProgress >= 1 then
		-- Block broken
		setWorldBlock(wx, wy, wz, B.AIR)
		local dropId = bd.dropId or bv
		if dropId ~= B.AIR and ps.mode == "survival" then
			addItem(dropId, 1)
		end
		ps.breakBlock = nil
		ps.breakProgress = 0
		ps.breakTimer = 0
	end
end

local function placeBlock(wx, wy, wz)
	local slot = ps.hotbar[ps.sel]
	if not slot or slot.count <= 0 then return end
	local id = slot.id
	local bd = BD[id]
	if not bd or not bd.solid then
		-- Handle buckets
		if id == B.WATER_BUCKET then
			setWorldBlock(wx, wy, wz, B.WATER)
			slot.count = slot.count - 1
			if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
			return
		elseif id == B.LAVA_BUCKET then
			setWorldBlock(wx, wy, wz, B.LAVA)
			slot.count = slot.count - 1
			if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
			return
		end
		return
	end

	-- Check not inside player
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local blockCenter = Vector3.new((wx + 0.5)*BS, (wy + 0.5)*BS, (wz + 0.5)*BS)
			local playerPos = hrp.Position
			if abs(blockCenter.X - playerPos.X) < BS*1.2 and
				abs(blockCenter.Y - playerPos.Y) < BS*2 and
				abs(blockCenter.Z - playerPos.Z) < BS*1.2 then
				return -- would intersect player
			end
		end
	end

	-- Handle door placement
	if id == B.DOOR_OAK_C or id == B.DOOR_IRON_C or id == B.DOOR_DARK_C then
		setWorldBlock(wx, wy, wz, id)
		setWorldBlock(wx, wy+1, wz, id) -- doors are 2 tall
	else
		setWorldBlock(wx, wy, wz, id)
	end

	slot.count = slot.count - 1
	if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
end

-- ─── Mouse input handling ─────────────────────────────────────────────────────
local isBreaking = false
local breakTarget = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if _G.VCInventoryOpen then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isBreaking = true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		-- Try eating first if holding food
		local slot = ps.hotbar[ps.sel]
		if slot and BD[slot.id] and BD[slot.id].hunger and BD[slot.id].hunger > 0 then
			tryEat()
			return
		end
		-- Place / interact
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local camLook = camera.CFrame.LookVector
		local rayOrigin = Vector3.new(
			hrp.Position.X / BS,
			hrp.Position.Y / BS + 1,
			hrp.Position.Z / BS
		)
		local hit = raycastBlocks(rayOrigin * BS, camLook, C.PLAYER_REACH)
		if hit then
			local bv = hit.blockId
			local bt2 = BD[bv]
			-- Interaction
			if bv == B.CHST then
				RE[WorldUtils.RE.INTERACT]:FireServer(hit.wx, hit.wy, hit.wz, "open_chest")
				return
			end
			-- Furnace: smelt held item (right-click with ore/smeltable in hand)
			if bv == B.FURN then
				local slot = ps.hotbar[ps.sel]
				if slot and slot.count > 0 then
					local result = Recipes.checkSmelt(slot.id)
					if result then
						slot.count = slot.count - 1
						if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
						addItem(result.id, result.count)
						if _G.VCUpdateHUD then _G.VCUpdateHUD() end
					end
				end
				return
			end
			if BT.DOOR_TOGGLE[bv] then
				RE[WorldUtils.RE.INTERACT]:FireServer(hit.wx, hit.wy, hit.wz, "toggle_door")
				return
			end
			if bv == B.NEON_BLK then
				-- Check for dungeon activation
				local slot = ps.hotbar[ps.sel]
				if slot and slot.id == B.DUNGEON_KEY and slot.count >= 3 then
					RE[WorldUtils.RE.INTERACT]:FireServer(hit.wx, hit.wy, hit.wz, "boss_activate")
					slot.count = slot.count - 3
					if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
					return
				end
			end
			-- Place block
			placeBlock(hit.prevX, hit.prevY, hit.prevZ)
		end
	end

	-- Hotbar number keys
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local kc = input.KeyCode
		if kc == Enum.KeyCode.One then ps.sel = 1
		elseif kc == Enum.KeyCode.Two then ps.sel = 2
		elseif kc == Enum.KeyCode.Three then ps.sel = 3
		elseif kc == Enum.KeyCode.Four then ps.sel = 4
		elseif kc == Enum.KeyCode.Five then ps.sel = 5
		elseif kc == Enum.KeyCode.Six then ps.sel = 6
		elseif kc == Enum.KeyCode.Seven then ps.sel = 7
		elseif kc == Enum.KeyCode.Eight then ps.sel = 8
		elseif kc == Enum.KeyCode.Nine then ps.sel = 9
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isBreaking = false
		ps.breakBlock = nil
		ps.breakProgress = 0
	end
end)

-- Mouse wheel for hotbar
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local delta = input.Position.Z > 0 and -1 or 1
		ps.sel = ((ps.sel - 1 + delta) % 9) + 1
	end
end)

-- ─── Mob attack (left-click) ──────────────────────────────────────────────────
local attackCooldown = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if _G.VCInventoryOpen then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if attackCooldown > 0 then return end
		if not _G.VCMobs then return end

		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local ppos = hrp.Position
		local camLook = camera.CFrame.LookVector

		-- Find mobs in range
		for id, mob in pairs(_G.VCMobs) do
			if mob.model then
				local mpos = mob.model:GetPivot().Position
				local dir = (mpos - ppos)
				local dist = dir.Magnitude
				if dist < C.PLAYER_ATTACK_RANGE * BS then
					-- Check aim
					local dot = camLook:Dot(dir.Unit)
					if dot > 0.4 then
						-- Attack!
						local damage = ps.mode == "creative" and 100 or 4
						-- Check if holding sword
						local slot = ps.hotbar[ps.sel]
						if slot and slot.id == B.WSWD then damage = 6 end

						local knockback = dir.Unit * BS
						RE[WorldUtils.RE.MOB_DAMAGE]:FireServer(id, damage, knockback)
						attackCooldown = 0.4
						-- Swing animation
						if _G.VCSwingArm then _G.VCSwingArm() end
						break
					end
				end
			end
		end
	end
end)

-- ─── Player damage handler ────────────────────────────────────────────────────
RE[WorldUtils.RE.PLAYER_DAMAGE].OnClientEvent:Connect(function(damage, sourcePos, damageType)
	if ps.mode == "creative" then return end
	if ps.hurtTimer > 0 then return end
	ps.hp = ps.hp - damage
	ps.hurtTimer = 0.5
	if ps.hp <= 0 then
		ps.hp = 0
		if _G.VCShowDeath then _G.VCShowDeath() end
	else
		if _G.VCShowHurt then _G.VCShowHurt() end
	end
	-- Update HUD
	if _G.VCUpdateHUD then _G.VCUpdateHUD() end
end)

-- ─── Item pickup ─────────────────────────────────────────────────────────────
RE[WorldUtils.RE.ITEM_DROP].OnClientEvent:Connect(function(posData, itemId, count)
	-- Client-side item drop visual handled in HUD script
	if _G.VCSpawnItemDrop then
		_G.VCSpawnItemDrop(Vector3.new(posData.x, posData.y, posData.z), itemId, count)
	end
end)

-- ─── Fall damage tracking ─────────────────────────────────────────────────────
local lastPosY     = nil   -- previous frame Y (studs)
local fallDist     = 0     -- accumulated fall distance in blocks
local wasAirborne  = false

-- ─── Hunger timer ─────────────────────────────────────────────────────────────
local hungerTimer  = 0
local HUNGER_RATE  = 30  -- seconds to lose 1 hunger point

-- ─── Eating ───────────────────────────────────────────────────────────────────
local function tryEat()
	if ps.mode == "creative" then return end
	local slot = ps.hotbar[ps.sel]
	if not slot then return end
	local bd = BD[slot.id]
	if not bd or not bd.hunger or bd.hunger <= 0 then return end
	if ps.hunger >= C.PLAYER_HUNGER then return end  -- full
	ps.hunger = math.min(C.PLAYER_HUNGER, ps.hunger + bd.hunger)
	slot.count = slot.count - 1
	if slot.count <= 0 then ps.hotbar[ps.sel] = nil end
	if _G.VCUpdateHUD then _G.VCUpdateHUD() end
end

-- ─── Heartbeat (physics integration with Roblox character) ───────────────────
local lastHurt = 0

RunService.Heartbeat:Connect(function(dt)
	attackCooldown = math.max(0, attackCooldown - dt)
	if ps.hurtTimer > 0 then ps.hurtTimer = ps.hurtTimer - dt end
	if ps.rightClickTimer > 0 then ps.rightClickTimer = ps.rightClickTimer - dt end

	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local ppos = hrp.Position
	local wx = floor(ppos.X / BS)
	local wy = floor(ppos.Y / BS)
	local wz = floor(ppos.Z / BS)

	-- Water detection
	local headBlock = getWorldBlock(wx, wy + 1, wz)
	local feetBlock = getWorldBlock(wx, wy, wz)
	ps.headInWater = BD[headBlock] and BD[headBlock].liquid or false
	ps.inWater = BD[feetBlock] and BD[feetBlock].liquid or false

	-- Lava damage
	if feetBlock == B.LAVA and ps.mode == "survival" then
		lastHurt = lastHurt + dt
		if lastHurt >= 0.5 then
			lastHurt = 0
			ps.hp = ps.hp - 4
			if ps.hp <= 0 then
				if _G.VCShowDeath then _G.VCShowDeath() end
			end
			if _G.VCUpdateHUD then _G.VCUpdateHUD() end
		end
	else
		lastHurt = 0
	end

	-- Void damage
	if ppos.Y < -80 * BS then
		if ps.mode == "survival" then
			ps.hp = 0
			if _G.VCShowDeath then _G.VCShowDeath() end
		end
		-- Teleport back
		if ppos.Y < -100 * BS then
			hrp.CFrame = CFrame.new(ppos.X, 200 * BS, ppos.Z)
		end
	end

	-- ─── Fall damage ──────────────────────────────────────────────────────────
	if ps.mode == "survival" then
		local hum = char:FindFirstChild("Humanoid")
		local grounded = hum and hum.FloorMaterial ~= Enum.Material.Air
		if lastPosY then
			local dy = (lastPosY - ppos.Y) / BS  -- positive = falling
			if dy > 0 then
				fallDist = fallDist + dy
				wasAirborne = true
			elseif grounded and wasAirborne then
				-- Just landed
				if fallDist > C.FALL_THRESHOLD then
					local dmg = math.floor(fallDist - C.FALL_THRESHOLD)
					if not ps.inWater then
						ps.hp = ps.hp - dmg
						if ps.hp <= 0 then
							ps.hp = 0
							if _G.VCShowDeath then _G.VCShowDeath() end
						elseif _G.VCShowHurt then
							_G.VCShowHurt()
						end
						if _G.VCUpdateHUD then _G.VCUpdateHUD() end
					end
				end
				fallDist = 0
				wasAirborne = false
			elseif grounded then
				fallDist = 0
				wasAirborne = false
			end
		end
		lastPosY = ppos.Y

		-- ─── Hunger drain ─────────────────────────────────────────────────────
		hungerTimer = hungerTimer + dt
		if hungerTimer >= HUNGER_RATE then
			hungerTimer = 0
			if ps.hunger > 0 then
				ps.hunger = ps.hunger - 1
				if _G.VCUpdateHUD then _G.VCUpdateHUD() end
			elseif ps.hunger <= 0 then
				-- Starving: slowly lose health
				ps.hp = math.max(1, ps.hp - 1)
				if _G.VCUpdateHUD then _G.VCUpdateHUD() end
			end
		end
	end

	-- Block breaking
	if isBreaking then
		local camLook = camera.CFrame.LookVector
		local rayOrigin = Vector3.new(ppos.X / BS, ppos.Y / BS + 1.5, ppos.Z / BS)
		local hit = raycastBlocks(rayOrigin * BS, camLook, C.PLAYER_REACH)
		if hit then
			-- Start breaking if not already targeting this block
			if not ps.breakBlock or ps.breakBlock.wx ~= hit.wx or ps.breakBlock.wy ~= hit.wy or ps.breakBlock.wz ~= hit.wz then
				startBreak(hit.wx, hit.wy, hit.wz)
			end
			continueBreak(dt, hit.wx, hit.wy, hit.wz)
			-- Update break overlay
			if _G.VCUpdateBreakOverlay then
				_G.VCUpdateBreakOverlay(hit.wx, hit.wy, hit.wz, ps.breakProgress)
			end
		else
			ps.breakBlock = nil
			ps.breakProgress = 0
		end
	else
		ps.breakBlock = nil
	end

	-- Target block name display
	if not isBreaking then
		local camLook = camera.CFrame.LookVector
		local rayOrigin = Vector3.new(ppos.X / BS, ppos.Y / BS + 1.5, ppos.Z / BS)
		local hit = raycastBlocks(rayOrigin * BS, camLook, C.PLAYER_REACH)
		if hit and _G.VCSetTargetBlock then
			_G.VCSetTargetBlock(hit.blockId)
		elseif _G.VCSetTargetBlock then
			_G.VCSetTargetBlock(nil)
		end
	end

	-- Ladder detection
	local ladderBlock = getWorldBlock(wx, wy, wz)
	ps.onLadder = ladderBlock == B.LADDER

	-- Apply speed modifiers based on environment
	local hum = char:FindFirstChild("Humanoid")
	if hum then
		local baseSpeed = C.PLAYER_SPEED
		if ps.inWater then baseSpeed = baseSpeed * 0.4 end
		if feetBlock == B.LAVA then baseSpeed = baseSpeed * 0.2 end
		if ps.sprinting then baseSpeed = baseSpeed * C.PLAYER_SPRINT_MUL end
		hum.WalkSpeed = baseSpeed * BS / 16 -- normalize to Roblox units
	end
end)

-- ─── First-person camera ──────────────────────────────────────────────────────
-- Only lock camera once game actually starts (not during main menu)
_G.VCActivateCamera = function()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end
if _G.VCGameRunning then
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

-- ─── Creative / Survival mode ─────────────────────────────────────────────────
local creativeBlocks = {
	-- Slot 1-9: most-used building blocks
	B.GRASS, B.STONE, B.PLNK, B.GLASS, B.BRK, B.SAND, B.CONCRETE, B.MARBLE, B.OBSIDIAN,
}

local function fillCreativeHotbar()
	for i = 1, 9 do
		ps.hotbar[i] = {id = creativeBlocks[i], count = 999}
	end
	-- Fill creative inventory with all major block types
	local allBlocks = {
		B.DIRT, B.GRAV, B.CLAY, B.MUD, B.RSAND, B.DEEP, B.MOSS,
		B.COB, B.SSTON, B.SBK, B.BRK, B.BASALT, B.OBSIDIAN,
		B.OLOG, B.BLOG, B.SLOG, B.DLOG, B.JLOG, B.ALOG, B.REDWOOD_LOG,
		B.PLNK, B.CRFT, B.FURN, B.CHST, B.LADDER, B.FENCE_BLK,
		B.GLASS, B.ICE, B.SNOW, B.NEON_BLK, B.SEA_LANTERN, B.GLOW_CRYSTAL,
		B.WATER_BUCKET, B.LAVA_BUCKET,
		-- Food
		B.APPLE, B.BREAD, B.MEAT_COOKED,
	}
	for i, id in ipairs(allBlocks) do
		if i <= 27 then
			ps.inventory[i] = {id = id, count = 999}
		end
	end
end

local function enterCreative()
	ps.mode   = "creative"
	ps.flying = false  -- start grounded, double-Space to fly
	ps.hp     = C.PLAYER_HP
	ps.hunger = C.PLAYER_HUNGER
	fillCreativeHotbar()
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.JumpPower = 60 end
	end
	if _G.VCUpdateHUD then _G.VCUpdateHUD() end
end

local function enterSurvival()
	ps.mode   = "survival"
	ps.flying = false
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
	end
	if _G.VCUpdateHUD then _G.VCUpdateHUD() end
end

_G.VCCreativeMode = enterCreative
_G.VCSurvivalMode = enterSurvival
_G.VCToggleMode   = function()
	if ps.mode == "creative" then enterSurvival() else enterCreative() end
end

-- Set by MainMenu before spawning
if _G.VCCurrentWorld and _G.VCCurrentWorld.gameMode == "creative" then
	enterCreative()
end

-- F4 toggles mode
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.F4 then _G.VCToggleMode() end
end)

-- ─── Creative flying (double-Space toggles, then WASD+Space/Shift) ───────────
local lastSpaceTime = 0
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Space and ps.mode == "creative" then
		local now = tick()
		if now - lastSpaceTime < 0.35 then
			-- Double-tap Space = toggle fly
			ps.flying = not ps.flying
			local char = player.Character
			if char then
				local hum = char:FindFirstChild("Humanoid")
				if hum then
					hum.PlatformStand = ps.flying
					if not ps.flying then hum.PlatformStand = false end
				end
			end
		end
		lastSpaceTime = now
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not ps.flying or ps.mode ~= "creative" then return end
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")
	if not hrp or not hum then return end
	hum.PlatformStand = true
	local cf  = camera.CFrame
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then dir += Vector3.new(0,1,0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)  then dir -= Vector3.new(0,1,0) end
	local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 120 or 48
	local vel = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero
	hrp.AssemblyLinearVelocity = vel
end)

print("VC CRAFT Player Controller initialized")
