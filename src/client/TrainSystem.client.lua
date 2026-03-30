-- VC CRAFT Train System Client
-- Handles rail carts, mounting, riding, throttle, braking, fuel, and dismount
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local WorldUtils = require(Shared.WorldUtils)
local BT = require(Shared.BlockTypes)

local B = BT.B
local BS = C.BLOCK_SIZE
local CS = C.CS

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── Constants ────────────────────────────────────────────────────────────────
local CART_SPEED_MAX   = 40   -- studs/sec max speed
local CART_ACCEL       = 12   -- studs/sec^2 acceleration
local CART_BRAKE       = 20   -- studs/sec^2 braking
local CART_GRAVITY     = 0.8  -- downhill speed gain multiplier
local CART_FUEL_USE    = 0.5  -- coal % per second while accelerating
local CART_FUEL_IDLE   = 0.05 -- coal % per second while idle
local RAIL_SNAP_RADIUS = 3    -- studs to snap to rail
local MOUNT_RADIUS     = 10   -- studs to detect nearby carts

-- ─── Rail block IDs ───────────────────────────────────────────────────────────
local RAIL_BLOCKS = {
	[B.RAIL_BLK]     = "EW",
	[B.RAIL_IRON]    = "NS",
	[B.RAIL_POWERED] = "EW",
}

-- Direction vectors for EW and NS rails
local DIR_EW = Vector3.new(1, 0, 0)
local DIR_NS = Vector3.new(0, 0, 1)

-- ─── Cart state ───────────────────────────────────────────────────────────────
local cartState = {
	mounted     = false,
	cartModel   = nil,
	cartPart    = nil,
	position    = Vector3.new(0, 0, 0),
	velocity    = 0,     -- signed speed along direction
	direction   = DIR_EW, -- current travel direction
	fuel        = 100,   -- 0-100%
	railType    = B.RAIL, -- current rail block
	onRail      = false,
	lastRailPos = nil,
	throttle    = 0,     -- -1 to 1
}

-- ─── HUD elements ─────────────────────────────────────────────────────────────
local trainGui = Instance.new("ScreenGui")
trainGui.Name = "VCTrainHUD"
trainGui.ResetOnSpawn = false
trainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
trainGui.Enabled = false
trainGui.Parent = playerGui

local trainHUD = Instance.new("Frame")
trainHUD.Size = UDim2.new(0, 280, 0, 120)
trainHUD.Position = UDim2.new(0.5, -140, 1, -160)
trainHUD.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
trainHUD.BackgroundTransparency = 0.3
trainHUD.BorderSizePixel = 0
trainHUD.Parent = trainGui

local tHUDCorner = Instance.new("UICorner")
tHUDCorner.CornerRadius = UDim.new(0, 10)
tHUDCorner.Parent = trainHUD

local tHUDStroke = Instance.new("UIStroke")
tHUDStroke.Color = Color3.fromRGB(80, 120, 180)
tHUDStroke.Thickness = 1.5
tHUDStroke.Parent = trainHUD

-- Speed display
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 40)
speedLabel.Position = UDim2.new(0, 0, 0, 5)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "0 km/h"
speedLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
speedLabel.Font = Enum.Font.GothamBold
speedLabel.TextSize = 28
speedLabel.Parent = trainHUD

-- Fuel bar background
local fuelBg = Instance.new("Frame")
fuelBg.Size = UDim2.new(0.85, 0, 0, 12)
fuelBg.Position = UDim2.new(0.075, 0, 0, 52)
fuelBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
fuelBg.BorderSizePixel = 0
fuelBg.Parent = trainHUD

local fuelBgCorner = Instance.new("UICorner")
fuelBgCorner.CornerRadius = UDim.new(1, 0)
fuelBgCorner.Parent = fuelBg

local fuelBar = Instance.new("Frame")
fuelBar.Size = UDim2.new(1, 0, 1, 0)
fuelBar.BackgroundColor3 = Color3.fromRGB(220, 160, 30)
fuelBar.BorderSizePixel = 0
fuelBar.Parent = fuelBg

