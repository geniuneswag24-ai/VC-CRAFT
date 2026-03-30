-- VC CRAFT Main Menu Client
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- ─── Splash texts ─────────────────────────────────────────────────────────────
local SPLASHES = {
	"Now with 146 blocks!", "Garfbot is real.", "VCLANTIS awaits...",
	"Mine. Craft. Survive.", "Not affiliated with Garfield.", "100% blocky",
	"Gomp Tower: Floor 99", "Watch out for VCKnights!", "Try punching a tree.",
	"GarfbotBoss has 3 phases!", "Dig straight down.", "Pirate ships on oceans.",
}

-- ─── Root GUI ─────────────────────────────────────────────────────────────────
local menuGui = Instance.new("ScreenGui")
menuGui.Name          = "VCCraftMainMenu"
menuGui.ResetOnSpawn  = false
menuGui.IgnoreGuiInset = true
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.Parent        = playerGui

-- Background
local bg = Instance.new("Frame")
bg.Size                 = UDim2.new(1,0,1,0)
bg.BackgroundColor3     = Color3.fromRGB(18, 28, 48)
bg.BorderSizePixel      = 0
bg.Parent               = menuGui

-- ─── Title ────────────────────────────────────────────────────────────────────
local titleLbl = Instance.new("TextLabel")
titleLbl.Size               = UDim2.new(0, 500, 0, 100)
titleLbl.Position           = UDim2.new(0.5, -250, 0, 60)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "VC CRAFT"
titleLbl.TextColor3         = Color3.fromRGB(255, 215, 50)
titleLbl.TextStrokeColor3   = Color3.fromRGB(160, 90, 0)
titleLbl.TextStrokeTransparency = 0
titleLbl.Font               = Enum.Font.GothamBold
titleLbl.TextScaled         = true
titleLbl.Parent             = bg

local splashLbl = Instance.new("TextLabel")
splashLbl.Size              = UDim2.new(0, 340, 0, 26)
splashLbl.Position          = UDim2.new(0.5, 60, 0, 155)
splashLbl.BackgroundTransparency = 1
splashLbl.Text              = SPLASHES[math.random(#SPLASHES)]
splashLbl.TextColor3        = Color3.fromRGB(255, 255, 80)
splashLbl.Font              = Enum.Font.GothamBold
splashLbl.TextSize          = 17
splashLbl.Rotation          = -6
splashLbl.Parent            = bg

-- ─── Button factory ───────────────────────────────────────────────────────────
local function makeBtn(parent, text, y, w, h, r, g, b2)
	w = w or 260; h = h or 46
	r = r or 55; g = g or 78; b2 = b2 or 112
	local btn = Instance.new("TextButton")
	btn.Size            = UDim2.new(0, w, 0, h)
	btn.Position        = UDim2.new(0.5, -w/2, 0, y)
	btn.BackgroundColor3= Color3.fromRGB(r, g, b2)
	btn.BorderSizePixel = 0
	btn.Text            = text
	btn.TextColor3      = Color3.new(1,1,1)
	btn.Font            = Enum.Font.GothamBold
	btn.TextSize        = 19
	btn.AutoButtonColor = true
	btn.Parent          = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,7); c.Parent = btn
	local s = Instance.new("UIStroke"); s.Thickness = 1.5
	s.Color = Color3.fromRGB(r+50, g+50, b2+50); s.Parent = btn
	return btn
end

-- ─── Main panel ───────────────────────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Size                  = UDim2.new(0, 300, 0, 260)
panel.Position              = UDim2.new(0.5, -150, 0.5, -60)
panel.BackgroundTransparency = 1
panel.Parent                = bg

local btnPlay     = makeBtn(panel, "▶  Survival",  10,  260, 54, 40, 120, 60)
local btnCreative = makeBtn(panel, "🎨  Creative",  74,  260, 46, 100, 60, 140)
local btnSettings = makeBtn(panel, "⚙  Settings",  130, 260, 46)
local btnQuit     = makeBtn(panel, "✕  Quit",      186, 130, 40, 120, 45, 45)
btnQuit.Position  = UDim2.new(0.5, -65, 0, 186)

-- ─── Settings panel ───────────────────────────────────────────────────────────
local settPanel = Instance.new("Frame")
settPanel.Size              = UDim2.new(0, 420, 0, 280)
settPanel.Position          = UDim2.new(0.5, -210, 0.5, -140)
settPanel.BackgroundColor3  = Color3.fromRGB(22, 32, 52)
settPanel.BorderSizePixel   = 0
settPanel.Visible           = false
settPanel.Parent            = bg
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0,10); sc.Parent = settPanel
local ss = Instance.new("UIStroke"); ss.Thickness = 2
ss.Color = Color3.fromRGB(80,120,160); ss.Parent = settPanel

