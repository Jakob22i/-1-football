-- The football screen in the preview: runs the real server and the real
-- client together for one pretend player, then prints the screen (G lines)
-- for gui_render.py.
--
--   VIEW_W=1280 VIEW_H=720      screen size (TOUCH=true for a phone)
--   STATS="72,70,66,68,61,64"   PAC,SHO,PAS,DRI,DEF,PHY
--   SEASON=1                    season number
--   PASSES="DoubleXP,VIP"       gamepasses owned
--   OPEN="Card"                 open a window: Card, Daily, Quests, Positions, Season, Style, Shop
--   UPGRADE="74,75"             play the upgrade moment from 74 to 75 ...
--   STEPS=6                     ... and stop after this many steps
--   STATUP="SHO"                a stat +1 on the corner card
--   DRILL="Lobby_Shooting"      start a drill (its HUD)
--   TOASTS=true                 a few messages at the top
--   XPPOP="PHY"                 "+XP" pops in the middle of the screen
--   SCROLL=400                  scroll the open window's list down

local W, H = tonumber(VIEW_W) or 1280, tonumber(VIEW_H) or 720

CLOCK = os.time()
INST.GetServerTimeNow = function() return CLOCK end
INST.GetNetworkPing = function() return 0.06 end
INST.IsStudio = function() return true end
INST.PromptGamePassPurchase = function() end
INST.PromptProductPurchase = function() end
INST.UserOwnsGamePassAsync = function() return false end
INST.BindToClose = function() end
INST.GetDataStore = function() error("no DataStore in the preview") end
INST.GetOrderedDataStore = function() error("no DataStore in the preview") end
INST.GetGuiInset = function() return Vector2.new(0, 58), Vector2.new() end

local function fire(inst, name, ...)
	local sigs = rawget(inst, "__signals")
	if sigs[name] then sigs[name]:Fire(...) end
end