local fuelBarCorner = Instance.new("UICorner")
fuelBarCorner.CornerRadius = UDim.new(1, 0)
fuelBarCorner.Parent = fuelBar

local fuelLabel = Instance.new("TextLabel")
fuelLabel.Size = UDim2.new(1, 0, 0, 16)
fuelLabel.Position = UDim2.new(0, 0, 0, 67)
fuelLabel.BackgroundTransparency = 1
fuelLabel.Text = "Fuel: 100%"
fuelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
fuelLabel.Font = Enum.Font.Gotham
fuelLabel.TextSize = 13
fuelLabel.Parent = trainHUD

-- Controls hint
local controlsLabel = Instance.new("TextLabel")
controlsLabel.Size = UDim2.new(1, 0, 0, 18)
controlsLabel.Position = UDim2.new(0, 0, 0, 94)
controlsLabel.BackgroundTransparency = 1
controlsLabel.Text = "[W] Throttle  [S] Brake  [Q] Dismount"
controlsLabel.TextColor3 = Color3.fromRGB(140, 160, 180)
controlsLabel.Font = Enum.Font.Gotham
controlsLabel.TextSize = 12
controlsLabel.Parent = trainHUD

-- Throttle indicator arrows
local throttleFrame = Instance.new("Frame")
throttleFrame.Size = UDim2.new(0, 60, 0, 40)
throttleFrame.Position = UDim2.new(1, -68, 0, 5)
throttleFrame.BackgroundTransparency = 1
throttleFrame.Parent = trainHUD

local arrowFwd = Instance.new("TextLabel")
arrowFwd.Size = UDim2.new(1, 0, 0.5, 0)
arrowFwd.BackgroundTransparency = 1
arrowFwd.Text = "▲"
arrowFwd.TextColor3 = Color3.fromRGB(100, 200, 100)
arrowFwd.Font = Enum.Font.GothamBold
arrowFwd.TextSize = 16
arrowFwd.TextTransparency = 0.6
arrowFwd.Parent = throttleFrame

local arrowBck = Instance.new("TextLabel")
arrowBck.Size = UDim2.new(1, 0, 0.5, 0)
arrowBck.Position = UDim2.new(0, 0, 0.5, 0)
arrowBck.BackgroundTransparency = 1
arrowBck.Text = "▼"
arrowBck.TextColor3 = Color3.fromRGB(200, 100, 100)
arrowBck.Font = Enum.Font.GothamBold
arrowBck.TextSize = 16
arrowBck.TextTransparency = 0.6
arrowBck.Parent = throttleFrame

