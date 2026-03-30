-- VC CRAFT HUD Client
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local BT = require(Shared.BlockTypes)
local WorldUtils = require(Shared.WorldUtils)

local B = BT.B
local BD = BT.BD
local BS = C.BLOCK_SIZE
local CS = C.CS

-- BiomeData needs initNoise called before bio() works.
-- Initialize with seed=1 as a safe default; re-initialize when the real seed
-- arrives via GAME_STATE so the debug biome label shows the correct biome.
local BiomeData = require(Shared:WaitForChild("BiomeData"))
BiomeData.initNoise(1)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RE = {}
for _, name in pairs(WorldUtils.RE) do
	RE[name] = ReplicatedStorage:WaitForChild(name, 10)
end

-- ─── Build main HUD ───────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VCHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Crosshair
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.BackgroundTransparency = 1
crosshair.Parent = screenGui

local ch_h = Instance.new("Frame")
ch_h.Size = UDim2.new(1, 0, 0, 2)
ch_h.Position = UDim2.new(0, 0, 0.5, -1)
ch_h.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
ch_h.BackgroundTransparency = 0.3
ch_h.BorderSizePixel = 0
ch_h.Parent = crosshair

local ch_v = Instance.new("Frame")
ch_v.Size = UDim2.new(0, 2, 1, 0)
ch_v.Position = UDim2.new(0.5, -1, 0, 0)
ch_v.BackgroundColor3 = Color3.new(0.8, 0.8, 0.8)
ch_v.BackgroundTransparency = 0.3
ch_v.BorderSizePixel = 0
ch_v.Parent = crosshair

-- ─── Hotbar ───────────────────────────────────────────────────────────────────
local hotbarFrame = Instance.new("Frame")
hotbarFrame.Name = "Hotbar"
hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
hotbarFrame.Position = UDim2.new(0.5, 0, 1, -4)
hotbarFrame.Size = UDim2.new(0, 9*46, 0, 46)
hotbarFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
hotbarFrame.BackgroundTransparency = 0.3
hotbarFrame.BorderSizePixel = 2
hotbarFrame.BorderColor3 = Color3.fromRGB(10, 10, 10)
hotbarFrame.Parent = screenGui

local UIL = Instance.new("UIListLayout")
UIL.FillDirection = Enum.FillDirection.Horizontal
UIL.Padding = UDim.new(0, 2)
UIL.VerticalAlignment = Enum.VerticalAlignment.Center
UIL.Parent = hotbarFrame

local hotbarSlots = {}
for i = 1, 9 do
	local slot = Instance.new("Frame")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0, 42, 0, 42)
	slot.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
	slot.BorderSizePixel = 1
	slot.BorderColor3 = Color3.fromRGB(51, 51, 51)
	slot.Parent = hotbarFrame

	local label = Instance.new("TextLabel")
	label.Name = "Count"
	label.Size = UDim2.new(1, -2, 0, 10)
	label.Position = UDim2.new(0, 2, 1, -12)
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 8
	label.Font = Enum.Font.Arcade
	label.TextStrokeTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Parent = slot

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, -3)
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
	icon.BorderSizePixel = 0
	icon.Parent = slot

	hotbarSlots[i] = {frame=slot, label=label, icon=icon}
end

-- ─── Health bar ───────────────────────────────────────────────────────────────
local healthFrame = Instance.new("Frame")
healthFrame.Name = "HealthBar"
healthFrame.AnchorPoint = Vector2.new(0.5, 1)
healthFrame.Position = UDim2.new(0.5, -93, 1, -54)
healthFrame.Size = UDim2.new(0, 182, 0, 10)
healthFrame.BackgroundTransparency = 1
healthFrame.Parent = screenGui

local heartLabels = {}
for i = 1, 10 do
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.new(0, 9, 0, 9)
	heart.Position = UDim2.new(0, (i-1)*18, 0, 0)
	heart.BackgroundTransparency = 1
	heart.Text = "♥"
	heart.TextColor3 = Color3.fromRGB(226, 34, 34)
	heart.TextSize = 10
	heart.Font = Enum.Font.Arcade
	heart.Parent = healthFrame
	heartLabels[i] = heart
