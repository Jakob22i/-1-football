-- The Stadium Match (from 75 OVR): a quick 5-a-side against a team about as
-- good as you. The match is played as big moments where your stats matter:
--
--   ATTACK   one shot at goal past their keeper (SHO)
--   DEFEND   stop their striker before the goal line (DEF, PAC)
--   PASS     find the teammate who is free; a good pass sets up a goal (PAS)
--
-- Your four AI teammates and their AI team add a goal now and then. A win
-- gives big XP to every stat, a draw half, a loss a little.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local DrillMath = require(ReplicatedStorage:WaitForChild("DrillMath"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))
local TrainingService = require(script.Parent:WaitForChild("TrainingService"))

local MatchService = {}

local MATCH = Config.Drills.Match
local SHOOT = Config.Drills.Shooting
local DEF = Config.Drills.Defending
local now, send, rng = TrainingService.Now, TrainingService.Send, TrainingService.Rng

local PLAN = { "Pass", "Attack", "Defend", "Attack", "Pass", "Defend", "Attack" }
local MOMENT_TIME = { Attack = 9, Defend = 14, Pass = 7 }

local function level(player, stat)
	return TrainingService.StatLevel(player, stat)
end

-- The keeper sways across the goal; how far it can reach depends on how
-- good they are compared with your shooting.
local function keeperFor(session)
	local diff = session.Opponent - level(session.Player, "SHO")
	return {
		Amp = 5.5, Freq = 1.1 + rng:NextNumber() * 0.4, Phase = rng:NextNumber() * 6.28,
		Reach = math.clamp(3.2 + diff * 0.06, 2.4, 4.6), T0 = now(),
	}
end

local function keeperU(keeper, t)
	return keeper.Amp * math.sin(keeper.Freq * (t - keeper.T0) + keeper.Phase)
end

local function scoreText(session)
	return ("YOU %d - %d THEM"):format(session.Us, session.Them)
end

local function setScoreboard(session)
	local board = session.Station.Scoreboard
	if board then board.Text = ("%s %d - %d AWAY"):format(string.upper(session.Player.DisplayName), session.Us, session.Them) end
end

