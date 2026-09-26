-- The +1 loop, all on the server: XP goes into one stat, a full bar gives
-- the stat +1, OVR is worked out from the stats for your position, and a
-- higher OVR tells the player's screen to play the upgrade moment.
--
-- Also: multipliers (seasons, 2x XP, boosts, training streak), walking speed
-- from Pace, positions, New Season, the cards over players' heads and the
-- LEGEND aura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local CardView = require(ReplicatedStorage:WaitForChild("CardView"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local StatService = {}

local Progress, Notify -- remotes, set in Init
local headCards = {}   -- player -> CardView on the billboard
local busy = {}        -- player -> true while a drill controls walk speed

-- Hooks other services set: called after counters or OVR change.
StatService.OnChanged = nil

function StatService.Init(remotes)
	Progress = remotes.Progress
	Notify = remotes.Notify
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------

function StatService.OVR(data)
	return Config.OVR(data.Stats, data.Position)
end

function StatService.HasPass(player, key)
	return player:GetAttribute("Pass_" .. key) == true
end

-- Everything that multiplies XP, with a line for each (for the screen).
function StatService.Multiplier(player, data, areaMult)
	local mult = areaMult or 1
	mult *= 1 + Config.Season.BonusPer * data.Season
	if StatService.HasPass(player, "DoubleXP") then mult *= 2 end
	if data.Boost > os.time() then mult *= Config.Boost.Multiplier end
	mult *= Config.StreakMultiplier(data.TrainStreak.Days)
	return mult
end

--------------------------------------------------------------------------------
-- Syncing to the client (attributes replicate to everyone)
--------------------------------------------------------------------------------

function StatService.Sync(player)
	local data = DataService.Get(player)
	if not data then return end
	local ovr = StatService.OVR(data)
	for _, stat in ipairs(Config.StatOrder) do
		player:SetAttribute(stat, data.Stats[stat])
		player:SetAttribute("XP_" .. stat, math.floor(data.XP[stat]))
		player:SetAttribute("Need_" .. stat, data.Stats[stat] >= Config.MaxLevel and 0 or Config.XPToNext(data.Stats[stat]))
	end
	player:SetAttribute("OVR", ovr)
	player:SetAttribute("Tier", Config.TierFor(ovr))
	player:SetAttribute("Position", data.Position)
	player:SetAttribute("PositionsUnlocked", data.PositionsUnlocked)
	player:SetAttribute("Season", data.Season)
	player:SetAttribute("BestOVR", data.BestOVR)
	player:SetAttribute("Boost", data.Boost)
	player:SetAttribute("StreakDays", data.TrainStreak.Days)
	player:SetAttribute("StreakLastDay", data.TrainStreak.LastDay)
	player:SetAttribute("XPMultiplier", StatService.Multiplier(player, data, 1))
	player:SetAttribute("SpeedBest", data.Counters.SpeedBest)
	player:SetAttribute("Cosmetics", HttpService:JSONEncode(data.Cosmetics))
	player:SetAttribute("Counters", HttpService:JSONEncode(data.Counters))
	player:SetAttribute("DataReady", true)
	StatService.UpdateHeadCard(player)
	if not busy[player] then StatService.ApplyWalkSpeed(player) end
end

--------------------------------------------------------------------------------
-- Walking speed
--------------------------------------------------------------------------------

-- A drill takes over walking speed while it runs (busy = true).
function StatService.SetBusy(player, on)
	busy[player] = on or nil
	if not on then StatService.ApplyWalkSpeed(player) end
end

function StatService.ApplyWalkSpeed(player)
	local data = DataService.Get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (data and humanoid) then return end
	humanoid.WalkSpeed = Config.WalkSpeed(data.Stats.PAC)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Speed.JumpPower
end

--------------------------------------------------------------------------------
-- XP
--------------------------------------------------------------------------------

local function today()
	return os.time() // 86400
end

-- A day with training keeps the streak going.
local function touchStreak(data)
	local day = today()
	local streak = data.TrainStreak
	if streak.LastDay == day then return false end
	if streak.LastDay == day - 1 then
		streak.Days += 1
	else
		streak.Days = 1
	end
	streak.LastDay = day
	return true
end

local announce -- defined below

-- Checks OVR after stats changed: the upgrade moment, unlocks, LEGEND.
local function checkOVR(player, data, oldOVR)
	local newOVR = StatService.OVR(data)
	if newOVR > oldOVR then
		local oldTier, newTier = Config.TierFor(oldOVR), Config.TierFor(newOVR)
		Progress:FireClient(player, "ovrUp", { Old = oldOVR, New = newOVR, OldTier = oldTier, NewTier = newTier })
		if newOVR > data.BestOVR then
			for _, mark in ipairs({ 70, 75, 80, 90, 99 }) do
				if data.BestOVR < mark and newOVR >= mark then announce(player, data, mark) end
			end
			data.BestOVR = newOVR
		end
		data.EverBestOVR = math.max(data.EverBestOVR, newOVR)
		if newOVR >= Config.PositionsUnlockOVR then data.PositionsUnlocked = true end
	end
	return newOVR
end

-- Adds XP to one stat ("ALL" splits the amount over every stat, weighted a
-- little toward your position). areaMult is the station's multiplier; pass
-- plain = true for rewards that should not be multiplied (quests, daily).
-- Returns the XP actually added.
function StatService.AddXP(player, stat, amount, areaMult, plain)
	local data = DataService.Get(player)
	if not data or amount <= 0 then return 0 end
	if stat == "ALL" then
		local total = 0
		for _, s in ipairs(Config.StatOrder) do
			total += StatService.AddXP(player, s, amount, areaMult, plain)
		end
		return total
	end
	if not data.Stats[stat] then return 0 end

	local gained = plain and amount or amount * StatService.Multiplier(player, data, areaMult)
	gained = math.max(1, math.floor(gained + 0.5))
	if not plain and touchStreak(data) and data.TrainStreak.Days >= 2 then
		Notify:FireClient(player, ("\u{1F525} %d-day training streak! +%d%% XP"):format(data.TrainStreak.Days,
			math.floor((Config.StreakMultiplier(data.TrainStreak.Days) - 1) * 100 + 0.5)), "streak")
	end

	local oldOVR = StatService.OVR(data)
	if data.Stats[stat] >= Config.MaxLevel then
		Progress:FireClient(player, "xp", { Stat = stat, Amount = 0, Max = true })
		return 0
	end
	data.XP[stat] += gained
	data.TotalXP += gained
	local ups = 0
	while data.Stats[stat] < Config.MaxLevel and data.XP[stat] >= Config.XPToNext(data.Stats[stat]) do
		data.XP[stat] -= Config.XPToNext(data.Stats[stat])
		data.Stats[stat] += 1
		ups += 1
	end
	if data.Stats[stat] >= Config.MaxLevel then data.XP[stat] = 0 end

	Progress:FireClient(player, "xp", {
		Stat = stat, Amount = gained, XP = math.floor(data.XP[stat]),
		Need = data.Stats[stat] >= Config.MaxLevel and 0 or Config.XPToNext(data.Stats[stat]), Level = data.Stats[stat],
	})
	if ups > 0 then
		Progress:FireClient(player, "statUp", { Stat = stat, Level = data.Stats[stat], Ups = ups })
		checkOVR(player, data, oldOVR)
		if stat == "PAC" and not busy[player] then StatService.ApplyWalkSpeed(player) end
	end
	DataService.MarkDirty(player)
	StatService.Sync(player)
	if StatService.OnChanged then StatService.OnChanged(player) end
	return gained
end

-- +levels to a stat straight away (the Instant Stat Point product).
function StatService.AddLevel(player, stat, levels, cap)
	local data = DataService.Get(player)
	if not (data and data.Stats[stat]) then return false end
	if data.Stats[stat] >= (cap or Config.MaxLevel) then return false end
	local oldOVR = StatService.OVR(data)
	data.Stats[stat] = math.min(data.Stats[stat] + levels, cap or Config.MaxLevel)
	Progress:FireClient(player, "statUp", { Stat = stat, Level = data.Stats[stat], Ups = levels })
	checkOVR(player, data, oldOVR)
	DataService.MarkDirty(player)
	StatService.Sync(player)
	if StatService.OnChanged then StatService.OnChanged(player) end
	return true
end

-- Adds to a counter (goals, tackles...). mode "min" keeps the lowest (best
-- times), "max" the highest.
function StatService.Count(player, counter, amount, mode)
	local data = DataService.Get(player)
	if not data then return end
	local c = data.Counters
	if mode == "min" then
		if (c[counter] or 0) == 0 or amount < c[counter] then c[counter] = amount end
	elseif mode == "max" then
		c[counter] = math.max(c[counter] or 0, amount)
	else
		c[counter] = (c[counter] or 0) + (amount or 1)
	end
	DataService.MarkDirty(player)
	if StatService.OnChanged then StatService.OnChanged(player) end
end

--------------------------------------------------------------------------------
-- Positions and seasons
--------------------------------------------------------------------------------

function StatService.SetPosition(player, position)
	local data = DataService.Get(player)
	if not data then return false, "Loading..." end
	if not Config.Positions[position] then return false, "Unknown position." end
	if not data.PositionsUnlocked and position ~= Config.StartPosition then
		return false, ("Reach %d OVR to unlock the Position Board!"):format(Config.PositionsUnlockOVR)
	end
	if data.Position == position then return true end
	local oldOVR = StatService.OVR(data)
	data.Position = position
	local newOVR = StatService.OVR(data)
	if newOVR > oldOVR then
		checkOVR(player, data, oldOVR)
	elseif newOVR < oldOVR then
		Progress:FireClient(player, "ovrSet", { Old = oldOVR, New = newOVR })
	end
	DataService.MarkDirty(player)
	StatService.Sync(player)
	if StatService.OnChanged then StatService.OnChanged(player) end
	return true, ("You are now a %s. OVR %d."):format(Config.Positions[position].Name, newOVR)
end

function StatService.NewSeason(player)
	local data = DataService.Get(player)
	if not data then return false, "Loading..." end
	if StatService.OVR(data) < Config.Season.NeedOVR then
		return false, ("Reach %d OVR to start a New Season."):format(Config.Season.NeedOVR)
	end
	data.Season += 1
	for _, stat in ipairs(Config.StatOrder) do
		data.Stats[stat] = Config.StartLevel
		data.XP[stat] = 0
	end
	data.BestOVR = Config.StartLevel
	DataService.MarkDirty(player)
	StatService.Sync(player)
	StatService.UpdateAura(player)
	Progress:FireClient(player, "season", { Season = data.Season, Bonus = Config.Season.BonusPer * data.Season })
	for _, other in ipairs(Players:GetPlayers()) do
		Notify:FireClient(other, ("\u{1F3C6} %s started SEASON %d!"):format(player.DisplayName, data.Season), "gold")
	end
	if StatService.OnChanged then StatService.OnChanged(player) end
	return true
end

--------------------------------------------------------------------------------
-- Unlock messages and LEGEND
--------------------------------------------------------------------------------

function announce(player, data, mark)
	if mark == 70 then
		Notify:FireClient(player, "POSITION BOARD and PRO ACADEMY unlocked!", "unlock")
	elseif mark == 75 then
		Notify:FireClient(player, "The STADIUM is open: play a match!", "unlock")
	elseif mark == 80 then
		Notify:FireClient(player, "ELITE ACADEMY unlocked!", "unlock")
	elseif mark == 90 then
		Notify:FireClient(player, "LEGEND ACADEMY unlocked!", "unlock")
	elseif mark == 99 then
		for _, other in ipairs(Players:GetPlayers()) do
			Notify:FireClient(other, ("\u{2B50} %s is now a 99 LEGEND! \u{2B50}"):format(player.DisplayName), "legend")
		end
		Progress:FireClient(player, "legend", {})
	end
end

-- The gold aura round a 99 LEGEND.
function StatService.UpdateAura(player)
	local data = DataService.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (data and root) then return end
	local legend = StatService.OVR(data) >= Config.MaxLevel
	local aura = root:FindFirstChild("LegendAura")
	if legend and not aura then
		aura = Instance.new("Attachment")
		aura.Name = "LegendAura"
		aura.Parent = root
		local p = Instance.new("ParticleEmitter")
		p.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 20))
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		p.Transparency = NumberSequence.new(0.2, 1)
		p.Lifetime = NumberRange.new(0.8, 1.4)
		p.Rate = 30
		p.Speed = NumberRange.new(1.5, 3)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = aura
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 90)
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = aura
	elseif not legend and aura then
		aura:Destroy()
	end