end

-- ─── Hunger bar ───────────────────────────────────────────────────────────────
local hungerFrame = Instance.new("Frame")
hungerFrame.Name = "HungerBar"
hungerFrame.AnchorPoint = Vector2.new(0, 1)
hungerFrame.Position = UDim2.new(0.5, 93, 1, -54)
hungerFrame.Size = UDim2.new(0, 182, 0, 10)
hungerFrame.BackgroundTransparency = 1
hungerFrame.Parent = screenGui

local foodLabels = {}
for i = 1, 10 do
	local food = Instance.new("TextLabel")
	food.Size = UDim2.new(0, 9, 0, 9)
	food.Position = UDim2.new(0, (10-i)*18, 0, 0)
	food.BackgroundTransparency = 1
	food.Text = "🍗"
	food.TextColor3 = Color3.fromRGB(200, 132, 68)
	food.TextSize = 10
	food.Font = Enum.Font.Arcade
	food.Parent = hungerFrame
	foodLabels[i] = food
end

-- ─── Debug info ───────────────────────────────────────────────────────────────
local debugLabel = Instance.new("TextLabel")
debugLabel.Name = "Debug"
debugLabel.Position = UDim2.new(0, 4, 0, 4)
debugLabel.Size = UDim2.new(0, 300, 0, 200)
debugLabel.BackgroundTransparency = 1
debugLabel.TextColor3 = Color3.new(1, 1, 1)
debugLabel.TextSize = 8
debugLabel.Font = Enum.Font.Arcade
debugLabel.TextStrokeTransparency = 0
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.TextYAlignment = Enum.TextYAlignment.Top
debugLabel.Parent = screenGui

-- ─── Block name display ───────────────────────────────────────────────────────
local blockNameLabel = Instance.new("TextLabel")
blockNameLabel.Name = "BlockName"
blockNameLabel.AnchorPoint = Vector2.new(0.5, 0)
blockNameLabel.Position = UDim2.new(0.5, 0, 0.5, 18)
blockNameLabel.Size = UDim2.new(0, 200, 0, 14)
blockNameLabel.BackgroundTransparency = 1
blockNameLabel.Text = ""
blockNameLabel.TextColor3 = Color3.new(1, 1, 1)
blockNameLabel.TextSize = 9
blockNameLabel.Font = Enum.Font.Arcade
blockNameLabel.TextStrokeTransparency = 0
blockNameLabel.Parent = screenGui

-- ─── Water overlay ────────────────────────────────────────────────────────────
local waterOverlay = Instance.new("Frame")
waterOverlay.Name = "WaterOverlay"
waterOverlay.Position = UDim2.new(0, 0, 0, 0)
waterOverlay.Size = UDim2.new(1, 0, 1, 0)
waterOverlay.BackgroundColor3 = Color3.fromRGB(20, 60, 150)
waterOverlay.BackgroundTransparency = 0.65
waterOverlay.BorderSizePixel = 0
waterOverlay.Visible = false
waterOverlay.ZIndex = 8
waterOverlay.Parent = screenGui

-- ─── Boss health bar ─────────────────────────────────────────────────────────
local bossFrame = Instance.new("Frame")
bossFrame.Name = "BossHP"
bossFrame.AnchorPoint = Vector2.new(0.5, 0)
bossFrame.Position = UDim2.new(0.5, 0, 0, 20)
bossFrame.Size = UDim2.new(0, 400, 0, 24)
bossFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
bossFrame.BackgroundTransparency = 0.3
bossFrame.BorderSizePixel = 1
bossFrame.BorderColor3 = Color3.fromRGB(200, 0, 0)
bossFrame.Visible = false
bossFrame.ZIndex = 10
bossFrame.Parent = screenGui

local bossNameLabel = Instance.new("TextLabel")
bossNameLabel.Size = UDim2.new(1, 0, 0, 10)
bossNameLabel.BackgroundTransparency = 1
bossNameLabel.Text = "GARBOT SENTIENT"
bossNameLabel.TextColor3 = Color3.fromRGB(255, 68, 68)
bossNameLabel.TextSize = 8
bossNameLabel.Font = Enum.Font.Arcade
bossNameLabel.TextStrokeTransparency = 0
bossNameLabel.Parent = bossFrame

