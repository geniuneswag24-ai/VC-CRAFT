-- VC CRAFT Inventory UI Client
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local C = require(Shared.Constants)
local BT = require(Shared.BlockTypes)
local WorldUtils = require(Shared.WorldUtils)
local Recipes = require(Shared.Recipes)

local B = BT.B
local BD = BT.BD
local BC = BT.BC

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RE = {}
for _, name in pairs(WorldUtils.RE) do
	RE[name] = ReplicatedStorage:WaitForChild(name, 10)
end

-- ─── State ────────────────────────────────────────────────────────────────────
local invOpen = false
local craftingSize = 2  -- 2x2 default, 3x3 with crafting table
local craftingGrid = {}  -- [row][col] = {id, count} or nil
for r = 1, 3 do craftingGrid[r] = {} end

local dragItem = nil   -- {id, count, srcType, srcIdx}
local chestData = nil  -- current open chest
local chestPos = nil

local function getPS() return _G.PlayerState end

-- ─── Screen setup ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VCInventory"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 340, 0, 400)
panel.BackgroundColor3 = Color3.fromRGB(198, 198, 198)
panel.BorderSizePixel = 3
panel.BorderColor3 = Color3.fromRGB(26, 26, 26)
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 14)
title.BackgroundTransparency = 1
title.Text = "Inventory"
title.TextColor3 = Color3.fromRGB(64, 64, 64)
title.TextSize = 9
title.Font = Enum.Font.Arcade
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 8, 0, 6)
title.Parent = panel

-- ─── Slot helper ─────────────────────────────────────────────────────────────
local function makeSlot(parent, x, y, size)
	size = size or 34
	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, x, 0, y)
	frame.Size = UDim2.new(0, size, 0, size)
	frame.BackgroundColor3 = Color3.fromRGB(139, 139, 139)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(55, 55, 55)  -- inset border (dark top/left)
	frame.Parent = parent

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.45, 0)
	icon.Size = UDim2.new(0, 22, 0, 22)
	icon.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	icon.BorderSizePixel = 0
	icon.Parent = frame

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(1, -2, 0, 8)
	countLabel.Position = UDim2.new(0, 0, 1, -10)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = ""
	countLabel.TextColor3 = Color3.new(1, 1, 1)
	countLabel.TextSize = 7
	countLabel.Font = Enum.Font.Arcade
	countLabel.TextStrokeTransparency = 0
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = frame

	return frame
end

local function updateSlotDisplay(slotFrame, item)
	local icon = slotFrame:FindFirstChild("Icon")
	local countLabel = slotFrame:FindFirstChild("Count")
	if item and item.id and item.id ~= B.AIR then
		local colors = BC[item.id]
		if icon then icon.BackgroundColor3 = colors and colors[1] or Color3.new(0.5, 0.5, 0.5) end
		if countLabel then countLabel.Text = item.count > 1 and tostring(item.count) or "" end
	else
		if icon then icon.BackgroundColor3 = Color3.fromRGB(100, 100, 100) end
		if countLabel then countLabel.Text = "" end
	end
end

-- ─── Crafting area ────────────────────────────────────────────────────────────
local craftArea = Instance.new("Frame")
craftArea.Name = "CraftArea"
craftArea.Position = UDim2.new(0, 8, 0, 22)
craftArea.Size = UDim2.new(1, -16, 0, 80)
craftArea.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
craftArea.BorderSizePixel = 0
craftArea.Parent = panel

local craftTitle = Instance.new("TextLabel")
craftTitle.Size = UDim2.new(1, 0, 0, 10)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "Crafting"
craftTitle.TextColor3 = Color3.fromRGB(64, 64, 64)
craftTitle.TextSize = 7
craftTitle.Font = Enum.Font.Arcade
craftTitle.TextXAlignment = Enum.TextXAlignment.Left
craftTitle.Position = UDim2.new(0, 4, 0, 2)
craftTitle.Parent = craftArea

local craftSlots = {}
for r = 1, 2 do
	craftSlots[r] = {}
	for c = 1, 2 do
		local slot = makeSlot(craftArea, 4 + (c-1)*36, 12 + (r-1)*36, 34)
		local row, col = r, c
		slot.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				handleSlotClick("craft", {row=row, col=col}, slot)
			end
		end)
		craftSlots[r][c] = slot
	end
end

local arrowLabel = Instance.new("TextLabel")
arrowLabel.Position = UDim2.new(0, 80, 0, 28)
arrowLabel.Size = UDim2.new(0, 30, 0, 30)
arrowLabel.BackgroundTransparency = 1
arrowLabel.Text = "→"
arrowLabel.TextColor3 = Color3.fromRGB(85, 85, 85)
arrowLabel.TextSize = 20
arrowLabel.Font = Enum.Font.Arcade
arrowLabel.Parent = craftArea

