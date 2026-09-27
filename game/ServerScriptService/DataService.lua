-- Saving and loading every player's card with DataStoreService.
--
-- Loads with a few retries. If it still fails the player plays on default
-- data that is never saved, so a bad moment at Roblox can not wipe a card.
-- Saves every 60 seconds, when a player leaves and when the server closes,
-- each with retries.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))

local DataService = {}

local STORE_NAME = "FootballStars_v1"
local AUTOSAVE = 60
local RETRIES = 4

local store = nil
do
	local ok, result = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = result else warn("[Data] no DataStore (publish the place and turn on API access):", result) end
end

local profiles = {}   -- player -> data
local canSave = {}    -- player -> true once loaded from the store
local dirty = {}

local function blank()
	local stats, xp = {}, {}
	for _, stat in ipairs(Config.StatOrder) do
		stats[stat] = Config.StartLevel
		xp[stat] = 0
	end
	local owned = {}
	for id, item in pairs(Config.Cosmetics) do
		if item.Default then owned[id] = true end
	end
	return {
		Version = 1,
		Stats = stats,
		XP = xp,
		Position = Config.StartPosition,
		PositionsUnlocked = false,
		Season = 0,
		BestOVR = Config.StartLevel,   -- this season
		EverBestOVR = Config.StartLevel,
		TotalXP = 0,
		Counters = {
			Goals = 0, TopCorners = 0, Passes = 0, PerfectRuns = 0, Tackles = 0, PerfectReps = 0,
			SpeedRuns = 0, SpeedBest = 0, MatchesWon = 0, MatchesPlayed = 0, Sessions = 0,
		},
		Quests = {},          -- quest id -> steps claimed
		Daily = { Streak = 0, Last = 0 },
		TrainStreak = { Days = 0, LastDay = -1 },
		Boost = 0,            -- 2x XP until this time (os.time)
		Cosmetics = { Owned = owned, Border = "Border_Classic", Background = "Background_Stadium", Celebration = "Celebration_Confetti" },
		Receipts = {},
		RobuxSpent = 0,
		Settings = { Music = true, SFX = true },
		Star = "",            -- the star player look worn (Config.Stars), "" = own
	}
end

-- Fills in anything missing (older saves, new fields).
local function reconcile(data)
	local fresh = blank()
	if type(data) ~= "table" then return fresh end
	for key, value in pairs(fresh) do
		if data[key] == nil or type(data[key]) ~= type(value) then
			data[key] = value
		elseif type(value) == "table" and key ~= "Receipts" and key ~= "Quests" then
			for k, v in pairs(value) do
				if data[key][k] == nil or type(data[key][k]) ~= type(v) then data[key][k] = v end
			end
		end
	end
	for _, stat in ipairs(Config.StatOrder) do
		data.Stats[stat] = math.clamp(math.floor(tonumber(data.Stats[stat]) or Config.StartLevel), Config.StartLevel, Config.MaxLevel)
		data.XP[stat] = math.max(0, tonumber(data.XP[stat]) or 0)
	end
	if not Config.Positions[data.Position] then data.Position = Config.StartPosition end
	for id, item in pairs(Config.Cosmetics) do
		if item.Default then data.Cosmetics.Owned[id] = true end
	end
	-- only the last 50 receipts are kept
	local receipts = {}
	for id, v in pairs(data.Receipts) do table.insert(receipts, { id, v }) end
	if #receipts > 50 then
		table.sort(receipts, function(a, b) return (tonumber(a[2]) or 0) > (tonumber(b[2]) or 0) end)
		data.Receipts = {}
		for i = 1, 50 do data.Receipts[receipts[i][1]] = receipts[i][2] end
	end
	return data
end

local function withRetry(what, fn)
	local lastErr
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		task.wait(math.min(2 ^ attempt * 0.5, 6))
	end
	warn("[Data] " .. what .. " failed:", lastErr)
	return false, lastErr
end

local function key(player)
	return "player_" .. player.UserId
end

function DataService.Load(player)
	local data
	if store then
		local ok, result = withRetry("load " .. player.Name, function()
			return store:GetAsync(key(player))
		end)
		if ok then
			data = reconcile(result)
			canSave[player] = true
		else
			data = blank()
			canSave[player] = false
		end
	else
		data = blank()
		canSave[player] = false
	end
	if not player.Parent then return nil end
	profiles[player] = data
	return data
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.MarkDirty(player)
	dirty[player] = true
end

function DataService.Save(player)
	local data = profiles[player]
	if not (data and store and canSave[player]) then return false end
	dirty[player] = nil
	local ok = withRetry("save " .. player.Name, function()
		store:UpdateAsync(key(player), function()
			return data
		end)
	end)
	return ok
end

function DataService.Release(player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
	dirty[player] = nil
end

function DataService.CanSave(player)
	return canSave[player] == true
end

-- Autosave loop and closing.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for _, player in ipairs(Players:GetPlayers()) do
			if profiles[player] then task.spawn(DataService.Save, player) end
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then return end
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if profiles[player] then
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do task.wait(0.2) end
end)

DataService.Blank = blank
DataService.Reconcile = reconcile
return DataService