local bossBarBg = Instance.new("Frame")
bossBarBg.Position = UDim2.new(0, 4, 0, 12)
bossBarBg.Size = UDim2.new(1, -8, 0, 8)
bossBarBg.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
bossBarBg.BorderSizePixel = 0
bossBarBg.Parent = bossFrame

local bossBar = Instance.new("Frame")
bossBar.Size = UDim2.new(1, 0, 1, 0)
bossBar.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
bossBar.BorderSizePixel = 0
bossBar.Parent = bossBarBg

-- ─── Death screen ─────────────────────────────────────────────────────────────
local deathFrame = Instance.new("Frame")
deathFrame.Name = "DeathUI"
deathFrame.Size = UDim2.new(1, 0, 1, 0)
deathFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
deathFrame.BackgroundTransparency = 0.5
deathFrame.Visible = false
deathFrame.ZIndex = 55
deathFrame.Parent = screenGui

local deathTitle = Instance.new("TextLabel")
deathTitle.AnchorPoint = Vector2.new(0.5, 0.5)
deathTitle.Position = UDim2.new(0.5, 0, 0.4, 0)
deathTitle.Size = UDim2.new(0, 400, 0, 60)
deathTitle.BackgroundTransparency = 1
deathTitle.Text = "You Died!"
deathTitle.TextColor3 = Color3.new(1, 1, 1)
deathTitle.TextSize = 32
deathTitle.Font = Enum.Font.Arcade
deathTitle.TextStrokeTransparency = 0
deathTitle.ZIndex = 56
deathTitle.Parent = deathFrame

local deathSub = Instance.new("TextLabel")
deathSub.AnchorPoint = Vector2.new(0.5, 0)
deathSub.Position = UDim2.new(0.5, 0, 0.5, 0)
deathSub.Size = UDim2.new(0, 400, 0, 20)
deathSub.BackgroundTransparency = 1
deathSub.Text = "GARFBOT got you..."
deathSub.TextColor3 = Color3.fromRGB(204, 204, 204)
deathSub.TextSize = 9
deathSub.Font = Enum.Font.Arcade
deathSub.TextStrokeTransparency = 0
deathSub.ZIndex = 56
deathSub.Parent = deathFrame

local respawnButton = Instance.new("TextButton")
respawnButton.AnchorPoint = Vector2.new(0.5, 0)
respawnButton.Position = UDim2.new(0.5, 0, 0.58, 0)
respawnButton.Size = UDim2.new(0, 240, 0, 32)
respawnButton.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
respawnButton.Text = "Respawn"
respawnButton.TextColor3 = Color3.new(1, 1, 1)
respawnButton.TextSize = 11
respawnButton.Font = Enum.Font.Arcade
respawnButton.ZIndex = 56
respawnButton.Parent = deathFrame

respawnButton.MouseButton1Click:Connect(function()
	deathFrame.Visible = false
	local ps = _G.PlayerState
	if ps then
		ps.hp = C.PLAYER_HP
		ps.hunger = C.PLAYER_HUNGER
		ps.hurtTimer = 0
	end
	-- Respawn character
	player:LoadCharacter()
	if _G.VCUpdateHUD then _G.VCUpdateHUD() end
end)

-- ─── Break overlay ────────────────────────────────────────────────────────────
local breakOverlay = nil
local breakTargetPos = nil
local breakHighlight = Instance.new("SelectionBox")
breakHighlight.Color3 = Color3.new(0, 0, 0)
breakHighlight.LineThickness = 0.06
breakHighlight.SurfaceTransparency = 0.8
breakHighlight.SurfaceColor3 = Color3.new(0, 0, 0)
breakHighlight.Parent = screenGui

-- ─── Item drops (visual) ─────────────────────────────────────────────────────
local itemDrops = {}