local function nextMoment(player, session)
	session.Index += 1
	local kind = session.Plan[session.Index]
	local rec = session.Station
	if not kind then
		MatchService.Finish(player, session)
		return
	end
	-- the AI teams play on between moments
	if session.Index == 4 or session.Index == #session.Plan then
		local edge = (level(player, "PAC") + level(player, "PHY") + level(player, "PAS")) / 3 - session.Opponent
		if rng:NextNumber() < math.clamp(0.25 + edge * 0.015, 0.1, 0.45) then
			session.Us += 1
			send(player, "matchEvent", { Text = "Your teammates score!", Us = session.Us, Them = session.Them, Good = true })
		elseif rng:NextNumber() < math.clamp(0.25 - edge * 0.015, 0.1, 0.45) then
			session.Them += 1
			send(player, "matchEvent", { Text = "They score on the break...", Us = session.Us, Them = session.Them, Good = false })
		end
		setScoreboard(session)
	end
	local moment = { Type = kind, Index = session.Index, Total = #session.Plan, Us = session.Us, Them = session.Them }
	session.Moment = moment
	moment.Ends = now() + MOMENT_TIME[kind] + MATCH.MomentGap
	moment.Opens = now() + MATCH.MomentGap
	if kind == "Attack" then
		TrainingService.Freeze(player, true)
		local spot = rec.AttackSpot
		local goalMid = DrillMath.GoalPoint(rec.TheirGoal, 0, 0)
		TrainingService.PlaceAt(player, CFrame.lookAt(spot + Vector3.new(0, 3, 0), Vector3.new(goalMid.X, 3, goalMid.Z)))
		moment.Spot = spot
		moment.Goal = rec.TheirGoal
		moment.GoalWidth, moment.GoalHeight = 24, 8
		moment.Keeper = keeperFor(session)
		moment.Green = { SHOOT.GreenFrom, SHOOT.GreenTo }
		moment.Shot = false
	elseif kind == "Pass" then
		TrainingService.Freeze(player, true)
		local spot = rec.PassSpot
		local ahead = DrillMath.GoalPoint(rec.TheirGoal, 0, 0)
		TrainingService.PlaceAt(player, CFrame.lookAt(spot + Vector3.new(0, 3, 0), Vector3.new(ahead.X, 3, ahead.Z)))
		moment.Spot = spot
		moment.Teammates = rec.Teammates
		moment.Free = rng:NextInteger(1, #rec.Teammates)
		moment.MaxDistance = Config.Drills.Passing.MaxDistance
		moment.Passed = false
	else
		-- DEFEND: their striker runs at your goal
		TrainingService.Freeze(player, false)
		StatService.SetBusy(player, true)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Config.WalkSpeed(level(player, "PAC")) + 2
			humanoid.JumpPower = Config.Speed.JumpPower
		end
		local line = rec.DefendLine
		TrainingService.PlaceAt(player, (line * CFrame.new(0, 3, -14)))
		local speed = math.clamp(10 + (session.Opponent - level(player, "DEF")) * 0.15 + session.Index * 0.4, 9, 20)
		local startPos = (line * CFrame.new((rng:NextNumber() * 2 - 1) * 14, 0, -44)).Position
		local endPos = (line * CFrame.new((rng:NextNumber() * 2 - 1) * 8, 0, 0)).Position
		local att = {
			Id = session.Index, Start = startPos, End = endPos, T0 = now() + MATCH.MomentGap + 0.6,
			Duration = (endPos - startPos).Magnitude / speed, Amp = 4, Freq = 1.6,
		}
		session.Attackers = { [att.Id] = att }
		moment.Attackers = { att }
		moment.Line = line
		moment.Ends = att.T0 + att.Duration + 1
	end
	send(player, "moment", moment)
end

local function momentResult(player, session, text, good, scored, conceded)
	if scored then session.Us += 1 end
	if conceded then session.Them += 1 end
	setScoreboard(session)
	session.Moment.Done = true
	send(player, "matchEvent", { Text = text, Good = good, Us = session.Us, Them = session.Them, Goal = scored, Against = conceded })
	task.delay(MATCH.MomentGap + 0.4, function()
		if TrainingService.Get(player) == session then nextMoment(player, session) end
	end)
end

local function start(player, session)
	local data = DataService.Get(player)
	local ovr = StatService.OVR(data)
	session.Opponent = math.clamp(ovr + rng:NextInteger(-2, 3), 60, 99)
	session.Us, session.Them = 0, 0
	session.Index = 0
	session.Plan = table.clone(PLAN)
	session.Attackers = {}
	session.Summary = function(s) return { Us = s.Us, Them = s.Them, Opponent = s.Opponent } end
	setScoreboard(session)
	send(player, "start", {
		Kind = "Match", Station = session.Station.Id, Opponent = session.Opponent, Moments = #session.Plan, Stat = "ALL", Area = "Stadium",
		Pitch = session.Station.Pitch,
	})
	task.delay(1.5, function()
		if TrainingService.Get(player) == session then nextMoment(player, session) end
	end)
end

function MatchService.Finish(player, session)
	local result = session.Us > session.Them and "win" or (session.Us == session.Them and "draw" or "loss")
	local base = result == "win" and MATCH.WinXP or (result == "draw" and MATCH.DrawXP or MATCH.LossXP)
	local total = 0
	for _, stat in ipairs(Config.StatOrder) do
		total += TrainingService.Reward(player, session, base, stat)
	end
	StatService.Count(player, "MatchesPlayed", 1)
	if result == "win" then StatService.Count(player, "MatchesWon", 1) end
	send(player, "matchEnd", { Result = result, Us = session.Us, Them = session.Them, XP = total })
	session.Finished = true
	task.delay(4, function()
		if TrainingService.Get(player) == session then
			TrainingService.End(player, "done")
			TrainingService.PlaceAt(player, CFrame.new(session.Station.Kickoff + Vector3.new(0, 3, 6)))
		end
	end)
end

local actions = {
	Shoot = function(player, session, u, v, power)
		local m = session.Moment
		if not (m and m.Type == "Attack") or m.Shot or m.Done then return { Result = "wait" } end
		if type(u) ~= "number" or type(v) ~= "number" or type(power) ~= "number" or u ~= u or v ~= v or power ~= power then return nil end
		if now() < m.Opens then return { Result = "wait" } end
		m.Shot = true
		local lu, lv, inGoal = TrainingService.ResolveShot(player, session, math.clamp(u, -24, 24), math.clamp(v, 0, 16), math.clamp(power, 0, 1), 24, 8)
		local tHit = now() + SHOOT.FlightTime
		local saved = false
		if inGoal then
			local ku = keeperU(m.Keeper, tHit)
			local reach = m.Keeper.Reach * (lv > 5.5 and 0.8 or 1)
			saved = math.abs(lu - ku) <= reach
		end
		local result = { U = lu, V = lv, Time = tHit, Keeper = keeperU(m.Keeper, tHit) }
		if inGoal and not saved then
			result.Result = "goal"
			momentResult(player, session, "GOAL!!!", true, true, false)
		elseif saved then
			result.Result = "saved"
			momentResult(player, session, "Saved by the keeper!", false, false, false)
		else
			result.Result = "miss"
			momentResult(player, session, "Just wide...", false, false, false)
		end
		return result
	end,
	Pass = function(player, session, x, z, power)
		local m = session.Moment
		if not (m and m.Type == "Pass") or m.Passed or m.Done then return { Result = "wait" } end
		if type(x) ~= "number" or type(z) ~= "number" or type(power) ~= "number" or x ~= x or z ~= z or power ~= power then return nil end
		if now() < m.Opens then return { Result = "wait" } end
		m.Passed = true
		local target = m.Teammates[m.Free]
		local success, landing = TrainingService.ResolvePass(player, m.Spot, target, "Dummy", Vector3.new(x, 0, z), math.clamp(power, 0, 1))
		if success then
			local finish = rng:NextNumber() < math.clamp(0.55 + (level(player, "PAS") - session.Opponent) * 0.02, 0.35, 0.85)
			if finish then
				momentResult(player, session, "ASSIST! Your teammate scores!", true, true, false)
			else
				momentResult(player, session, "Great pass! Their keeper saves the shot.", true, false, false)
			end
		else
			local counter = rng:NextNumber() < 0.35
			momentResult(player, session, counter and "Intercepted... and they score!" or "Intercepted!", false, false, counter)
		end
		return { Success = success, Landing = landing }
	end,
	Tackle = function(player, session)
		local m = session.Moment
		if not (m and m.Type == "Defend") or m.Done then return { Result = "wait" } end
		local t = now()
		if t - (session.LastTackle or 0) < DEF.TackleCooldown then return { Result = "wait" } end
		session.LastTackle = t
		local att = TrainingService.TackleCheck(player, session.Attackers, t)
		if not att then return { Result = "miss" } end
		session.Attackers = {}
		StatService.Count(player, "Tackles", 1)
		momentResult(player, session, "What a tackle!", true, false, false)
		return { Result = "stop", Attacker = att.Id }
	end,
}

local function tick(player, session, t)
	local m = session.Moment
	if session.Finished or not m or m.Done then return end
	if m.Type == "Defend" then
		for id, att in pairs(session.Attackers) do
			if DrillMath.AttackerDone(att, t) then
				session.Attackers[id] = nil
				momentResult(player, session, "They score...", false, false, true)
				return
			end
		end
	elseif t > m.Ends then
		momentResult(player, session, m.Type == "Attack" and "Too slow! The chance is gone." or "Too slow! They win the ball.", false, false, false)
	end
end

function MatchService.Init()
	TrainingService.AddKind("Match", start, actions, tick)
end

MatchService.ScoreText = scoreText
return MatchService
