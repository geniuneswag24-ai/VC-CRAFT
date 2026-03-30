-- VC CRAFT Game Manager Server
-- Handles day/night cycle, weather, game state broadcast
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local WorldUtils = require(Shared.WorldUtils)

local RE = {}
for _, name in pairs(WorldUtils.RE) do
	RE[name] = ReplicatedStorage:WaitForChild(name, 10)
end

local gameState = {
	dayTime = 0.25,   -- 0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset
	dayLength = C.DAY_LENGTH,
}

-- Day/night cycle
local lastDaySync = 0

-- Lighting setup
Lighting.GlobalShadows = true
-- Technology must be set in Studio properties, not via script
Lighting.Ambient = Color3.fromRGB(0, 0, 0)

local function updateLighting(dayTime)
	local pi = math.pi
	local tau = pi * 2
	local sa = dayTime * tau
	local sy = math.sin(sa) -- positive = day, negative = night
	local tw = math.clamp((sy + 0.15) / 0.3, 0, 1) -- twilight factor

	-- Sky color
	local skyColor
	if tw > 0.7 then
		skyColor = Color3.new(0.53, 0.81, 0.92) -- day blue
	elseif tw > 0.3 then
		local t = (tw - 0.3) / 0.4
		skyColor = Color3.new(
			0.9 + (0.53 - 0.9) * t,
			0.5 + (0.81 - 0.5) * t,
			0.3 + (0.92 - 0.3) * t
		)
	elseif tw > 0.05 then
		local t = (tw - 0.05) / 0.25
		skyColor = Color3.new(
			0.15 + (0.9 - 0.15) * t,
			0.1 + (0.5 - 0.1) * t,
			0.2 + (0.3 - 0.2) * t
		)
	else
		skyColor = Color3.new(0.06, 0.06, 0.18)
	end

	-- Sun/ambient brightness
	local sunIntensity = math.max(0.05, tw * 0.95)
	local ambientBright = 0.1 + tw * 0.35

	Lighting.Brightness = sunIntensity * 2
	Lighting.Ambient = Color3.new(ambientBright * 0.8, ambientBright * 0.85, ambientBright * 0.9)
	Lighting.OutdoorAmbient = skyColor

	-- Time of day for Roblox sky
	-- Map dayTime (0-1) to Roblox time (0-24)
	Lighting.TimeOfDay = string.format("%02d:%02d:00", math.floor(dayTime * 24), math.floor((dayTime * 24 % 1) * 60))

	-- Fog
	Lighting.FogEnd = C.RD * C.CS * C.BLOCK_SIZE * 0.9
	Lighting.FogColor = skyColor

	return tw
end

RunService.Heartbeat:Connect(function(dt)
	-- Advance time
	gameState.dayTime = (gameState.dayTime + dt / gameState.dayLength) % 1

	-- Expose to other server scripts
	_G.VCDayTime = gameState.dayTime

	-- Update lighting
	updateLighting(gameState.dayTime)

	-- Sync day time to clients every 5 seconds
	lastDaySync = lastDaySync + dt
	if lastDaySync >= 5 then
		lastDaySync = 0
		RE[WorldUtils.RE.DAY_NIGHT]:FireAllClients(gameState.dayTime)
	end
end)

-- Handle player spawn point
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Wait for WorldGen to finish spawn area
		local WG
		local deadline = tick() + 20
		while tick() < deadline do
			WG = _G.WorldGen
			if WG then
				-- Check that chunk 0,0 is actually generated
				local key = WorldUtils.chunkKey(0, 0)
				if WG.chunks and WG.chunks[key] then break end
			end
			task.wait(0.5)
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Scan surface near origin, try a few offsets for a dry spawn
			local spawnX = 0; local spawnZ = 0
			local spawnY = 200
			local B_ref = require(Shared.BlockTypes).B

			if WG then
				-- Try up to 5 search positions around origin
				local found = false
				for _, off in ipairs({{0,0},{2,0},{-2,0},{0,2},{0,-2},{4,4}}) do
					local sx, sz = off[1], off[2]
					for y = C.CH - 1, 5, -1 do
						local bv = WG.getBlock(sx, y, sz)
						if bv ~= 0 and bv ~= B_ref.WATER and bv ~= B_ref.LAVA then
							-- Ensure 2 air blocks above for player body
							local a1 = WG.getBlock(sx, y+1, sz)
							local a2 = WG.getBlock(sx, y+2, sz)
							if a1 == 0 and a2 == 0 then
								spawnX = sx; spawnZ = sz; spawnY = y + 1
								found = true; break
							end
						end
					end
					if found then break end
				end
			end
			hrp.CFrame = CFrame.new(spawnX * C.BLOCK_SIZE, spawnY * C.BLOCK_SIZE, spawnZ * C.BLOCK_SIZE)
		end

		-- Send initial game state
		RE[WorldUtils.RE.GAME_STATE]:FireClient(player, {
			seed = _G.WorldGen and _G.WorldGen.seed or 1,
			dayTime = gameState.dayTime,
		})
	end)
end)

-- Cheat commands (server-side validation)
RE[WorldUtils.RE.GAME_STATE].OnServerEvent:Connect(function(player, action, data)
	if action == "cheat_day" then
		gameState.dayTime = 0.25
	elseif action == "cheat_night" then
		gameState.dayTime = 0.75
	end
end)

print("VC CRAFT Game Manager initialized")