local function spawnItemDrop(pos, itemId, count)
	local bd = BD[itemId]
	if not bd then return end
	local colors = BT.BC[itemId]
	local color = colors and colors[1] or Color3.new(0.5, 0.5, 0.5)

	local part = Instance.new("Part")
	part.Size = Vector3.new(BS*0.4, BS*0.4, BS*0.4)
	part.CFrame = CFrame.new(pos.X * BS, pos.Y * BS + BS*0.3, pos.Z * BS)
	part.BrickColor = BrickColor.new(color)
	part.Anchored = false
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = Workspace

	-- Spinning billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 20, 0, 20)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(1, 0, 1, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = count > 1 and tostring(count) or ""
	countLabel.TextColor3 = Color3.new(1, 1, 1)
	countLabel.TextSize = 8
	countLabel.Font = Enum.Font.Arcade
	countLabel.TextStrokeTransparency = 0
	countLabel.Parent = billboard

	local drop = {part=part, age=0, pos=pos, itemId=itemId, count=count}
	table.insert(itemDrops, drop)
end
_G.VCSpawnItemDrop = spawnItemDrop

-- ─── HUD update functions ─────────────────────────────────────────────────────
local function updateHUD()
	local ps = _G.PlayerState
	if not ps then return end

	-- Health hearts
	for i = 1, 10 do
		local filled = (ps.hp / 2) >= i
		heartLabels[i].TextColor3 = filled and Color3.fromRGB(226, 34, 34) or Color3.fromRGB(68, 68, 68)
	end

	-- Hunger icons
	for i = 1, 10 do
		local filled = (ps.hunger / 2) >= i
		foodLabels[i].TextColor3 = filled and Color3.fromRGB(200, 132, 68) or Color3.fromRGB(68, 68, 68)
	end

	-- Hotbar slots
	for i = 1, 9 do
		local slot = hotbarSlots[i]
		local item = ps.hotbar[i]

		-- Selected slot highlight
		if i == ps.sel then
			slot.frame.BorderColor3 = Color3.fromRGB(221, 221, 221)
			slot.frame.BorderSizePixel = 2
			slot.frame.BackgroundColor3 = Color3.fromRGB(119, 119, 119)
		else
			slot.frame.BorderColor3 = Color3.fromRGB(51, 51, 51)
			slot.frame.BorderSizePixel = 1
			slot.frame.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
		end

		if item then
			local bd = BD[item.id]
			local colors = BT.BC[item.id]
			slot.icon.BackgroundColor3 = colors and colors[1] or Color3.new(0.5, 0.5, 0.5)
			slot.label.Text = item.count > 1 and tostring(item.count) or ""
		else
			slot.icon.BackgroundColor3 = Color3.fromRGB(68, 68, 68)
			slot.label.Text = ""
		end
	end
end
_G.VCUpdateHUD = updateHUD

local function showDeath()
	deathFrame.Visible = true
end
_G.VCShowDeath = showDeath

local function showHurt()
	-- Flash screen red briefly
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	flash.BackgroundTransparency = 0.6
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = screenGui
	local tw = TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency=1})
	tw:Play()
	tw.Completed:Connect(function() flash:Destroy() end)
end
_G.VCShowHurt = showHurt

local function setTargetBlock(blockId)
	if blockId then
		local bd = BD[blockId]
		blockNameLabel.Text = bd and bd.name or ""
	else
		blockNameLabel.Text = ""
	end
end
_G.VCSetTargetBlock = setTargetBlock

local function updateBreakOverlay(wx, wy, wz, progress)
	-- Find the voxel part in the chunk
	local cx = math.floor(wx / CS); local cz = math.floor(wz / CS)
	local key = WorldUtils.chunkKey(cx, cz)
	local chunkFolder = Workspace:FindFirstChild("VCCraftChunks")
	if not chunkFolder then return end
	local model = chunkFolder:FindFirstChild("Chunk_" .. cx .. "_" .. cz)
	if not model then return end

	-- Show a progress indicator (simple transparent box)
	if progress > 0 then
		-- Find part at this position
		local targetPos = Vector3.new((wx+0.5)*BS, (wy+0.5)*BS, (wz+0.5)*BS)
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") then
				if (part.Position - targetPos).Magnitude < BS*0.6 then
					breakHighlight.Adornee = part
					break
				end
			end
		end
		-- Stage-based color
		local stage = math.floor(progress * 6)
		local r = 0.1 + stage * 0.1
		breakHighlight.SurfaceColor3 = Color3.new(r, 0, 0)
		breakHighlight.SurfaceTransparency = 0.9 - progress * 0.5
	else
		breakHighlight.Adornee = nil
	end