-- ─── Cart model builder ───────────────────────────────────────────────────────
local function buildCartModel(pos, dir)
	local model = Instance.new("Model")
	model.Name = "RailCart"

	-- Cart body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(BS * 0.9, BS * 0.6, BS * 1.4)
	body.CFrame = CFrame.new(pos) * CFrame.Angles(0, dir == DIR_NS and math.pi/2 or 0, 0)
	body.BrickColor = BrickColor.new("Reddish brown")
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CastShadow = true
	body.Parent = model

	-- Cart floor
	local floor2 = Instance.new("Part")
	floor2.Name = "Floor"
	floor2.Size = Vector3.new(BS * 0.85, BS * 0.08, BS * 1.3)
	floor2.CFrame = CFrame.new(pos + Vector3.new(0, BS * 0.27, 0)) * CFrame.Angles(0, dir == DIR_NS and math.pi/2 or 0, 0)
	floor2.BrickColor = BrickColor.new("Dark orange")
	floor2.Material = Enum.Material.SmoothPlastic
	floor2.Anchored = true
	floor2.CastShadow = false
	floor2.Parent = model

	-- Wheels (4 total)
	local wheelPositions
	if dir == DIR_EW then
		wheelPositions = {
			Vector3.new(-BS*0.35, -BS*0.2, -BS*0.5),
			Vector3.new( BS*0.35, -BS*0.2, -BS*0.5),
			Vector3.new(-BS*0.35, -BS*0.2,  BS*0.5),
			Vector3.new( BS*0.35, -BS*0.2,  BS*0.5),
		}
	else
		wheelPositions = {
			Vector3.new(-BS*0.5, -BS*0.2, -BS*0.35),
			Vector3.new(-BS*0.5, -BS*0.2,  BS*0.35),
			Vector3.new( BS*0.5, -BS*0.2, -BS*0.35),
			Vector3.new( BS*0.5, -BS*0.2,  BS*0.35),
		}
	end

	for i, wPos in ipairs(wheelPositions) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel" .. i
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(BS * 0.12, BS * 0.32, BS * 0.32)
		wheel.CFrame = CFrame.new(pos + wPos) * CFrame.Angles(0, 0, math.pi/2)
		wheel.BrickColor = BrickColor.new("Dark grey")
		wheel.Material = Enum.Material.Metal
		wheel.Anchored = true
		wheel.CastShadow = false
		wheel.Parent = model
	end

	-- Axles
	for _, side in ipairs({-1, 1}) do
		local axleZ = side * BS * 0.5
		local axle = Instance.new("Part")
		axle.Name = "Axle"
		if dir == DIR_EW then
			axle.Size = Vector3.new(BS * 0.06, BS * 0.06, BS * 0.8)
			axle.CFrame = CFrame.new(pos + Vector3.new(0, -BS*0.2, axleZ))
		else
			axle.Size = Vector3.new(BS * 0.8, BS * 0.06, BS * 0.06)
			axle.CFrame = CFrame.new(pos + Vector3.new(axleZ, -BS*0.2, 0))
		end
		axle.BrickColor = BrickColor.new("Mid gray")
		axle.Material = Enum.Material.Metal
		axle.Anchored = true
		axle.CastShadow = false
		axle.Parent = model
	end

	-- Chest/storage indicator
	local chestIndicator = Instance.new("Part")
	chestIndicator.Name = "Storage"
	chestIndicator.Size = Vector3.new(BS * 0.35, BS * 0.25, BS * 0.5)
	chestIndicator.CFrame = CFrame.new(pos + Vector3.new(0, BS * 0.43, 0)) * CFrame.Angles(0, dir == DIR_NS and math.pi/2 or 0, 0)
	chestIndicator.BrickColor = BrickColor.new("Bright orange")
	chestIndicator.Material = Enum.Material.SmoothPlastic
	chestIndicator.Anchored = true
	chestIndicator.CastShadow = false
	chestIndicator.Parent = model

	-- Glow when fueled
	local fuelLight = Instance.new("PointLight")
	fuelLight.Name = "FuelLight"
	fuelLight.Color = Color3.fromRGB(255, 160, 30)
	fuelLight.Brightness = 0
	fuelLight.Range = 8
	fuelLight.Parent = body

	model.PrimaryPart = body
	model.Parent = Workspace
	return model
end

-- ─── Find nearby rail carts ───────────────────────────────────────────────────
local function findNearbyCart()
	local char = player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name == "RailCart" then
			local body = obj:FindFirstChild("Body")
			if body then
				local dist = (hrp.Position - body.Position).Magnitude
				if dist <= MOUNT_RADIUS then
					return obj, body
				end
			end
		end
	end
	return nil
end

-- ─── Check if position is on a rail ──────────────────────────────────────────
local function getRailAtPos(wx, wy, wz)
	if not _G.VCGetBlock then return nil end
	-- Check current block and one below
	local bv = _G.VCGetBlock(wx, wy, wz)
	if RAIL_BLOCKS[bv] then return bv, wy end
	bv = _G.VCGetBlock(wx, wy - 1, wz)
	if RAIL_BLOCKS[bv] then return bv, wy - 1 end
	return nil
end