local craftOutputSlot = makeSlot(craftArea, 112, 24, 34)
craftOutputSlot.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleSlotClick("craft_output", {}, craftOutputSlot)
	end
end)

-- ─── Main inventory ───────────────────────────────────────────────────────────
local invTitle = Instance.new("TextLabel")
invTitle.Position = UDim2.new(0, 8, 0, 106)
invTitle.Size = UDim2.new(1, -16, 0, 12)
invTitle.BackgroundTransparency = 1
invTitle.Text = "Inventory"
invTitle.TextColor3 = Color3.fromRGB(64, 64, 64)
invTitle.TextSize = 7
invTitle.Font = Enum.Font.Arcade
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.Parent = panel

local invSlots = {}
for i = 1, 27 do
	local row = math.ceil(i / 9) - 1
	local col = (i - 1) % 9
	local slot = makeSlot(panel, 8 + col*36, 118 + row*36, 34)
	local idx = i
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleSlotClick("inv", idx, slot)
		end
	end)
	invSlots[i] = slot
end

-- Hotbar row in inventory
local hbTitle = Instance.new("TextLabel")
hbTitle.Position = UDim2.new(0, 8, 0, 228)
hbTitle.Size = UDim2.new(1, -16, 0, 10)
hbTitle.BackgroundTransparency = 1
hbTitle.Text = "Hotbar"
hbTitle.TextColor3 = Color3.fromRGB(64, 64, 64)
hbTitle.TextSize = 7
hbTitle.Font = Enum.Font.Arcade
hbTitle.TextXAlignment = Enum.TextXAlignment.Left
hbTitle.Parent = panel

local hbSlots = {}
for i = 1, 9 do
	local slot = makeSlot(panel, 8 + (i-1)*36, 240, 34)
	local idx = i
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleSlotClick("hb", idx, slot)
		end
	end)
	hbSlots[i] = slot
end

-- ─── Drag item display ────────────────────────────────────────────────────────
local dragFrame = Instance.new("Frame")
dragFrame.Name = "DragItem"
dragFrame.Size = UDim2.new(0, 28, 0, 28)
dragFrame.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
dragFrame.BorderSizePixel = 0
dragFrame.Visible = false
dragFrame.ZIndex = 200
dragFrame.Parent = screenGui

local dragCount = Instance.new("TextLabel")
dragCount.Size = UDim2.new(1, 0, 0.5, 0)
dragCount.Position = UDim2.new(0, 0, 0.5, 0)
dragCount.BackgroundTransparency = 1
dragCount.Text = ""
dragCount.TextColor3 = Color3.new(1,1,1)
dragCount.TextSize = 7
dragCount.Font = Enum.Font.Arcade
dragCount.TextStrokeTransparency = 0
dragCount.TextXAlignment = Enum.TextXAlignment.Right
dragCount.ZIndex = 201
dragCount.Parent = dragFrame

