-- Football Stars: starts everything on the server.
--
--   1. the remotes the client talks through
--   2. the map (MapBuilder) with every station
--   3. the services: stats, training, the stadium match, rewards, the shop
--      and the leaderboards
--   4. players joining and leaving (load, set up, save)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local TrainingService = require(script.Parent:WaitForChild("TrainingService"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))
local RewardService = require(script.Parent:WaitForChild("RewardService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local function remote(class, name)
	local r = folder:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end

local remotes = {
	Train = remote("RemoteFunction", "Train"),          -- drill actions (shoot, pass, tackle, lift, leave)
	TrainEvent = remote("RemoteEvent", "TrainEvent"),   -- drill updates to the client
	Progress = remote("RemoteEvent", "Progress"),       -- XP, +1, OVR up, seasons
	Request = remote("RemoteFunction", "Request"),      -- menus: daily, quests, positions, season, shop, style
	Notify = remote("RemoteEvent", "Notify"),           -- messages
	OpenMenu = remote("RemoteEvent", "OpenMenu"),       -- a board in the world opens a menu
}

--------------------------------------------------------------------------------
-- Map and services
--------------------------------------------------------------------------------

local started = os.clock()
local ok, records, boards, extra = pcall(MapBuilder.Build)
if not ok then
	warn("[Football] building the map failed:", records)
	records, boards, extra = {}, {}, {}
end
print(string.format("[Football] map built in %.2fs", os.clock() - started))

StatService.Init(remotes)
TrainingService.Init(remotes, records)
MatchService.Init()
RewardService.Init(remotes)
ShopService.Init(remotes)
LeaderboardService.Init(boards)

StatService.OnChanged = function(player)
	RewardService.Sync(player)
end

if extra.PositionPrompt then
	extra.PositionPrompt.Triggered:Connect(function(player)
		remotes.OpenMenu:FireClient(player, "Positions")
	end)
end

--------------------------------------------------------------------------------
-- Menus
--------------------------------------------------------------------------------

local lastRequest = {}

remotes.Request.OnServerInvoke = function(player, action, arg, arg2)
	local t = os.clock()
	if t - (lastRequest[player] or 0) < 0.15 then return false, "Slow down!" end
	lastRequest[player] = t
	if not DataService.Get(player) then return false, "Your card is still loading." end
	if action == "ClaimDaily" then
		return RewardService.ClaimDaily(player)
	elseif action == "ClaimQuest" then
		return RewardService.ClaimQuest(player, arg)
	elseif action == "SetPosition" then
		return StatService.SetPosition(player, arg)
	elseif action == "NewSeason" then
		return StatService.NewSeason(player)
	elseif action == "Equip" then
		return RewardService.Equip(player, arg)
	elseif action == "BuyPass" then
		return ShopService.BuyPass(player, arg)
	elseif action == "BuyProduct" then
		return ShopService.BuyProduct(player, arg, arg2)
	end
	return false, "Unknown request."
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------

local function onCharacter(player)
	local character = player.Character
	if not character then return end
	character:WaitForChild("Head", 5)
	character:WaitForChild("HumanoidRootPart", 5)
	TrainingService.CharacterAdded(player)
	StatService.CharacterAdded(player)
end

local function onJoin(player)
	player.CharacterAdded:Connect(function()
		task.defer(onCharacter, player)
	end)
	local data = DataService.Load(player)
	if not data then return end
	ShopService.CheckPasses(player)
	StatService.Sync(player)
	RewardService.Sync(player)
	if player.Character then task.defer(onCharacter, player) end
	if not DataService.CanSave(player) then
		remotes.Notify:FireClient(player, "Saving is off right now (Studio without API access?). Your progress will not be kept.", "error")
	end
end

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onJoin, player) end

Players.PlayerRemoving:Connect(function(player)
	TrainingService.End(player, "left")
	StatService.Remove(player)
	DataService.Release(player)
	lastRequest[player] = nil
end)