if PACKTEST then
local pack = Instance.new("Model")
pack.Name = "Simulator Icon Pack"
pack.Parent = game:GetService("ReplicatedStorage")
for _, n in ipairs({ "Gift", "Trophy", "Lightning", "Shopping Cart", "Lock" }) do
	local part = Instance.new("Part") part.Name = n part.Parent = pack
	local d = Instance.new("Decal") d.Texture = "rbxassetid://" .. (#n * 1000) d.Parent = part
end
end
if SPRITE then require("Icons").Sprite.Image = SPRITE end -- SPRITE="1": the uploaded icon sheet
-- the server
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")

local Players = game:GetService("Players")
local plr = newInstance("Player")
plr.Name = "Jakob"
plr.DisplayName = "Jakob"
plr.UserId = tonumber(USERID) or 1 -- USERID=0: a Studio test player (no avatar picture)
plr.Parent = Players
local rig = MockRig(nil)
rig.Name = "Jakob"
rig.Parent = workspace
plr.Character = rig
INST.GetPlayers = function(self)
	if self == Players then return { plr } end
	return {}
end
Players.LocalPlayer = plr
local pg = newInstance("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = plr
workspace.CurrentCamera.ViewportSize = Vector2.new(W, H)
local uis = game:GetService("UserInputService")
uis.TouchEnabled = TOUCH == true
uis.MouseEnabled = TOUCH ~= true
uis.KeyboardEnabled = TOUCH ~= true
function uis:GetMouseLocation() return Vector2.new(W / 2, H / 2) end
function uis:IsMouseButtonPressed() return false end

local ok, err = pcall(MODULES.Main)
if not ok then print("MAIN ERROR", err) end
fire(Players, "PlayerAdded", plr)
RunScheduler(4)

local Config = require("FootballConfig")
local DataService = require("DataService")
local StatService = require("StatService")
local RewardService = require("RewardService")
local data = DataService.Get(plr)
if not data then print("ERROR no data") end

-- the player we want to show
if STATS then
	local i = 0
	for v in string.gmatch(STATS, "[^,]+") do
		i += 1
		data.Stats[Config.StatOrder[i]] = tonumber(v)
	end
end
for _, stat in ipairs(Config.StatOrder) do data.XP[stat] = math.floor(Config.XPToNext(data.Stats[stat]) * 0.62) end
data.Season = tonumber(SEASON) or 0
data.PositionsUnlocked = StatService.OVR(data) >= Config.PositionsUnlockOVR or data.Season > 0
data.BestOVR = StatService.OVR(data)
data.EverBestOVR = math.max(data.EverBestOVR, data.BestOVR)
data.Counters.Goals = 31
data.Counters.TopCorners = 4
data.Counters.Passes = 12
data.Counters.SpeedBest = 23.4
data.Counters.Tackles = 9
data.Quests.Goals = 2
data.Daily.Streak = 2
data.Daily.Last = CLOCK - 21 * 3600
data.TrainStreak = { Days = 3, LastDay = math.floor(CLOCK / 86400) }
data.Boost = CLOCK + 11 * 60 + 42
data.Cosmetics.Owned.Border_Neon = true
data.Cosmetics.Border = BORDER or data.Cosmetics.Border
for key in string.gmatch(PASSES or "", "[^,]+") do plr:SetAttribute("Pass_" .. key, true) end
StatService.Sync(plr)
RewardService.Sync(plr)

-- the wires between the two
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
INST.InvokeServer = function(self, ...)
	local f = self.OnServerInvoke
	if f then return f(plr, ...) end
	return nil
end
INST.FireClient = function(self, _, ...)
	fire(self, "OnClientEvent", ...)
end
INST.FireAllClients = function(self, ...)
	fire(self, "OnClientEvent", ...)
end

-- time moves 0.1 s for every scheduler step, so animations that watch the
-- clock move on too
local fakeClock = 0
local realOs = os
os = setmetatable({ clock = function() return fakeClock end }, { __index = realOs })
local realRun = RunScheduler
RunScheduler = function(n)
	for _ = 1, n or 1 do
		fakeClock += 0.1
		CLOCK += 0.1
		realRun(1)
	end
end
local renderStepped = game:GetService("RunService").RenderStepped
renderStepped.Wait = function()
	task.wait()
	return 0.1
end

-- the client
script = newInstance("LocalScript")
script.Name = "ClientMain"
script.Parent = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local okClient, errClient = pcall(MODULES.ClientMain)
if not okClient then print("CLIENT ERROR", errClient) end
RunScheduler(3)

if STATUP then
	data.Stats[STATUP] += 1
	StatService.Sync(plr)
	fire(Remotes.Progress, "OnClientEvent", "statUp", { Stat = STATUP, Level = data.Stats[STATUP], Ups = 1 })
end
if TOASTS then
	local notify = Remotes.Notify
	fire(notify, "OnClientEvent", "GOLD UNLOCKED! The Stadium is open.", "unlock")
	fire(notify, "OnClientEvent", "\u{1F525} 3-day training streak! +10% XP", "streak")
end
if DRILL then
	local TrainingService = require("TrainingService")
	print("DRILL", TrainingService.Start(plr, DRILL))
	RunScheduler(2)
end
if OPEN then
	require("MenusUI").Open(OPEN)
	RunScheduler(1)
end
if UPGRADE then
	local a, b = string.match(UPGRADE, "(%d+),(%d+)")
	a, b = tonumber(a), tonumber(b)
	fire(Remotes.Progress, "OnClientEvent", "ovrUp", { Old = a, New = b, OldTier = Config.TierFor(a), NewTier = Config.TierFor(b) })
	RunScheduler(tonumber(STEPS) or 6)
end

if SCROLL then
	for _, d in ipairs(pg:GetDescendants()) do
		if d.Name == "List" and d:IsA("ScrollingFrame") then
			d.CanvasPosition = Vector2.new(0, tonumber(SCROLL))
			-- the picture does not scroll lists: hide the rows above instead
			local rows = {}
			for _, row in ipairs(d:GetChildren()) do
				if row:IsA("GuiObject") then table.insert(rows, row) end
			end
			table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			local hidden = 0
			for _, row in ipairs(rows) do
				if hidden + row.Size.Y.Offset <= tonumber(SCROLL) then
					hidden += row.Size.Y.Offset
					row.Visible = false
				end
			end
		end
	end
	RunScheduler(2)
end
if XPPOP then
	for _, amount in ipairs({ 12, 12, 16 }) do
		fire(Remotes.Progress, "OnClientEvent", "xp", { Stat = XPPOP, Amount = amount, XP = 40, Need = 120, Level = data.Stats[XPPOP] })
	end
	-- (no scheduler step: the preview runs delays at once, which would
	-- clear the pops before the picture)
end

if ICONS then
	-- every drawn icon on one sheet
	local Icons = require("Icons")
	local sheet = Instance.new("ScreenGui")
	sheet.Name = "IconSheet"
	sheet.Parent = pg
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 40, 90)
	bg.ZIndex = 50
	bg.Parent = sheet
	local names = {}
	for name in pairs(Icons.Names) do table.insert(names, name) end
	table.sort(names)
	for i, name in ipairs(names) do
		local col, row = (i - 1) % 7, (i - 1) // 7
		Icons.new(bg, name, { Position = UDim2.fromOffset(40 + col * 175, 40 + row * 170), Size = UDim2.fromOffset(120, 120), ZIndex = 51 })
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = name
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextSize = 20
		l.Position = UDim2.fromOffset(40 + col * 175, 165 + row * 170)
		l.Size = UDim2.fromOffset(120, 24)
		l.ZIndex = 51
		l.Parent = bg
	end
	RunScheduler(1)
end
ExportGui(pg)