-- ─── Slot click handler ───────────────────────────────────────────────────────
function handleSlotClick(slotType, slotInfo, slotFrame)
	local ps = getPS()
	if not ps then return end

	local function getItem()
		if slotType == "inv" then return ps.inventory[slotInfo]
		elseif slotType == "hb" then return ps.hotbar[slotInfo]
		elseif slotType == "craft" then return craftingGrid[slotInfo.row][slotInfo.col]
		elseif slotType == "craft_output" then
			-- Collect crafting output
			local grid = {}
			for r = 1, craftingSize do
				grid[r] = {}
				for c = 1, craftingSize do
					local item = craftingGrid[r][c]
					grid[r][c] = item and item.id or 0
				end
			end
			local result = Recipes.check(grid, craftingSize)
			if result then return {id=result.id, count=result.count} end
			return nil
		elseif slotType == "chest" then return chestData and chestData[slotInfo]
		end
	end

	local function setItem(item)
		if slotType == "inv" then ps.inventory[slotInfo] = item
		elseif slotType == "hb" then ps.hotbar[slotInfo] = item
		elseif slotType == "craft" then craftingGrid[slotInfo.row][slotInfo.col] = item
		elseif slotType == "craft_output" then
			if item ~= nil then return end -- can't place into output
			-- Consume crafting inputs
			for r = 1, craftingSize do
				for c = 1, craftingSize do
					local ci = craftingGrid[r][c]
					if ci then
						ci.count = ci.count - 1
						if ci.count <= 0 then craftingGrid[r][c] = nil end
					end
				end
			end
		elseif slotType == "chest" then
			if chestData then
				chestData[slotInfo] = item
				-- Sync to server
				if chestPos then
					RE[WorldUtils.RE.CHEST_UPDATE]:FireServer(chestPos.x, chestPos.y, chestPos.z, chestData)
				end
			end
		end
	end

	if dragItem then
		-- Place dragged item
		local current = getItem()
		if slotType == "craft_output" then
			-- Collect crafted item
			if current and _G.VCAddItem then
				_G.VCAddItem(current.id, current.count)
				-- Consume crafting inputs
				for r = 1, craftingSize do
					for c = 1, craftingSize do
						local ci = craftingGrid[r][c]
						if ci then
							ci.count = ci.count - 1
							if ci.count <= 0 then craftingGrid[r][c] = nil end
						end
					end
				end
				dragItem = nil
				dragFrame.Visible = false
			end
		else
			if current and current.id == dragItem.id then
				-- Stack
				local bd = BD[dragItem.id]
				local maxStack = (bd and bd.stackSize) or 64
				local canAdd = math.min(dragItem.count, maxStack - current.count)
				current.count = current.count + canAdd
				dragItem.count = dragItem.count - canAdd
				if dragItem.count <= 0 then dragItem = nil; dragFrame.Visible = false end
			else
				-- Swap
				local tmp = current
				setItem(dragItem)
				dragItem = tmp
				if dragItem then
					local colors = BC[dragItem.id]
					dragFrame.BackgroundColor3 = colors and colors[1] or Color3.new(0.5, 0.5, 0.5)
					dragCount.Text = dragItem.count > 1 and tostring(dragItem.count) or ""
				else
					dragFrame.Visible = false
				end
			end
		end
	else
		-- Pick up item
		local item = getItem()
		if item and item.id then
			dragItem = {id=item.id, count=item.count, srcType=slotType, srcIdx=slotInfo}
			setItem(nil)
			local colors = BC[item.id]
			dragFrame.BackgroundColor3 = colors and colors[1] or Color3.new(0.5, 0.5, 0.5)
			dragCount.Text = item.count > 1 and tostring(item.count) or ""
			dragFrame.Visible = true
		end
	end

	refreshInventoryDisplay()
end

-- ─── Refresh display ──────────────────────────────────────────────────────────
function refreshInventoryDisplay()
	local ps = getPS()
	if not ps then return end

	-- Inventory slots
	for i = 1, 27 do
		updateSlotDisplay(invSlots[i], ps.inventory[i])
	end
	-- Hotbar slots
	for i = 1, 9 do
		updateSlotDisplay(hbSlots[i], ps.hotbar[i])
	end
	-- Crafting grid
	for r = 1, craftingSize do
		if craftSlots[r] then
			for c = 1, craftingSize do
				if craftSlots[r][c] then
					updateSlotDisplay(craftSlots[r][c], craftingGrid[r][c])
				end
			end
		end
	end
	-- Crafting output
	local grid = {}
	for r = 1, craftingSize do
		grid[r] = {}
		for c = 1, craftingSize do
			local item = craftingGrid[r][c]
			grid[r][c] = item and item.id or 0
		end
	end
	local result = Recipes.check(grid, craftingSize)
	updateSlotDisplay(craftOutputSlot, result and {id=result.id, count=result.count} or nil)
end

-- ─── Open/close ───────────────────────────────────────────────────────────────
local function openInventory()
	if invOpen then return end
	invOpen = true
	screenGui.Enabled = true
	_G.VCInventoryOpen = true
	-- Release mouse
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	refreshInventoryDisplay()
end
_G.VCOpenInventory = openInventory

local function closeInventory()
	if not invOpen then return end
	invOpen = false
	screenGui.Enabled = false
	_G.VCInventoryOpen = false
	-- Return dragged item to inventory
	if dragItem then
		if _G.VCAddItem then _G.VCAddItem(dragItem.id, dragItem.count) end
		dragItem = nil
		dragFrame.Visible = false
	end
	-- Return crafting items
	for r = 1, 3 do
		for c = 1, 3 do
			local item = craftingGrid[r][c]
			if item and _G.VCAddItem then
				_G.VCAddItem(item.id, item.count)
				craftingGrid[r][c] = nil
			end
		end
	end
	-- Re-lock mouse for gameplay
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

-- ─── Chest UI ─────────────────────────────────────────────────────────────────
local chestGui = Instance.new("ScreenGui")
chestGui.Name = "VCChest"
chestGui.ResetOnSpawn = false
chestGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
chestGui.Enabled = false
chestGui.Parent = playerGui

local chestPanel = Instance.new("Frame")
chestPanel.AnchorPoint = Vector2.new(0.5, 0.5)
chestPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
chestPanel.Size = UDim2.new(0, 340, 0, 380)
chestPanel.BackgroundColor3 = Color3.fromRGB(198, 198, 198)
chestPanel.BorderSizePixel = 3
chestPanel.BorderColor3 = Color3.fromRGB(26, 26, 26)
chestPanel.Parent = chestGui

