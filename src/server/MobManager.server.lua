-- VC CRAFT Mob Manager Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local BT = require(Shared.BlockTypes)
local WorldUtils = require(Shared.WorldUtils)

local B = BT.B
local floor = math.floor
local abs = math.abs

-- Wait for RemoteEvents
local RE = {}
for _, name in pairs(WorldUtils.RE) do
	RE[name] = ReplicatedStorage:WaitForChild(name, 10)
end

-- ─── Mob definitions ──────────────────────────────────────────────────────────
local MOB_TYPES = {
	GARFBOT = "Garfbot",
	GARFBOT_BOSS = "GarfbotBoss",
	COW = "Cow",
	FISH = "Fish",
	VC_KNIGHT = "VCKnight",
}

local MOB_STATS = {
	[MOB_TYPES.GARFBOT] = {
		hp = 20, speed = 3.2, damage = 3,
		attackRange = 1.8, attackCooldown = 1.2,
		detectRange = 18, wanderSpeed = 1.2,
		color = Color3.fromRGB(68, 68, 85), size = Vector3.new(1, 2, 1),
	},
	[MOB_TYPES.GARFBOT_BOSS] = {
		hp = 400, speed = 2.8, damage = 8,
		attackRange = 4, attackCooldown = 2.5,
		detectRange = 30, wanderSpeed = 0,
		color = Color3.fromRGB(80, 40, 20), size = Vector3.new(2, 4, 2),
	},
	[MOB_TYPES.COW] = {
		hp = 10, speed = 0.6, damage = 0,
		attackRange = 0, attackCooldown = 999,
		detectRange = 0, wanderSpeed = 0.6,
		color = Color3.fromRGB(139, 105, 20), size = Vector3.new(1.5, 1.5, 1.5),
	},
	[MOB_TYPES.FISH] = {
		hp = 4, speed = 0.8, damage = 0,
		attackRange = 0, attackCooldown = 999,
		detectRange = 0, wanderSpeed = 0.8,
		color = Color3.fromRGB(68, 136, 204), size = Vector3.new(0.5, 0.5, 1),
	},
	[MOB_TYPES.VC_KNIGHT] = {
		hp = 150, speed = 1.4, damage = 7,
		attackRange = 2.5, attackCooldown = 1.8,
		detectRange = 20, wanderSpeed = 0.4,
		color = Color3.fromRGB(58, 56, 48), size = Vector3.new(1.5, 3.5, 1.5),
	},
}

-- ─── Active mobs ──────────────────────────────────────────────────────────────
local mobs = {}
local mobIdCounter = 0

local function newMobId()
	mobIdCounter = mobIdCounter + 1
	return mobIdCounter
end

local function spawnMob(mobType, position)
	local stats = MOB_STATS[mobType]
	if not stats then return nil end
	local id = newMobId()
	local mob = {
		id = id,
		mobType = mobType,
		pos = position,
		vel = Vector3.new(0, 0, 0),
		hp = stats.hp,
		maxHp = stats.hp,
		yaw = math.random() * math.pi * 2,
		grounded = false,
		hurtTimer = 0,
		deathTimer = -1,
		animTime = 0,
		attackCooldown = 0,
		wanderTimer = math.random(2, 6),
		wanderDir = Vector3.new(math.random()-0.5, 0, math.random()-0.5).Unit,
		phase = 1,          -- for boss
		dmgAccum = 0,       -- for boss stagger
		staggerTimer = 0,   -- boss stagger
		chargingTimer = 0,
		chargeDir = nil,
		wakeTimer = mobType == MOB_TYPES.GARFBOT_BOSS and 3 or 0,
	}
	mobs[id] = mob

	-- Notify clients
	RE[WorldUtils.RE.MOB_UPDATE]:FireAllClients({
		action = "spawn",
		id = id,
		mobType = mobType,
		pos = {x=position.X, y=position.Y, z=position.Z},
		hp = mob.hp,
		maxHp = mob.maxHp,
	})
	return mob