end
_G.VCUpdateBreakOverlay = updateBreakOverlay

-- ─── Mob visuals tracking ─────────────────────────────────────────────────────
_G.VCMobs = {}

-- ─── Mob rendering ───────────────────────────────────────────────────────────
local mobModels = {}

local function getMobColors(mobType)
	if mobType == "Garfbot" then return {Color3.fromRGB(68,68,85), Color3.fromRGB(255,34,0)} end
	if mobType == "GarfbotBoss" then return {Color3.fromRGB(80,40,20), Color3.fromRGB(255,100,0)} end
	if mobType == "Cow" then return {Color3.fromRGB(139,105,20), Color3.fromRGB(245,245,220)} end
	if mobType == "Fish" then return {Color3.fromRGB(68,136,204), Color3.fromRGB(30,80,150)} end
	if mobType == "VCKnight" then return {Color3.fromRGB(58,56,48), Color3.fromRGB(136,204,255)} end
	return {Color3.fromRGB(100,100,100), Color3.fromRGB(150,150,150)}
end

local function buildMobModel(mob)
	if mobModels[mob.id] then return end
	local colors = getMobColors(mob.mobType)
	local isBoss = mob.mobType == "GarfbotBoss"
	local scale = isBoss and 2 or 1

	local model = Instance.new("Model")
	model.Name = "Mob_" .. mob.id

	-- Body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(BS*0.8*scale, BS*1.2*scale, BS*0.6*scale)
	body.BrickColor = BrickColor.new(colors[1])
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(BS*0.7*scale, BS*0.7*scale, BS*0.7*scale)
	head.BrickColor = BrickColor.new(colors[1])
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- Eyes
	if mob.mobType == "Garfbot" or mob.mobType == "GarfbotBoss" then
		-- Glowing red eyes
		local eyeL = Instance.new("Part")
		eyeL.Name = "EyeL"
		eyeL.Size = Vector3.new(BS*0.15*scale, BS*0.15*scale, BS*0.05*scale)
		eyeL.BrickColor = BrickColor.new(colors[2])
		eyeL.Material = Enum.Material.Neon
		eyeL.Anchored = true
		eyeL.CanCollide = false
		eyeL.Parent = model

		local eyeR = eyeL:Clone()
		eyeR.Name = "EyeR"
		eyeR.Parent = model

		-- Neon chest panel (GARF text approximation)
		local chest = Instance.new("Part")
		chest.Name = "Chest"
		chest.Size = Vector3.new(BS*0.4*scale, BS*0.3*scale, BS*0.05*scale)
		chest.BrickColor = BrickColor.new(colors[2])
		chest.Material = Enum.Material.Neon
		chest.Anchored = true
		chest.CanCollide = false
		chest.Parent = model

		-- Point light for glow effect
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 34, 0)
		light.Brightness = isBoss and 2 or 1
		light.Range = isBoss and 20 or 12
		light.Parent = body
	elseif mob.mobType == "VCKnight" then
		-- Blue visor
		local visor = Instance.new("Part")
		visor.Name = "Visor"
		visor.Size = Vector3.new(BS*0.6*scale, BS*0.15*scale, BS*0.05*scale)
		visor.BrickColor = BrickColor.new(colors[2])
		visor.Material = Enum.Material.Neon
		visor.Anchored = true
		visor.CanCollide = false
		visor.Parent = model
	end

	-- HP bar (billboard)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HPBar"
	billboard.Size = UDim2.new(0, 60*scale, 0, 8)
	billboard.StudsOffset = Vector3.new(0, BS*scale*1.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = body

	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(1, 0, 1, 0)
	hpBg.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
	hpBg.BorderSizePixel = 1
	hpBg.BorderColor3 = Color3.new(0,0,0)
	hpBg.Parent = billboard

	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(220, 0, 0)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	model.PrimaryPart = body
	model.Parent = Workspace

	mobModels[mob.id] = {
		model = model, body = body, head = head,
		hpFill = hpFill, scale = scale
	}

	-- Store reference
	if not _G.VCMobs then _G.VCMobs = {} end
	_G.VCMobs[mob.id] = mob
end

local function updateMobModel(mob, data)
	local mm = mobModels[mob.id]
	if not mm then return end

	local pos = Vector3.new(data.pos.x * BS, data.pos.y * BS, data.pos.z * BS)
	local yaw = data.yaw or 0
	local scale = mm.scale
	local anim = data.animTime or 0

	-- Leg bob animation
	local walkSin = math.sin(anim * 6)
	local walkCos = math.cos(anim * 6)

	local bodyOffset = Vector3.new(0, BS*0.6*scale, 0)
	mm.body.CFrame = CFrame.new(pos + bodyOffset) * CFrame.Angles(0, yaw, 0)

	local headOffset = Vector3.new(0, BS*1.0*scale + BS*0.35*scale, 0)
	mm.head.CFrame = CFrame.new(pos + headOffset) * CFrame.Angles(0, yaw, 0)

	-- Update eye and chest positions for Garfbot
	if mob.mobType == "Garfbot" or mob.mobType == "GarfbotBoss" then
		local eyeL = mm.model:FindFirstChild("EyeL")
		local eyeR = mm.model:FindFirstChild("EyeR")
		local chest = mm.model:FindFirstChild("Chest")
		local fwd = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
		local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))

		if eyeL then eyeL.CFrame = CFrame.new(pos + headOffset + right*(BS*0.15*scale) + fwd*(BS*0.3*scale) + Vector3.new(0, BS*0.1*scale, 0)) end
		if eyeR then eyeR.CFrame = CFrame.new(pos + headOffset - right*(BS*0.15*scale) + fwd*(BS*0.3*scale) + Vector3.new(0, BS*0.1*scale, 0)) end
		if chest then chest.CFrame = CFrame.new(pos + bodyOffset + fwd*(BS*0.28*scale)) * CFrame.Angles(0, yaw, 0) end
	end

	-- HP bar
	if data.hp and data.maxHp then
		mm.hpFill.Size = UDim2.new(data.hp / data.maxHp, 0, 1, 0)
	end

	-- Death: tilt over
	if data.deathTimer and data.deathTimer >= 0 then
		local tilt = math.min(data.deathTimer / 1.5, 1) * math.pi / 2
		mm.body.CFrame = mm.body.CFrame * CFrame.Angles(0, 0, tilt)
		mm.head.CFrame = mm.head.CFrame * CFrame.Angles(0, 0, tilt)
		-- Fade
		mm.body.Transparency = math.min(data.deathTimer / 1.5, 1)
		mm.head.Transparency = math.min(data.deathTimer / 1.5, 1)
	end