local function worldToBlock(pos)
	return
		math.floor(pos.X / BS),
		math.floor(pos.Y / BS),
		math.floor(pos.Z / BS)
end

local function blockCenter(bx, by, bz)
	return Vector3.new(bx * BS + BS/2, by * BS + BS + 0.5, bz * BS + BS/2)
end

-- ─── Mount / dismount ─────────────────────────────────────────────────────────
local function mountCart(cartModel)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	local body = cartModel:FindFirstChild("Body")
	if not body then return end

	cartState.mounted = true
	cartState.cartModel = cartModel
	cartState.cartPart = body
	cartState.position = body.Position
	cartState.velocity = 0
	cartState.throttle = 0

	-- Detect initial direction from nearest rail
	local bx, by, bz = worldToBlock(body.Position)
	local railBv = _G.VCGetBlock and _G.VCGetBlock(bx, by - 1, bz)
	if railBv == B.RAIL_IRON then
		cartState.direction = DIR_NS
	else
		cartState.direction = DIR_EW
	end

	-- Disable character control
	hum.WalkSpeed = 0
	hum.JumpPower = 0

	-- Show HUD
	trainGui.Enabled = true

	-- Sit character in cart
	hrp.CFrame = CFrame.new(body.Position + Vector3.new(0, BS * 0.5, 0))

	print("Mounted rail cart")
end

local function dismountCart()
	if not cartState.mounted then return end
	local char = player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
		if hrp and cartState.cartPart then
			-- Place player beside cart
			local offset = cartState.direction == DIR_EW and Vector3.new(0, BS, BS * 1.5) or Vector3.new(BS * 1.5, BS, 0)
			hrp.CFrame = CFrame.new(cartState.cartPart.Position + offset)
		end
	end

	cartState.mounted = false
	cartState.velocity = 0
	cartState.throttle = 0

	trainGui.Enabled = false
	print("Dismounted rail cart")
end

-- ─── Add fuel to cart ─────────────────────────────────────────────────────────
local function addFuel(amount)
	cartState.fuel = math.clamp(cartState.fuel + amount, 0, 100)
end

_G.VCAddCartFuel = addFuel

-- ─── Find next rail position along direction ──────────────────────────────────
local function getNextRailPos(pos, dir, forward)
	local stepSign = forward and 1 or -1
	local bx, by, bz = worldToBlock(pos)

	-- Step along direction
	local nx, nz
	if dir == DIR_EW then
		nx = bx + stepSign
		nz = bz
	else
		nx = bx
		nz = bz + stepSign
	end

	-- Check several Y levels for sloped rails
	for dy = -1, 1 do
		local ny = by + dy
		local rv = _G.VCGetBlock and _G.VCGetBlock(nx, ny, nz)
		if rv and RAIL_BLOCKS[rv] then
			return blockCenter(nx, ny, nz), rv
		end
	end

	return nil, nil
end

-- ─── Input handling ───────────────────────────────────────────────────────────
local keysDown = {}

UserInputService.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	keysDown[inp.KeyCode] = true

	-- Mount nearby cart with F key
	if inp.KeyCode == Enum.KeyCode.F and not cartState.mounted then
		local cart, body = findNearbyCart()
		if cart then
			mountCart(cart)
		end
	end

	-- Dismount with Q
	if inp.KeyCode == Enum.KeyCode.Q and cartState.mounted then
		dismountCart()
	end

	-- Refuel with R (uses coal from inventory)
	if inp.KeyCode == Enum.KeyCode.R and cartState.mounted then
		local ps = _G.PlayerState
		if ps and ps.hotbar then
			-- Find coal in hotbar
			local sel = ps.sel or 1
			local slot = ps.hotbar[sel]
			if slot and slot.id then
				local BT2 = BT
				-- Check if item is coal (fuel item)
				local fuelItems = {
					[B.COAL_I]  = 20,  -- coal item
					[B.OLOG]    = 8,   -- oak log
					[B.SLOG]    = 8,   -- spruce log
					[B.BLOG]    = 8,   -- birch log
					[B.DLOG]    = 8,   -- dark log
					[B.PLNK]    = 4,   -- planks
				}
				if fuelItems[slot.id] then
					addFuel(fuelItems[slot.id])
					slot.count = slot.count - 1
					if slot.count <= 0 then ps.hotbar[sel] = nil end
					if _G.VCUpdateHUD then _G.VCUpdateHUD() end
				end
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	keysDown[inp.KeyCode] = false
end)