end

local function removeMob(id)
	if mobs[id] then
		mobs[id] = nil
		RE[WorldUtils.RE.MOB_UPDATE]:FireAllClients({action="remove", id=id})
	end
end

-- ─── AI helpers ──────────────────────────────────────────────────────────────
local function getClosestPlayer(pos)
	local closest = nil
	local closestDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d = (hrp.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closest = {player = player, pos = hrp.Position, dist = d}
				end
			end
		end
	end
	return closest
end

local function getWorldBlock(pos)
	local WG = _G.WorldGen
	if not WG then return B.AIR end
	return WG.getBlock(floor(pos.X), floor(pos.Y), floor(pos.Z))
end

local function isSolidAt(pos)
	local bv = getWorldBlock(pos)
	local bd = BT.BD[bv]
	if not bd then return false end
	return bd.solid and not bd.liquid
end

-- Simple gravity/collision for mobs
local function mobPhysics(mob, dt)
	local stats = MOB_STATS[mob.mobType]
	if not stats then return end

	-- Fish: no gravity, swim in water
	if mob.mobType == MOB_TYPES.FISH then
		local bv = getWorldBlock(mob.pos)
		local bd = BT.BD[bv]
		if bd and bd.liquid then
			-- swim
			mob.vel = Vector3.new(mob.vel.X * 0.9, mob.vel.Y * 0.8, mob.vel.Z * 0.9)
		else
			mob.vel = Vector3.new(mob.vel.X, mob.vel.Y - 18*dt, mob.vel.Z)
		end
	else
		-- Apply gravity
		mob.vel = Vector3.new(mob.vel.X, mob.vel.Y - 18*dt, mob.vel.Z)
	end

	-- Move and collide
	local newPos = mob.pos + mob.vel * dt
	-- Y collision
	local floorY = floor(mob.pos.Y)
	if isSolidAt(Vector3.new(mob.pos.X, newPos.Y, mob.pos.Z)) then
		if mob.vel.Y < 0 then
			mob.grounded = true
			newPos = Vector3.new(newPos.X, floorY + 1, newPos.Z)
			mob.vel = Vector3.new(mob.vel.X, 0, mob.vel.Z)
		end
	else
		mob.grounded = false
	end

	-- X/Z collision - simple axis-aligned
	if isSolidAt(Vector3.new(newPos.X, mob.pos.Y + 0.5, mob.pos.Z)) then
		newPos = Vector3.new(mob.pos.X, newPos.Y, newPos.Z)
		mob.vel = Vector3.new(0, mob.grounded and 5.5 or mob.vel.Y, mob.vel.Z)
	end
	if isSolidAt(Vector3.new(newPos.X, mob.pos.Y + 0.5, newPos.Z)) then
		newPos = Vector3.new(newPos.X, newPos.Y, mob.pos.Z)
		mob.vel = Vector3.new(mob.vel.X, mob.grounded and 5.5 or mob.vel.Y, 0)
	end

	-- Water drag
	local bvNew = getWorldBlock(newPos)
	local bdNew = BT.BD[bvNew]
	if bdNew and bdNew.liquid then
		mob.vel = Vector3.new(mob.vel.X * 0.85, mob.vel.Y * 0.85, mob.vel.Z * 0.85)
	end

	mob.pos = newPos
end

-- ─── Mob AI ───────────────────────────────────────────────────────────────────
local function aiGarfbot(mob, dt, playerInfo)
	local stats = MOB_STATS[MOB_TYPES.GARFBOT]
	mob.wanderTimer = mob.wanderTimer - dt
	mob.attackCooldown = mob.attackCooldown - dt

	if playerInfo and playerInfo.dist < stats.detectRange then
		-- Chase player
		local dir = (playerInfo.pos - mob.pos)
		dir = Vector3.new(dir.X, 0, dir.Z)
		local dist = dir.Magnitude
		if dist > 1.8 then
			dir = dir.Unit
			mob.vel = Vector3.new(dir.X * stats.speed, mob.vel.Y, dir.Z * stats.speed)
			mob.yaw = math.atan2(-dir.X, -dir.Z)
		else
			mob.vel = Vector3.new(0, mob.vel.Y, 0)
			-- Attack
			if mob.attackCooldown <= 0 then
				mob.attackCooldown = stats.attackCooldown
				RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, stats.damage, mob.pos)
			end
		end
	else
		-- Wander
		if mob.wanderTimer <= 0 then
			mob.wanderTimer = 2 + math.random() * 4
			mob.wanderDir = Vector3.new(math.random()-0.5, 0, math.random()-0.5)
			if mob.wanderDir.Magnitude > 0 then mob.wanderDir = mob.wanderDir.Unit end
		end
		mob.vel = Vector3.new(mob.wanderDir.X * stats.wanderSpeed, mob.vel.Y, mob.wanderDir.Z * stats.wanderSpeed)
		if mob.vel.Magnitude > 0 then
			mob.yaw = math.atan2(-mob.wanderDir.X, -mob.wanderDir.Z)
		end
	end
