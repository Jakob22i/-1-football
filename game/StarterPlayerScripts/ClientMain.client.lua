-- Football Stars on the player's screen. Starts the parts and wires them to
-- the server:
--
--   CardUI          your card in the bottom right (and its +1 pops)
--   UpgradeFX       the big upgrade moment when OVR goes up
--   TrainingClient  what you see and press in every drill
--   MenusUI         the menu buttons and windows, messages, boost chips

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))
local Sounds = require(ReplicatedStorage:WaitForChild("FootballSounds"))

local here = script.Parent
local CardUI = require(here:WaitForChild("CardUI"))
local UpgradeFX = require(here:WaitForChild("UpgradeFX"))
local TrainingClient = require(here:WaitForChild("TrainingClient"))
local MenusUI = require(here:WaitForChild("MenusUI"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local new = FKit.new
local C = FKit.Color

local ctx = { Player = player, Config = Config, Sounds = Sounds }
ctx.Remotes = {
	Train = remotes:WaitForChild("Train"),
	TrainEvent = remotes:WaitForChild("TrainEvent"),
	Progress = remotes:WaitForChild("Progress"),
	Request = remotes:WaitForChild("Request"),
	Notify = remotes:WaitForChild("Notify"),
	OpenMenu = remotes:WaitForChild("OpenMenu"),
}

ctx.Gui = new("ScreenGui", {
	Name = "FootballUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
ctx.Overlay = new("ScreenGui", {
	Name = "FootballFX",
	ResetOnSpawn = false,
	DisplayOrder = 20,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player.PlayerGui,
})

function ctx.Now()
	return workspace:GetServerTimeNow()
end

function ctx.Sound(name, volume, pitch)
	Sounds.Play(name, volume, pitch)
end

-- The player's stats as the server last sent them.
function ctx.Stats()
	local stats = {}
	for _, stat in ipairs(Config.StatOrder) do stats[stat] = player:GetAttribute(stat) or Config.StartLevel end
	return stats
end

function ctx.Request(action, ...)
	local ok, a, b, c = pcall(function(...) return ctx.Remotes.Request:InvokeServer(...) end, action, ...)
	if not ok then return false, "Could not reach the server." end
	return a, b, c
end

--------------------------------------------------------------------------------
-- Messages: coloured lettering with an icon, no box behind
--------------------------------------------------------------------------------

local toastHolder = new("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 64),
	Size = UDim2.fromOffset(700, 200),
	BackgroundTransparency = 1,
	Parent = ctx.Gui,
})
new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder })
local toastOrder = 0
local KIND = {
	error = { C.Red, "\u{26D4}", "Error" },
	unlock = { C.Gold, "\u{1F513}", "Chime" },
	gold = { C.Gold, "\u{2B50}", "Ding" },
	streak = { C.Orange, "\u{1F525}", "Fire" },
	legend = { Color3.fromRGB(255, 220, 60), "\u{1F451}", "Legend" },
	info = { Color3.fromRGB(140, 220, 255), "\u{26BD}", "Pop" },
	good = { C.Green, "\u{2705}", "Ding" },
}

function ctx.Toast(text, kind)
	local style = KIND[kind or "info"] or KIND.info
	toastOrder += 1
	local items = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("TextLabel") then table.insert(items, child) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 1, #items - 2 do items[i]:Destroy() end
	local label = FKit.text(toastHolder, style[2] .. " " .. text, 26, C.White, {
		Name = "Toast",
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.XY,
		TextWrapped = true,
		LayoutOrder = toastOrder,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(680, 120), Parent = label })
	FKit.gradient(label, { style[1]:Lerp(C.White, 0.55), style[1] }, 90)
	label.TextStroke.Thickness = 4
	FKit.pop(label, 0.6)
	ctx.Sound(style[3])
	task.delay(3.6, function()
		if not label.Parent then return end
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(label.TextStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		task.wait(0.35)
		label:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Gates open on your screen when you have the OVR (the server checks too)
--------------------------------------------------------------------------------

local function refreshGates()
	local gates = workspace:FindFirstChild("Gates")
	if not gates then return end
	local ovr = player:GetAttribute("OVR") or Config.StartLevel
	for _, gate in ipairs(gates:GetChildren()) do
		local need = gate:GetAttribute("NeedOVR") or 0
		local pass = gate:GetAttribute("NeedPass") or ""
		local open = ovr >= need and (pass == "" or player:GetAttribute("Pass_" .. pass) == true)
		local barrier = gate:FindFirstChild("Barrier")
		if barrier then
			barrier.CanCollide = not open
			barrier.Transparency = open and 0.85 or 0.15
		end
		local label = gate:FindFirstChild("Label")
		for _, gui in ipairs(label and label:GetChildren() or {}) do
			local status = gui:FindFirstChild("Status")
			if status then
				status.Text = open and "\u{2705} OPEN" or ("\u{1F512} " .. (pass ~= "" and "VIP ONLY" or (need .. " OVR")))
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Start everything
--------------------------------------------------------------------------------

ctx.Card = CardUI.Init(ctx)
UpgradeFX.Init(ctx)
TrainingClient.Init(ctx)
MenusUI.Init(ctx)
require(ReplicatedStorage:WaitForChild("Icons")).Report()

-- The football over the lobby fountain spins slowly and bobs. Done here, on
-- each player's own screen, so it is smooth and costs the server nothing;
-- it stops when you are far away.
task.spawn(function()
	local map = workspace:WaitForChild("Map", 60)
	local ball = map and map:WaitForChild("Plaza", 30)
	ball = ball and ball:WaitForChild("Football", 30)
	if not ball then return end
	local base = ball:GetPivot()
	local angle = 0
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam or (cam.CFrame.Position - base.Position).Magnitude > 260 then return end
		angle += dt * 0.6
		local bob = math.sin(os.clock() * 1.3) * 0.5
		ball:PivotTo(CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(math.rad(18), 0, 0) * CFrame.Angles(0, angle, 0))
	end)
end)

ctx.Remotes.Progress.OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "xp" then
		TrainingClient.OnXP(data)
	elseif kind == "statUp" then
		CardUI.StatUp(data)
		TrainingClient.OnStatUp(data)
	elseif kind == "ovrUp" then
		UpgradeFX.Queue(data)
		refreshGates()
	elseif kind == "ovrSet" then
		CardUI.Refresh()
	elseif kind == "season" then
		UpgradeFX.Season(data)
	elseif kind == "legend" then
		UpgradeFX.Legend()
	end
end)

ctx.Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	ctx.Toast(text, kind)
end)

ctx.Remotes.OpenMenu.OnClientEvent:Connect(function(name)
	MenusUI.Open(name)
end)

for _, attribute in ipairs({ "OVR", "Pass_VIP" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshGates)
end
task.spawn(function()
	workspace:WaitForChild("Gates", 30)
	task.wait(1)
	refreshGates()
end)