-- ─── Cart physics update ──────────────────────────────────────────────────────
local cartUpdateConn

cartUpdateConn = RunService.RenderStepped:Connect(function(dt)
	if not cartState.mounted then return end
	if not cartState.cartModel or not cartState.cartPart then
		dismountCart()
		return
	end

	-- Read throttle input
	local thr = 0
	if keysDown[Enum.KeyCode.W] then thr = 1
	elseif keysDown[Enum.KeyCode.S] then thr = -1 end
	cartState.throttle = thr

	-- Update fuel
	if math.abs(thr) > 0.1 and cartState.fuel > 0 then
		cartState.fuel = math.max(0, cartState.fuel - CART_FUEL_USE * dt)
	else
		cartState.fuel = math.max(0, cartState.fuel - CART_FUEL_IDLE * dt)
	end

	-- No fuel = no throttle
	if cartState.fuel <= 0 then thr = 0 end

	-- Apply throttle to velocity
	if thr > 0 then
		cartState.velocity = math.min(CART_SPEED_MAX, cartState.velocity + CART_ACCEL * dt * thr)
	elseif thr < 0 then
		if cartState.velocity > 0 then
			-- Braking forward
			cartState.velocity = math.max(0, cartState.velocity - CART_BRAKE * dt)
		else
			-- Reverse
			cartState.velocity = math.max(-CART_SPEED_MAX * 0.5, cartState.velocity - CART_ACCEL * dt * 0.5)
		end
	else
		-- Friction coast
		local friction = 2.0
		if cartState.velocity > 0 then
			cartState.velocity = math.max(0, cartState.velocity - friction * dt)
		elseif cartState.velocity < 0 then
			cartState.velocity = math.min(0, cartState.velocity + friction * dt)
		end
	end

	-- Move cart along rail
	if math.abs(cartState.velocity) > 0.01 then
		local forward = cartState.velocity > 0
		local delta = math.abs(cartState.velocity) * dt

		-- Try to find next rail position
		local nextPos, nextRail = getNextRailPos(cartState.position, cartState.direction, forward)
		if nextPos then
			-- Move toward next rail block center
			local toNext = (nextPos - cartState.position)
			local distToNext = toNext.Magnitude
			if distToNext < delta + 0.5 then
				-- Arrive at next block, snap and advance
				cartState.position = nextPos
				if nextRail then cartState.railType = nextRail end
				-- Switch direction based on rail type at new position
				if nextRail == B.RAIL_IRON then
					cartState.direction = DIR_NS
				elseif nextRail == B.RAIL_BLK or nextRail == B.RAIL_POWERED then
					cartState.direction = DIR_EW
				end
			else
				-- Slide toward next
				local moveDir = toNext.Unit
				cartState.position = cartState.position + moveDir * delta
			end
		else
			-- No rail ahead — stop
			cartState.velocity = 0
		end

		-- Apply gravity slope effect (check Y difference)
		if nextPos then
			local yDiff = nextPos.Y - cartState.position.Y
			if yDiff < -0.1 and forward then
				-- Downhill boost
				cartState.velocity = math.min(CART_SPEED_MAX, cartState.velocity + CART_GRAVITY * dt * 10)
			elseif yDiff > 0.1 and forward then
				-- Uphill slow
				cartState.velocity = math.max(0, cartState.velocity - CART_GRAVITY * dt * 5)
			end
		end
	end

	-- Update cart model position
	local newCF = CFrame.new(cartState.position)
	if cartState.direction == DIR_NS then
		newCF = newCF * CFrame.Angles(0, math.pi/2, 0)
	end

	-- Move all parts of cart model
	for _, part in ipairs(cartState.cartModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local relCF = cartState.cartPart.CFrame:Inverse() * part.CFrame
			part.CFrame = newCF * relCF
		end
	end
	-- Actually just set primary part (simpler)
	cartState.cartPart.CFrame = newCF

	-- Seat player on cart
	local char = player.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(cartState.position + Vector3.new(0, BS * 0.6, 0))
		end
	end

	-- Rotate wheels (visual)
	local wheelSpin = cartState.velocity * dt * 3
	for _, part in ipairs(cartState.cartModel:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:sub(1, 5) == "Wheel" then
			part.CFrame = part.CFrame * CFrame.Angles(wheelSpin, 0, 0)
		end
	end

	-- Fuel light glow
	local fuelLight = cartState.cartPart:FindFirstChild("FuelLight")
	if fuelLight then
		fuelLight.Brightness = (cartState.fuel / 100) * 1.5 * (math.abs(cartState.velocity) / CART_SPEED_MAX + 0.3)
	end

	-- Update HUD
	local speedKmh = math.abs(cartState.velocity) * 3.6  -- convert studs/s to km/h (approx)
	speedLabel.Text = string.format("%d km/h", math.floor(speedKmh))

	local fuelFrac = cartState.fuel / 100
	fuelBar.Size = UDim2.new(fuelFrac, 0, 1, 0)
	fuelLabel.Text = string.format("Fuel: %d%%", math.floor(cartState.fuel))

	-- Color fuel bar by level
	if fuelFrac > 0.5 then
		fuelBar.BackgroundColor3 = Color3.fromRGB(220, 160, 30)
	elseif fuelFrac > 0.2 then
		fuelBar.BackgroundColor3 = Color3.fromRGB(220, 100, 20)
	else
		fuelBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		-- Flash when low
		local t = tick() * 4
		fuelBg.BackgroundTransparency = math.abs(math.sin(t)) * 0.5
	end

	-- Throttle arrow indicators
	arrowFwd.TextTransparency = (thr > 0) and 0 or 0.7
	arrowBck.TextTransparency = (thr < 0) and 0 or 0.7
	if cartState.velocity == 0 and thr == 0 then
		speedLabel.TextColor3 = Color3.fromRGB(150, 180, 200)
	else
		speedLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
	end
end)

-- ─── Spawn carts on rail blocks (at server-loaded stations) ──────────────────
-- Carts are spawned when the renderer loads chunks with RAIL blocks
-- Listen for VCCartSpawn global event
_G.VCSpawnCart = function(wx, wy, wz, dirStr)
	local pos = Vector3.new(wx * BS + BS/2, wy * BS + BS + 1, wz * BS + BS/2)
	local dir = (dirStr == "NS") and DIR_NS or DIR_EW
	local cart = buildCartModel(pos, dir)
	print("Spawned rail cart at", wx, wy, wz)
	return cart
end

-- ─── Auto-detect carts at stations ───────────────────────────────────────────
-- When player enters a chunk with a station, check for cart spawn points
RunService.Heartbeat:Connect(function()
	-- Check every 2 seconds if player is near a station rail
	-- (full implementation would query WorldGen station positions)
	-- For now, spawn carts at known rail intersections based on C constants
	-- This is handled by the world gen side; client just renders them
end)

-- ─── Global cart creation for other scripts ──────────────────────────────────
_G.VCBuildCartModel = buildCartModel
_G.VCDismountCart   = dismountCart
_G.VCIsMounted      = function() return cartState.mounted end
_G.VCGetCartSpeed   = function() return cartState.velocity end

-- ─── Cleanup on character removal ─────────────────────────────────────────────
player.CharacterRemoving:Connect(function()
	if cartState.mounted then
		dismountCart()
	end
end)

print("VC CRAFT Train System initialized")