end

-- ─── RE handlers ─────────────────────────────────────────────────────────────
RE[WorldUtils.RE.MOB_UPDATE].OnClientEvent:Connect(function(data)
	if data.action == "spawn" then
		local mob = {id=data.id, mobType=data.mobType, pos=data.pos, hp=data.hp, maxHp=data.maxHp}
		if _G.VCMobs then _G.VCMobs[data.id] = mob end
		buildMobModel(mob)

	elseif data.action == "remove" then
		if mobModels[data.id] then
			mobModels[data.id].model:Destroy()
			mobModels[data.id] = nil
		end
		if _G.VCMobs then _G.VCMobs[data.id] = nil end

	elseif data.action == "death" then
		local mm = mobModels[data.id]
		if mm then
			-- Will be cleaned up by batch update death timer
		end

	elseif data.action == "damage" then
		if _G.VCMobs and _G.VCMobs[data.id] then
			_G.VCMobs[data.id].hp = data.hp
			if mobModels[data.id] then
				mobModels[data.id].hpFill.Size = UDim2.new(data.hp / data.maxHp, 0, 1, 0)
			end
		end

	elseif data.action == "batch_update" then
		for _, mobData in ipairs(data.mobs) do
			local mob = _G.VCMobs and _G.VCMobs[mobData.id]
			if mob then
				mob.pos = mobData.pos
				mob.hp = mobData.hp
				updateMobModel(mob, mobData)
			end
		end
	end
end)