end

local function aiGarfbotBoss(mob, dt, playerInfo)
	if mob.wakeTimer > 0 then
		mob.wakeTimer = mob.wakeTimer - dt
		return
	end

	mob.attackCooldown = mob.attackCooldown - dt
	mob.staggerTimer = mob.staggerTimer - dt

	-- Phase update
	local hpRatio = mob.hp / mob.maxHp
	if hpRatio > 0.5 then mob.phase = 1
	elseif hpRatio > 0.25 then mob.phase = 2
	else mob.phase = 3 end

	local atkSpd = mob.phase == 1 and 2.5 or (mob.phase == 2 and 1.8 or 1.2)

	if mob.staggerTimer > 0 then
		mob.vel = Vector3.new(0, mob.vel.Y, 0)
		return
	end

	if not playerInfo then return end
	local stats = MOB_STATS[MOB_TYPES.GARFBOT_BOSS]
	local dir = playerInfo.pos - mob.pos
	local dist = dir.Magnitude
	local hdir = Vector3.new(dir.X, 0, dir.Z)
	local hdist = hdir.Magnitude

	-- Move toward player if not close
	if hdist > 3 then
		local mv = hdir.Unit * stats.speed
		mob.vel = Vector3.new(mv.X, mob.vel.Y, mv.Z)
		mob.yaw = math.atan2(-hdir.X, -hdir.Z)
	else
		mob.vel = Vector3.new(0, mob.vel.Y, 0)
	end

	if mob.attackCooldown <= 0 then
		mob.attackCooldown = atkSpd
		local roll = math.random()

		if roll < 0.18 and hdist < 4 then
			-- Slam
			RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 8, mob.pos)
			RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 0, mob.pos, "knockback_heavy")

		elseif roll < 0.32 and hdist > 5 and hdist < 18 then
			-- Charge
			local chargeSpd = mob.phase == 3 and 16 or 12
			mob.chargeDir = hdir.Unit
			mob.chargingTimer = 1.0
			mob.vel = Vector3.new(mob.chargeDir.X * chargeSpd, mob.vel.Y, mob.chargeDir.Z * chargeSpd)

		elseif roll < 0.46 and hdist < 12 then
			-- Beam attack
			RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 6, mob.pos)

		elseif roll < 0.58 and mob.phase >= 2 then
			-- Summon 1-2 Garfbots
			local count = math.random(1, 2)
			for i = 1, count do
				local angle = math.random() * math.pi * 2
				local spawnPos = mob.pos + Vector3.new(math.cos(angle)*4, 0, math.sin(angle)*4)
				spawnMob(MOB_TYPES.GARFBOT, spawnPos)
			end

		elseif roll < 0.72 and hdist < 5 then
			-- Crush: jump up
			mob.vel = Vector3.new(mob.vel.X, 8, mob.vel.Z)
			RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 10, mob.pos)

		elseif roll < 0.86 then
			-- Sweep
			RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 5, mob.pos, "knockback")
		end
	end

	-- Handle charge
	if mob.chargingTimer > 0 then
		mob.chargingTimer = mob.chargingTimer - dt
		if mob.chargingTimer <= 0 then
			mob.vel = Vector3.new(0, mob.vel.Y, 0)
			mob.chargeDir = nil
			-- Charge damage on contact
			if hdist < 3 then
				RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, 10, mob.pos, "charge")
			end
		end
	end

	-- Stagger accumulation
	if mob.phase >= 2 then
		if math.random() < 0.03 and mob.dmgAccum > 40 then
			mob.staggerTimer = 2.5
			mob.dmgAccum = 0
		end
	end
