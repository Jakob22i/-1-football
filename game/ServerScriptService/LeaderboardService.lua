-- The three boards in the lobby: Highest OVR, Most Seasons and the Fastest
-- Speed Course. Scores go into OrderedDataStores when players save and the
-- boards refresh every minute.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))

local LeaderboardService = {}

local BOARDS = {
	HighestOVR = { Store = "FS_HighestOVR", Ascending = false },
	MostSeasons = { Store = "FS_MostSeasons", Ascending = false },
	FastestSpeed = { Store = "FS_FastestSpeed", Ascending = true },
}

local stores = {}
local boards = {}
local names = {}

for key, def in pairs(BOARDS) do
	local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(def.Store) end)
	if ok then stores[key] = store end
end

-- What a player puts on each board.
local function scores(player)
	local data = DataService.Get(player)
	if not data then return nil end
	return {
		-- OVR first, the season breaks ties
		HighestOVR = StatService.OVR(data) * 1000 + math.min(data.Season, 999),
		MostSeasons = data.Season,
		FastestSpeed = data.Counters.SpeedBest > 0 and math.floor(data.Counters.SpeedBest * 100 + 0.5) or nil,
	}
end

local function display(key, value)
	if key == "HighestOVR" then return tostring(value // 1000) .. " OVR" end
	if key == "MostSeasons" then return "S" .. value end
	return ("%.2fs"):format(value / 100)
end

function LeaderboardService.Submit(player)
	local list = scores(player)
	if not list then return end
	for key, value in pairs(list) do
		local store = stores[key]
		if store and value and value > 0 then
			pcall(function() store:SetAsync(tostring(player.UserId), value) end)
		end
	end
end

local function nameOf(userId)
	if names[userId] then return names[userId] end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = ok and name or ("Player " .. userId)
	return names[userId]
end

local function fill(key, entries)
	local board = boards[key]
	if not board then return end
	for i, row in ipairs(board.Rows) do
		local entry = entries[i]
		row.Name.Text = entry and entry.Name or "-"
		row.Value.Text = entry and display(key, entry.Value) or ""
	end
end

-- With no DataStore (Studio without API access) the boards show who is here.
local function localEntries(key)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local s = scores(player)
		if s and s[key] and s[key] > 0 then table.insert(list, { Name = player.DisplayName, Value = s[key] }) end
	end
	table.sort(list, function(a, b)
		if BOARDS[key].Ascending then return a.Value < b.Value end
		return a.Value > b.Value
	end)
	return list
end

function LeaderboardService.Refresh()
	for key, def in pairs(BOARDS) do
		local store = stores[key]
		local entries
		if store then
			local ok, pages = pcall(function() return store:GetSortedAsync(def.Ascending, 10) end)
			if ok and pages then
				entries = {}
				for _, item in ipairs(pages:GetCurrentPage()) do
					table.insert(entries, { Name = nameOf(tonumber(item.key)), Value = item.value })
				end
			end
		end
		fill(key, entries or localEntries(key))
	end
end

function LeaderboardService.Init(boardRecords)
	boards = boardRecords
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(LeaderboardService.Submit, player)
			end
			task.wait(3)
			LeaderboardService.Refresh()
			task.wait(60)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		LeaderboardService.Submit(player)
	end)
end

LeaderboardService.Display = display
return LeaderboardService