end

--------------------------------------------------------------------------------
-- The card over every player's head
--------------------------------------------------------------------------------

function StatService.UpdateHeadCard(player)
	local data = DataService.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (data and head) then return end
	local entry = headCards[player]
	if not entry or not entry.Gui.Parent or entry.Gui.Adornee ~= head then
		if entry and entry.Gui then entry.Gui:Destroy() end
		local gui = Instance.new("BillboardGui")
		gui.Name = "HeadCard"
		gui.Adornee = head
		gui.Size = UDim2.fromScale(2.3, 3.2)
		gui.StudsOffset = Vector3.new(0, 3.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.PlayerToHideFrom = player -- your own card is in the corner of your screen
		gui.Parent = head
		local card = CardView.new(gui, { Compact = true, Size = UDim2.fromScale(1, 1) })
		card:ShowPlayer(player.UserId)
		entry = { Gui = gui, Card = card }
		headCards[player] = entry
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	end
	entry.Card:Set({
		OVR = StatService.OVR(data),
		Position = data.Position,
		Name = player.DisplayName,
		Season = data.Season,
		Border = data.Cosmetics.Border,
		Background = data.Cosmetics.Background,
	})
end

function StatService.Remove(player)
	local entry = headCards[player]
	if entry and entry.Gui then entry.Gui:Destroy() end
	headCards[player] = nil
	busy[player] = nil
end

function StatService.CharacterAdded(player)
	StatService.UpdateHeadCard(player)
	StatService.UpdateAura(player)
	if not busy[player] then StatService.ApplyWalkSpeed(player) end
end

return StatService