end

local function aiCow(mob, dt)
	mob.wanderTimer = mob.wanderTimer - dt
	if mob.wanderTimer <= 0 then
		mob.wanderTimer = 3 + math.random() * 5
		if math.random() < 0.3 then
			mob.wanderDir = Vector3.new(0, 0, 0)
		else
			mob.wanderDir = Vector3.new(math.random()-0.5, 0, math.random()-0.5)
			if mob.wanderDir.Magnitude > 0 then mob.wanderDir = mob.wanderDir.Unit end
		end
	end
	local s = MOB_STATS[MOB_TYPES.COW]
	mob.vel = Vector3.new(mob.wanderDir.X * s.wanderSpeed, mob.vel.Y, mob.wanderDir.Z * s.wanderSpeed)
	if mob.wanderDir.Magnitude > 0.1 then
		mob.yaw = math.atan2(-mob.wanderDir.X, -mob.wanderDir.Z)
	end
end

local function aiFish(mob, dt)
	mob.wanderTimer = mob.wanderTimer - dt
	if mob.wanderTimer <= 0 then
		mob.wanderTimer = 2 + math.random() * 2
		local angle = math.random() * math.pi * 2
		mob.wanderDir = Vector3.new(math.cos(angle), (math.random()-0.5)*0.4, math.sin(angle))
	end
	local s = MOB_STATS[MOB_TYPES.FISH]
	mob.vel = mob.wanderDir * s.wanderSpeed
	-- Keep in water
	local bv = getWorldBlock(mob.pos)
	local bd = BT.BD[bv]
	if not (bd and bd.liquid) then
		mob.vel = Vector3.new(mob.vel.X, -1, mob.vel.Z) -- dive back in
	end
end

local function aiVCKnight(mob, dt, playerInfo)
	local stats = MOB_STATS[MOB_TYPES.VC_KNIGHT]
	mob.wanderTimer = mob.wanderTimer - dt
	mob.attackCooldown = mob.attackCooldown - dt

	if playerInfo and playerInfo.dist < stats.detectRange then
		local dir = playerInfo.pos - mob.pos
		local hdir = Vector3.new(dir.X, 0, dir.Z)
		local hdist = hdir.Magnitude
		if hdist > stats.attackRange then
			local mv = hdir.Unit * stats.speed
			mob.vel = Vector3.new(mv.X, mob.vel.Y, mv.Z)
			mob.yaw = math.atan2(-hdir.X, -hdir.Z)
		else
			mob.vel = Vector3.new(0, mob.vel.Y, 0)
			if mob.attackCooldown <= 0 then
				mob.attackCooldown = stats.attackCooldown
				RE[WorldUtils.RE.PLAYER_DAMAGE]:FireClient(playerInfo.player, stats.damage, mob.pos)
			end
		end
	else
		if mob.wanderTimer <= 0 then
			mob.wanderTimer = 5 + math.random() * 8
			mob.wanderDir = Vector3.new(math.random()-0.5, 0, math.random()-0.5)
			if mob.wanderDir.Magnitude > 0 then mob.wanderDir = mob.wanderDir.Unit end
		end
		mob.vel = Vector3.new(mob.wanderDir.X * stats.wanderSpeed, mob.vel.Y, mob.wanderDir.Z * stats.wanderSpeed)
	end