local settTitle = Instance.new("TextLabel")
settTitle.Size              = UDim2.new(1, 0, 0, 50)
settTitle.BackgroundTransparency = 1
settTitle.Text              = "Settings"
settTitle.TextColor3        = Color3.fromRGB(210, 220, 255)
settTitle.Font              = Enum.Font.GothamBold
settTitle.TextSize          = 24
settTitle.Parent            = settPanel

-- Render distance row
local rdRow = Instance.new("Frame")
rdRow.Size  = UDim2.new(1,-40,0,40); rdRow.Position = UDim2.new(0,20,0,58)
rdRow.BackgroundTransparency = 1; rdRow.Parent = settPanel

local rdLbl = Instance.new("TextLabel")
rdLbl.Size = UDim2.new(0,240,1,0); rdLbl.BackgroundTransparency = 1
rdLbl.Text = "Render Distance: 6"; rdLbl.TextColor3 = Color3.new(1,1,1)
rdLbl.Font = Enum.Font.Gotham; rdLbl.TextSize = 15
rdLbl.TextXAlignment = Enum.TextXAlignment.Left; rdLbl.Parent = rdRow

local rdMinus = makeBtn(rdRow, "-", 5, 32, 30, 60, 70, 100)
rdMinus.Position = UDim2.new(0, 248, 0, 5)
local rdPlus  = makeBtn(rdRow, "+", 5, 32, 30, 60, 70, 100)
rdPlus.Position  = UDim2.new(0, 288, 0, 5)

local rdValue = 6
rdMinus.MouseButton1Click:Connect(function()
	rdValue = math.max(2, rdValue - 1)
	rdLbl.Text = "Render Distance: " .. rdValue
	if _G.VCSetRenderDist then _G.VCSetRenderDist(rdValue) end
end)
rdPlus.MouseButton1Click:Connect(function()
	rdValue = math.min(12, rdValue + 1)
	rdLbl.Text = "Render Distance: " .. rdValue
	if _G.VCSetRenderDist then _G.VCSetRenderDist(rdValue) end
end)

local btnSettBack = makeBtn(settPanel, "← Back", 220, 130, 40)
btnSettBack.Position = UDim2.new(0.5, -65, 0, 220)

-- ─── Loading screen ───────────────────────────────────────────────────────────
local loadScreen = Instance.new("Frame")
loadScreen.Size             = UDim2.new(1,0,1,0)
loadScreen.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
loadScreen.BorderSizePixel  = 0
loadScreen.ZIndex           = 20
loadScreen.Visible          = false
loadScreen.Parent           = menuGui

local loadTitle = Instance.new("TextLabel")
loadTitle.Size      = UDim2.new(0, 400, 0, 60)
loadTitle.Position  = UDim2.new(0.5, -200, 0.35, 0)
loadTitle.BackgroundTransparency = 1
loadTitle.Text      = "Entering World..."
loadTitle.TextColor3= Color3.fromRGB(220, 195, 90)
loadTitle.Font      = Enum.Font.GothamBold
loadTitle.TextSize  = 30
loadTitle.ZIndex    = 21
loadTitle.Parent    = loadScreen

local barBg = Instance.new("Frame")
barBg.Size          = UDim2.new(0, 480, 0, 18)
barBg.Position      = UDim2.new(0.5, -240, 0.5, 10)
barBg.BackgroundColor3 = Color3.fromRGB(30, 38, 58)
barBg.BorderSizePixel  = 0
barBg.ZIndex        = 21
barBg.Parent        = loadScreen
local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(1,0); bbc.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Size        = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(80, 170, 230)
barFill.BorderSizePixel  = 0
barFill.ZIndex      = 22
barFill.Parent      = barBg
local bfc = Instance.new("UICorner"); bfc.CornerRadius = UDim.new(1,0); bfc.Parent = barFill

local loadStatus = Instance.new("TextLabel")
loadStatus.Size     = UDim2.new(0, 480, 0, 28)
loadStatus.Position = UDim2.new(0.5, -240, 0.5, 36)
loadStatus.BackgroundTransparency = 1
loadStatus.Text     = "Preparing..."
loadStatus.TextColor3 = Color3.fromRGB(170, 185, 200)
loadStatus.Font     = Enum.Font.Gotham
loadStatus.TextSize = 15
loadStatus.ZIndex   = 21
loadStatus.Parent   = loadScreen

