-- Daily login rewards, quests and card cosmetics.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))

local RewardService = {}

local Notify

--------------------------------------------------------------------------------
-- Quests
--------------------------------------------------------------------------------

local function counterValue(data, quest)
	if quest.Counter == "BestOVR" then return data.EverBestOVR end
	return data.Counters[quest.Counter] or 0
end

-- Where every quest stands, for the client.
function RewardService.QuestState(data)
	local list = {}
	for order, quest in ipairs(Config.Quests) do
		local step = (data.Quests[quest.Id] or 0) + 1
		local goal = quest.Goals[math.min(step, #quest.Goals)]
		local done = step > #quest.Goals
		local value = counterValue(data, quest)
		local ready
		if quest.Lower then
			ready = value > 0 and value < goal
		else
			ready = value >= goal
		end
		table.insert(list, {
			Id = quest.Id, Order = order, Text = quest.Text:format(tostring(goal)), Stat = quest.Stat, Step = step,
			Steps = #quest.Goals, Goal = goal, Value = value, Ready = ready and not done, Done = done, Lower = quest.Lower,
		})
	end
	return list
end

function RewardService.Sync(player)
	local data = DataService.Get(player)
	if not data then return end
	local list = RewardService.QuestState(data)
	local ready = 0
	for _, q in ipairs(list) do if q.Ready then ready += 1 end end
	player:SetAttribute("Quests", HttpService:JSONEncode(list))
	player:SetAttribute("QuestsReady", ready)
	player:SetAttribute("NextDaily", data.Daily.Last + Config.Daily.Cooldown)
	player:SetAttribute("DailyStreak", data.Daily.Streak)
	player:SetAttribute("DailyLast", data.Daily.Last)
end

local function questReward(player, data, quest)
	if quest.Stat == "ALL" then
		for _, stat in ipairs(Config.StatOrder) do
			local amount = Config.XPToNext(data.Stats[stat]) * Config.QuestReward.AllLevels
			StatService.AddXP(player, stat, amount, 1, true)
		end
		return "XP for every stat"
	end
	local amount = Config.XPToNext(data.Stats[quest.Stat]) * Config.QuestReward.Levels
	StatService.AddXP(player, quest.Stat, amount, 1, true)
	return ("+%s %s XP"):format(Config.Short(amount), quest.Stat)
end

function RewardService.ClaimQuest(player, id)
	local data = DataService.Get(player)
	local quest = Config.GetQuest(id)
	if not (data and quest) then return false, "Unknown quest." end
	for _, q in ipairs(RewardService.QuestState(data)) do
		if q.Id == id then
			if q.Done then return false, "You finished every step of this quest!" end
			if not q.Ready then return false, "Not done yet. Keep training!" end
			data.Quests[id] = (data.Quests[id] or 0) + 1
			local text = questReward(player, data, quest)
			DataService.MarkDirty(player)
			RewardService.Sync(player)
			return true, "Quest complete! " .. text
		end
	end
	return false, "Unknown quest."
end

--------------------------------------------------------------------------------
-- Daily login reward
--------------------------------------------------------------------------------

function RewardService.DailyState(data)
	local t = os.time()
	local ready = t - data.Daily.Last >= Config.Daily.Cooldown
	local streak = data.Daily.Streak
	if ready and t - data.Daily.Last > Config.Daily.Reset then streak = 0 end
	return ready, streak % #Config.Daily.Days + 1
end

local function giveCosmetic(player, data, item)
	if data.Cosmetics.Owned[item] then return false end
	data.Cosmetics.Owned[item] = true
	local def = Config.Cosmetics[item]
	Notify:FireClient(player, ("New card %s: %s!"):format(def.Kind:lower(), def.Name), "unlock")
	return true
end

function RewardService.ClaimDaily(player)
	local data = DataService.Get(player)
	if not data then return false, "Loading..." end
	local ready, day = RewardService.DailyState(data)
	if not ready then
		return false, "Next reward in " .. Config.Clock(data.Daily.Last + Config.Daily.Cooldown - os.time())
	end
	if os.time() - data.Daily.Last > Config.Daily.Reset then data.Daily.Streak = 0 end
	data.Daily.Streak += 1
	data.Daily.Last = os.time()
	local entry = Config.Daily.Days[day]
	local lines = {}
	if entry.Kind == "Boost" or entry.Kind == "Big" then
		data.Boost = math.max(data.Boost, os.time()) + entry.Minutes * 60
		table.insert(lines, ("2x XP for %d minutes"):format(entry.Minutes))
	end
	if entry.Kind == "XPAll" or entry.Kind == "Big" then
		for _, stat in ipairs(Config.StatOrder) do
			StatService.AddXP(player, stat, entry.Amount * Config.LevelBonus(data.Stats[stat]), 1, true)
		end
		table.insert(lines, ("+%d XP to every stat"):format(entry.Amount))
	end
	if entry.Item then
		if giveCosmetic(player, data, entry.Item) then
			table.insert(lines, Config.Cosmetics[entry.Item].Name)
		elseif entry.Kind == "Cosmetic" then
			-- already owned: XP instead
			for _, stat in ipairs(Config.StatOrder) do
				StatService.AddXP(player, stat, 80 * Config.LevelBonus(data.Stats[stat]), 1, true)
			end
			table.insert(lines, "+80 XP to every stat")
		end
	end
	DataService.MarkDirty(player)
	StatService.Sync(player)
	RewardService.Sync(player)
	return true, ("Day %d: %s"):format(day, table.concat(lines, ", ")), { Day = day, Lines = lines }
end

--------------------------------------------------------------------------------
-- Cosmetics
--------------------------------------------------------------------------------

function RewardService.UnlockPack(player)
	local data = DataService.Get(player)
	if not data then return end
	for id, item in pairs(Config.Cosmetics) do
		if item.Pack then data.Cosmetics.Owned[id] = true end
	end
	DataService.MarkDirty(player)
	StatService.Sync(player)
end

function RewardService.Equip(player, id)
	local data = DataService.Get(player)
	local item = Config.Cosmetics[id]
	if not (data and item) then return false, "Unknown item." end
	if not data.Cosmetics.Owned[id] then
		return false, item.Pack and "Get the Card Style Pack to use this." or "Keep claiming daily rewards to unlock this!"
	end
	data.Cosmetics[item.Kind] = id
	DataService.MarkDirty(player)
	StatService.Sync(player)
	return true
end

--------------------------------------------------------------------------------

function RewardService.Init(remotes)
	Notify = remotes.Notify
end

return RewardService