end

-- ─── Mob tick ─────────────────────────────────────────────────────────────────
local function tickMob(mob, dt)
	mob.animTime = mob.animTime + dt
	mob.hurtTimer = mob.hurtTimer - dt

	if mob.deathTimer >= 0 then
		mob.deathTimer = mob.deathTimer + dt
		if mob.deathTimer > 1.5 then
			removeMob(mob.id)
		end
		return
	end

	-- Get closest player
	local playerInfo = getClosestPlayer(mob.pos)

	-- Run AI
	if mob.mobType == MOB_TYPES.GARFBOT then aiGarfbot(mob, dt, playerInfo)
	elseif mob.mobType == MOB_TYPES.GARFBOT_BOSS then aiGarfbotBoss(mob, dt, playerInfo)
	elseif mob.mobType == MOB_TYPES.COW then aiCow(mob, dt)
	elseif mob.mobType == MOB_TYPES.FISH then aiFish(mob, dt)
	elseif mob.mobType == MOB_TYPES.VC_KNIGHT then aiVCKnight(mob, dt, playerInfo)
	end

	-- Physics
	mobPhysics(mob, dt)
end

-- ─── Mob spawning ─────────────────────────────────────────────────────────────
local spawnTimer = 0
local BiomeData

local function doSpawn()
	if #Players:GetPlayers() == 0 then return end
	local player = Players:GetPlayers()[1]
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local ppos = hrp.Position

	-- Count active mobs
	local count = 0
	for _ in pairs(mobs) do count = count + 1 end
	if count >= C.MAX_MOBS then return end

	-- Spawn at random distance
	local angle = math.random() * math.pi * 2
	local dist = 25 + math.random() * 35
	local sx = ppos.X + math.cos(angle) * dist
	local sz = ppos.Z + math.sin(angle) * dist

	-- Find surface
	local WG = _G.WorldGen
	if not WG then return end
	local sy = 200
	for y = 200, 5, -1 do
		if WG.getBlock(floor(sx), y, floor(sz)) ~= B.AIR then
			sy = y + 1
			break
		end
	end

	-- Determine mob type based on biome
	if not BiomeData then BiomeData = require(Shared:WaitForChild("BiomeData")) end
	local bi = BiomeData.bio(sx, sz)
	local BI = BiomeData.BI

	local mobType
	-- Night is roughly dayTime 0.7-1.0 or 0.0-0.2 (midnight at 0.0/1.0, sunset at 0.75)
	local dayTime = _G.VCDayTime or 0.25
	local sy = math.sin(dayTime * math.pi * 2)
	local nightTime = sy < -0.1  -- negative sin = night

	if bi == BI.WATCHER then
		local knightCount = 0
		for _, m in pairs(mobs) do if m.mobType == MOB_TYPES.VC_KNIGHT then knightCount = knightCount + 1 end end
		if knightCount < 4 and math.random() < 0.3 then
			mobType = MOB_TYPES.VC_KNIGHT
		else
			mobType = MOB_TYPES.GARFBOT
		end
	elseif bi == BI.GARFBOT_CITY then
		mobType = MOB_TYPES.GARFBOT
	elseif bi == BI.OC or bi == BI.BE then
		mobType = math.random() < 0.6 and MOB_TYPES.FISH or MOB_TYPES.COW
	else
		if nightTime and math.random() < 0.4 then
			mobType = MOB_TYPES.GARFBOT
		else
			mobType = MOB_TYPES.COW
		end
	end

	spawnMob(mobType, Vector3.new(sx, sy, sz))
end