-- Expose load progress
_G.VCSetLoadProgress = function(frac, status)
	TweenService:Create(barFill, TweenInfo.new(0.25), {
		Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	}):Play()
	if status then loadStatus.Text = status end
end

-- ─── Navigation helpers ───────────────────────────────────────────────────────
local function showMain()
	panel.Visible    = true
	settPanel.Visible = false
end

local function hideMenu()
	menuGui.Enabled = false
	_G.VCGameRunning = true
	if _G.VCActivateCamera then _G.VCActivateCamera() end
end

-- ─── Play button ─────────────────────────────────────────────────────────────
local function startGame(gameMode)
	panel.Visible      = false
	loadScreen.Visible = true
	_G.VCCurrentWorld  = {gameMode = gameMode}
	-- Enable renderer NOW so chunks start loading during the loading screen.
	-- hideMenu() still runs after VCSpawnReady(), but the renderer needs this
	-- flag set early or VCSpawnReady() will never become true (deadlock).
	_G.VCGameRunning = true

	-- Set mode before game starts
	if gameMode == "creative" then
		if _G.VCCreativeMode then _G.VCCreativeMode() end
	else
		if _G.VCSurvivalMode then _G.VCSurvivalMode() end
	end

	task.spawn(function()
		-- Wait for VoxelRenderer to be ready
		local statusMsgs = {
			[0.0]  = "Connecting to server...",
			[0.15] = "Generating terrain...",
			[0.35] = "Building world...",
			[0.55] = "Loading structures...",
			[0.75] = "Almost ready...",
			[0.90] = "Polishing terrain...",
		}
		local lastMsg = ""
		local deadline = tick() + 90  -- 90s hard cap
		while tick() < deadline do
			task.wait(0.1)
			local prog = (_G.VCSpawnProgress and _G.VCSpawnProgress()) or 0
			-- Pick status message based on progress
			local msg = "Loading world..."
			for threshold, m in pairs(statusMsgs) do
				if prog >= threshold then msg = m end
			end
			_G.VCSetLoadProgress(math.min(0.97, prog * 0.95 + 0.02), msg)
			if _G.VCSpawnReady and _G.VCSpawnReady() then
				break
			end
		end
		_G.VCSetLoadProgress(1.0, "Ready!")
		task.wait(0.4)
		hideMenu()
	end)
end

btnPlay.MouseButton1Click:Connect(function()
	startGame("survival")
end)

btnCreative.MouseButton1Click:Connect(function()
	startGame("creative")
end)

-- ─── Settings button ──────────────────────────────────────────────────────────
btnSettings.MouseButton1Click:Connect(function()
	panel.Visible     = false
	settPanel.Visible = true
end)

btnSettBack.MouseButton1Click:Connect(function()
	showMain()
end)

-- ─── Quit button ─────────────────────────────────────────────────────────────
btnQuit.MouseButton1Click:Connect(function()
	player:Kick("Thanks for playing VC CRAFT!")
end)

-- ─── Animation ────────────────────────────────────────────────────────────────
local t0 = tick()
local splashTimer = 0
local splashIdx   = 1

RunService.RenderStepped:Connect(function(dt)
	local t = tick() - t0

	-- Title bob
	titleLbl.Position = UDim2.new(0.5, -250, 0, 60 + math.sin(t * 1.4) * 5)

	-- Splash wobble
	splashLbl.Rotation = -6 + math.sin(t * 2.2) * 2.5

	-- Cycle splash every 5 seconds
	splashTimer = splashTimer + dt
	if splashTimer >= 5 then
		splashTimer = 0
		splashIdx = (splashIdx % #SPLASHES) + 1
		splashLbl.Text = SPLASHES[splashIdx]
		splashLbl.TextTransparency = 1
		TweenService:Create(splashLbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
	end
end)

-- ─── Auto-hide if another script already started the game ────────────────────
RunService.Heartbeat:Connect(function()
	if _G.VCGameRunning then
		menuGui.Enabled = false
	end
end)

-- Globals
_G.VCShowMenu   = showMain
_G.VCHideMenu   = hideMenu
_G.VCHideLoading = function() loadScreen.Visible = false end

print("VC CRAFT Main Menu initialized")