-- Boss health bar update
RE[WorldUtils.RE.MOB_UPDATE].OnClientEvent:Connect(function(data)
	if data.action == "spawn" and data.mobType == "GarfbotBoss" then
		bossFrame.Visible = true
	elseif data.action == "remove" and _G.VCMobs and _G.VCMobs[data.id] then
		if _G.VCMobs[data.id].mobType == "GarfbotBoss" then
			bossFrame.Visible = false
		end
	elseif data.action == "damage" and _G.VCMobs and _G.VCMobs[data.id] then
		if _G.VCMobs[data.id].mobType == "GarfbotBoss" then
			bossBar.Size = UDim2.new(data.hp / data.maxHp, 0, 1, 0)
		end
	end
end)

-- Re-initialize BiomeData with the real world seed when server sends it
RE[WorldUtils.RE.GAME_STATE].OnClientEvent:Connect(function(data)
	if data and data.seed then
		BiomeData.initNoise(data.seed)
	end
end)

-- ─── Day/night visual feedback ────────────────────────────────────────────────
local dayTime = 0.25
RE[WorldUtils.RE.DAY_NIGHT].OnClientEvent:Connect(function(dt)
	dayTime = dt
end)

-- ─── Main update loop ─────────────────────────────────────────────────────────
local fps = 60
local frameCount = 0
local lastFPSUpdate = 0
local lastTime = tick()

RunService.RenderStepped:Connect(function(dt)
	frameCount = frameCount + 1
	local now = tick()
	if now - lastFPSUpdate >= 1 then
		fps = frameCount / (now - lastFPSUpdate)
		frameCount = 0
		lastFPSUpdate = now
	end

	-- Update HUD
	updateHUD()

	-- Water overlay
	local ps = _G.PlayerState
	waterOverlay.Visible = ps and ps.headInWater or false

	-- Item drops physics
	local char = player.Character
	local ppos = char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position or Vector3.new(0,0,0)
	local toRemove = {}
	for i, drop in ipairs(itemDrops) do
		drop.age = drop.age + dt
		if drop.age > 60 then
			table.insert(toRemove, i)
		elseif (drop.part.Position - ppos).Magnitude < BS * 1.5 then
			-- Pickup
			if _G.VCAddItem then _G.VCAddItem(drop.itemId, drop.count) end
			table.insert(toRemove, i)
		else
			-- Float animation
			local baseY = drop.pos.Y * BS + BS * 0.3
			local floatY = baseY + math.sin(drop.age * 3) * BS * 0.08
			drop.part.CFrame = CFrame.new(drop.part.Position.X, floatY, drop.part.Position.Z) * CFrame.Angles(0, drop.age * 2, 0)
		end
	end
	for i = #toRemove, 1, -1 do
		local drop = itemDrops[table.remove(toRemove, i)]
		if drop then drop.part:Destroy() end
		table.remove(itemDrops, toRemove[i] or i)
	end

	-- Debug info
	if ps then
		local char2 = player.Character
		local hrp = char2 and char2:FindFirstChild("HumanoidRootPart")
		local pos = hrp and hrp.Position or Vector3.new(0,0,0)
		local wx = math.floor(pos.X / BS)
		local wy = math.floor(pos.Y / BS) - C.Y_OFF
		local wz = math.floor(pos.Z / BS)

		local bi = BiomeData.bio(wx, wz) or 0
		local BDt = BiomeData.BDt or {}
		local biomeName = BDt[bi] and BDt[bi].n or "Unknown"

		-- Count loaded chunks
		local chunkCount = 0
		local chunkFolder = Workspace:FindFirstChild("VCCraftChunks")
		if chunkFolder then chunkCount = #chunkFolder:GetChildren() end

		debugLabel.Text = string.format(
			"VC CRAFT 1.1\n%s\nXYZ: %d %d %d\nBiome: %s\nFPS: %d\nChunks: %d\nDay: %.2f",
			ps.mode == "creative" and "Creative" or "Survival",
			wx, wy, wz, biomeName, math.floor(fps), chunkCount, dayTime
		)
	end
end)

print("VC CRAFT HUD initialized")