-- ─── Mob damage handler (from player attacking) ───────────────────────────────
RE[WorldUtils.RE.MOB_DAMAGE].OnServerEvent:Connect(function(player, mobId, damage, knockback)
	local mob = mobs[mobId]
	if not mob then return end
	if mob.deathTimer >= 0 then return end
	if mob.hurtTimer > 0 then return end

	mob.hurtTimer = 0.5
	mob.hp = mob.hp - damage

	-- Boss damage accumulation for stagger
	if mob.mobType == MOB_TYPES.GARFBOT_BOSS then
		mob.dmgAccum = mob.dmgAccum + damage
	end

	-- Knockback
	if knockback then
		mob.vel = Vector3.new(knockback.X * 5, 3, knockback.Z * 5)
	end

	-- Update all clients
	RE[WorldUtils.RE.MOB_UPDATE]:FireAllClients({
		action = "damage",
		id = mobId,
		hp = mob.hp,
		maxHp = mob.maxHp,
	})

	if mob.hp <= 0 then
		mob.deathTimer = 0
		RE[WorldUtils.RE.MOB_UPDATE]:FireAllClients({action="death", id=mobId})
		-- Drop items
		local drops = {}
		if mob.mobType == MOB_TYPES.GARFBOT then
			drops = {{B.COAL_I, math.random(1, 3)}, {B.IRON_I, math.random(0, 1)}}
		elseif mob.mobType == MOB_TYPES.GARFBOT_BOSS then
			drops = {
				{B.DIAM, math.random(5, 10)},
				{B.IRON_I, math.random(10, 20)},
				{B.DUNGEON_KEY, math.random(2, 4)},
				{B.GOLD_I, math.random(3, 6)},
			}
		elseif mob.mobType == MOB_TYPES.COW then
			drops = {{B.MEAT_RAW, math.random(1, 3)}}
		elseif mob.mobType == MOB_TYPES.FISH then
			drops = {{B.MEAT_RAW, 1}}
		elseif mob.mobType == MOB_TYPES.VC_KNIGHT then
			drops = {
				{B.IRON_I, math.random(3, 7)},
				{B.DUNGEON_KEY, math.random(0, 1)},
			}
		end
		for _, drop in ipairs(drops) do
			RE[WorldUtils.RE.ITEM_DROP]:FireAllClients(mob.pos, drop[1], drop[2])
		end
	end
end)

-- Boss spawn handler
RE[WorldUtils.RE.SPAWN_BOSS].OnServerEvent:Connect(function(player, wx, wy, wz)
	spawnMob(MOB_TYPES.GARFBOT_BOSS, Vector3.new(wx, wy + 2, wz))
end)

-- ─── Heartbeat ────────────────────────────────────────────────────────────────
local lastSync = 0
local SYNC_RATE = 0.05 -- 20hz sync

RunService.Heartbeat:Connect(function(dt)
	-- Tick all mobs
	local toRemove = {}
	for id, mob in pairs(mobs) do
		local ok, err = pcall(tickMob, mob, dt)
		if not ok then warn("Mob tick error: " .. tostring(err)) end
	end

	-- Sync mob positions to clients
	lastSync = lastSync + dt
	if lastSync >= SYNC_RATE then
		lastSync = 0
		local updates = {}
		for id, mob in pairs(mobs) do
			table.insert(updates, {
				id = mob.id,
				pos = {x=mob.pos.X, y=mob.pos.Y, z=mob.pos.Z},
				yaw = mob.yaw,
				animTime = mob.animTime,
				hp = mob.hp,
				deathTimer = mob.deathTimer,
				phase = mob.phase,
			})
		end
		if #updates > 0 then
			RE[WorldUtils.RE.MOB_UPDATE]:FireAllClients({action="batch_update", mobs=updates})
		end
	end

	-- Spawning
	spawnTimer = spawnTimer + dt
	if spawnTimer >= C.MOB_SPAWN_INTERVAL then
		spawnTimer = 0
		pcall(doSpawn)
	end
end)

-- Initial spawn
task.wait(5) -- wait for world to generate
pcall(doSpawn)
pcall(doSpawn)
pcall(doSpawn)

print("VC CRAFT Mob Manager initialized")