local chestTitle2 = Instance.new("TextLabel")
chestTitle2.Size = UDim2.new(1, 0, 0, 12)
chestTitle2.Position = UDim2.new(0, 8, 0, 4)
chestTitle2.BackgroundTransparency = 1
chestTitle2.Text = "Chest"
chestTitle2.TextColor3 = Color3.fromRGB(64, 64, 64)
chestTitle2.TextSize = 8
chestTitle2.Font = Enum.Font.Arcade
chestTitle2.TextXAlignment = Enum.TextXAlignment.Left
chestTitle2.Parent = chestPanel

local chestSlots = {}
for i = 1, 27 do
	local row = math.ceil(i / 9) - 1
	local col = (i - 1) % 9
	local slot = makeSlot(chestPanel, 8 + col*36, 20 + row*36, 34)
	slot.Parent = chestPanel
	local idx = i
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleSlotClick("chest", idx, slot)
		end
	end)
	chestSlots[i] = slot
end

local chestInvTitle = Instance.new("TextLabel")
chestInvTitle.Position = UDim2.new(0, 8, 0, 136)
chestInvTitle.Size = UDim2.new(1, -16, 0, 10)
chestInvTitle.BackgroundTransparency = 1
chestInvTitle.Text = "Inventory"
chestInvTitle.TextColor3 = Color3.fromRGB(64, 64, 64)
chestInvTitle.TextSize = 7
chestInvTitle.Font = Enum.Font.Arcade
chestInvTitle.TextXAlignment = Enum.TextXAlignment.Left
chestInvTitle.Parent = chestPanel

local chestInvSlots = {}
for i = 1, 27 do
	local row = math.ceil(i / 9) - 1
	local col = (i - 1) % 9
	local slot = makeSlot(chestPanel, 8 + col*36, 148 + row*36, 34)
	local idx = i
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleSlotClick("inv", idx, slot)
		end
	end)
	chestInvSlots[i] = slot
end

local chestHBTitle = Instance.new("TextLabel")
chestHBTitle.Position = UDim2.new(0, 8, 0, 260)
chestHBTitle.Size = UDim2.new(1, -16, 0, 10)
chestHBTitle.BackgroundTransparency = 1
chestHBTitle.Text = "Hotbar"
chestHBTitle.TextColor3 = Color3.fromRGB(64, 64, 64)
chestHBTitle.TextSize = 7
chestHBTitle.Font = Enum.Font.Arcade
chestHBTitle.TextXAlignment = Enum.TextXAlignment.Left
chestHBTitle.Parent = chestPanel

local chestHBSlots = {}
for i = 1, 9 do
	local slot = makeSlot(chestPanel, 8 + (i-1)*36, 272, 34)
	local idx = i
	slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			handleSlotClick("hb", idx, slot)
		end
	end)
	chestHBSlots[i] = slot
end

local function openChest(wx, wy, wz, data)
	chestData = data or {}
	chestPos = {x=wx, y=wy, z=wz}
	chestGui.Enabled = true
	_G.VCInventoryOpen = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	-- Refresh display
	local ps = getPS()
	for i = 1, 27 do
		updateSlotDisplay(chestSlots[i], chestData[i])
		if ps then
			updateSlotDisplay(chestInvSlots[i], ps.inventory[i])
		end
	end
	if ps then
		for i = 1, 9 do
			updateSlotDisplay(chestHBSlots[i], ps.hotbar[i])
		end
	end
end

local function closeChest()
	chestGui.Enabled = false
	_G.VCInventoryOpen = false
	if dragItem and _G.VCAddItem then
		_G.VCAddItem(dragItem.id, dragItem.count)
		dragItem = nil
		dragFrame.Visible = false
	end
	chestData = nil
	chestPos = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

-- Chest data from server
RE[WorldUtils.RE.CHEST_DATA].OnClientEvent:Connect(function(wx, wy, wz, data)
	openChest(wx, wy, wz, data)
end)

-- ─── Input ────────────────────────────────────────────────────────────────────
-- InventoryUI owns ALL E-key logic (open AND close) to avoid race conditions
-- with PlayerController's InputBegan handler.
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		if invOpen then
			closeInventory()
		elseif chestGui.Enabled then
			closeChest()
		elseif _G.VCGameRunning then
			-- Only open once the game is actually running
			openInventory()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if invOpen then closeInventory()
		elseif chestGui.Enabled then closeChest()
		end
	end
end)

-- Drag item follows mouse
RunService.RenderStepped:Connect(function()
	if dragItem then
		local mousePos = UserInputService:GetMouseLocation()
		dragFrame.Position = UDim2.new(0, mousePos.X - 14, 0, mousePos.Y - 14)
		dragFrame.Visible = true
	else
		dragFrame.Visible = false
	end
end)

print("VC CRAFT Inventory UI initialized")
