-- The six drills, run on the server. The client draws them and sends what
-- the player did (a shot's aim and power, a pass, a tackle, a press); the
-- server decides what happened and hands out the XP. Runs are timed from the
-- server's own view of the character, with checks that the time is possible.
--
-- A session starts at a station's START prompt and lasts until the player
-- leaves (the LEAVE button, walking off, or dying).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local DrillMath = require(ReplicatedStorage:WaitForChild("DrillMath"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))

local TrainingService = {}

local TrainEvent, Notify
local stations = {}
local sessions = {}
local rng = Random.new(os.time() % 100000 + 17)
local lastAFK = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
end

local function statLevel(player, stat)
	local data = DataService.Get(player)
	return data and data.Stats[stat] or Config.StartLevel
end

local function progress(player, session)
	return math.clamp(Config.Progress(statLevel(player, session.Stat)) + session.Difficulty, 0, 1)
end

-- XP for a drill action: base x level bonus, then StatService adds the rest.
local function reward(player, session, base, stat)
	stat = stat or session.Stat
	local amount = base * Config.LevelBonus(statLevel(player, stat))
	local gained = StatService.AddXP(player, stat, amount, session.Mult)
	session.XP += gained
	return gained
end

local function send(player, kind, payload)
	TrainEvent:FireClient(player, kind, payload or {})
end

local function freeze(player, on)
	local _, humanoid = rootOf(player)
	StatService.SetBusy(player, on)
	if humanoid and on then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

local function placeAt(player, cf)
	local root = rootOf(player)
	if root then
		player.Character:PivotTo(cf)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

--------------------------------------------------------------------------------
-- Session start and end
--------------------------------------------------------------------------------

local starters = {}
local actions = {}
local ticks = {}

function TrainingService.Get(player)
	return sessions[player]
end

function TrainingService.End(player, reason)
	local session = sessions[player]
	if not session then return end
	sessions[player] = nil
	if session.Cleanup then session.Cleanup(session) end
	StatService.SetBusy(player, false)
	local _, humanoid = rootOf(player)
	if humanoid then humanoid.JumpPower = Config.Speed.JumpPower end
	StatService.Count(player, "Sessions", 1)
	send(player, "ended", {
		Kind = session.Kind, Reason = reason, XP = session.XP, Summary = session.Summary and session.Summary(session) or nil,
	})
end

function TrainingService.Start(player, stationId)
	local rec = stations[stationId]
	local data = DataService.Get(player)
	if not (rec and data) then return false end
	local root, humanoid = rootOf(player)
	if not (root and humanoid and humanoid.Health > 0) then return false end
	local current = sessions[player]
	if current then
		if current.Station == rec then return false end
		TrainingService.End(player, "switch")
	end
	local area = Config.Areas[rec.Area] or Config.Areas.Lobby
	local ovr = StatService.OVR(data)
	if area.NeedOVR and ovr < area.NeedOVR then
		Notify:FireClient(player, ("You need %d OVR for the %s."):format(area.NeedOVR, area.Title), "error")
		return false
	end
	if area.VIP and not StatService.HasPass(player, "VIP") then
		Notify:FireClient(player, "The VIP lounge needs the VIP Training pass.", "error")
		return false
	end
	local kind = rec.Kind
	local drill = Config.Drills[kind]
	local session = {
		Player = player, Kind = kind, Station = rec, Stat = drill.Stat, Area = rec.Area,
		Mult = area.Mult or 1, Difficulty = area.Difficulty or 0, Started = now(), XP = 0, LastAction = now(),
	}
	sessions[player] = session
	local ok, err = pcall(starters[kind], player, session)
	if not ok then
		warn("[Training] start failed:", err)
		sessions[player] = nil
		StatService.SetBusy(player, false)
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Shooting
--------------------------------------------------------------------------------

local SHOOT = Config.Drills.Shooting

local function newTarget(session, corner)
	local p = progress(session.Player, session)
	local rec = session.Station
	local r = Config.Lerp(SHOOT.RadiusEasy, SHOOT.RadiusHard, p)
	local halfW = rec.GoalWidth / 2 - r - 0.3
	local target = { Id = session.NextId, R = r, T0 = now(), Phase = rng:NextNumber() * math.pi * 2, Corner = corner }
	session.NextId += 1
	if corner then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		target.U0 = side * halfW
		target.V0 = rec.GoalHeight - r - 0.3
		target.AU, target.AV, target.W = 0, 0, 0
		target.Expires = now() + SHOOT.TopCornerLife
	else
		local move = Config.Lerp(SHOOT.MoveEasy, SHOOT.MoveHard, p)
		target.AU = math.min(move, halfW * 0.8)
		target.AV = math.min(move * 0.3, (rec.GoalHeight - 2 * r) / 2 * 0.8)
		target.U0 = (rng:NextNumber() * 2 - 1) * (halfW - target.AU)
		local vRoom = rec.GoalHeight - 2 * r - 0.6 - 2 * target.AV
		target.V0 = r + 0.3 + target.AV + rng:NextNumber() * math.max(0, vRoom)
		target.W = Config.Lerp(SHOOT.SpeedEasy, SHOOT.SpeedHard, p)
	end
	return target
end

local function refillTargets(session)
	local changed = false
	-- one ordinary target always, and sometimes a top corner one
	local ordinary, corner = 0, 0
	for _, t in pairs(session.Targets) do
		if t.Corner then corner += 1 else ordinary += 1 end
	end
	if ordinary == 0 then
		local t = newTarget(session, false)
		session.Targets[t.Id] = t
		changed = true
	end
	if corner == 0 and rng:NextNumber() < SHOOT.TopCornerChance then
		local t = newTarget(session, true)
		session.Targets[t.Id] = t
		changed = true
	end
	return changed
end

local function targetList(session)
	local list = {}
	for _, t in pairs(session.Targets) do table.insert(list, t) end
	return list
end

starters.Shooting = function(player, session)
	local rec = session.Station
	freeze(player, true)
	local goalMid = DrillMath.GoalPoint(rec.Goal, 0, 0)
	placeAt(player, CFrame.lookAt(rec.Spot + Vector3.new(0, 3, 0) + DrillMath.Flat(rec.Spot - goalMid).Unit * 2, Vector3.new(goalMid.X, rec.Spot.Y + 3, goalMid.Z)))
	session.Targets = {}
	session.NextId = 1
	session.Streak, session.BestStreak, session.Goals, session.Shots = 0, 0, 0, 0
	session.FireUntil = 0
	session.LastShot = 0
	refillTargets(session)
	session.Summary = function(s) return { Goals = s.Goals, Shots = s.Shots, BestStreak = s.BestStreak } end
	send(player, "start", {
		Kind = "Shooting", Station = rec.Id, Spot = rec.Spot, Goal = rec.Goal, GoalWidth = rec.GoalWidth, GoalHeight = rec.GoalHeight,
		Targets = targetList(session), Green = { SHOOT.GreenFrom, SHOOT.GreenTo }, Stat = "SHO", Area = rec.Area,
	})
end

-- The shot itself, shared with the stadium (keeper = nil here).
function TrainingService.ResolveShot(player, session, u, v, power, goalWidth, goalHeight)
	local p = Config.Progress(statLevel(player, "SHO"))
	local spread = Config.Lerp(SHOOT.SpreadEasy, SHOOT.SpreadHard, p)
	local lu, lv = DrillMath.ShotLanding(u, v, power, spread, { SHOOT.GreenFrom, SHOOT.GreenTo }, rng)
	local inGoal = math.abs(lu) <= goalWidth / 2 - 0.35 and lv >= 0.2 and lv <= goalHeight - 0.35
	return lu, lv, inGoal
end

actions.Shooting = {
	Shoot = function(player, session, u, v, power)
		if type(u) ~= "number" or type(v) ~= "number" or type(power) ~= "number" then return nil end
		if u ~= u or v ~= v or power ~= power then return nil end
		local t = now()
		if t - session.LastShot < SHOOT.ShotCooldown then return { Result = "wait" } end
		session.LastShot = t
		session.LastAction = t
		session.Shots += 1
		local rec = session.Station
		u = math.clamp(u, -rec.GoalWidth, rec.GoalWidth)
		v = math.clamp(v, 0, rec.GoalHeight * 2)
		power = math.clamp(power, 0, 1)
		local lu, lv, inGoal = TrainingService.ResolveShot(player, session, u, v, power, rec.GoalWidth, rec.GoalHeight)
		local tHit = t + SHOOT.FlightTime
		local hit
		if inGoal then
			for _, target in pairs(session.Targets) do
				local tu, tv = DrillMath.TargetPos(target, tHit)
				if math.sqrt((lu - tu) ^ 2 + (lv - tv) ^ 2) <= target.R + 0.4 then
					hit = target
					break
				end
			end
		end
		local result = { U = lu, V = lv, Time = tHit, XP = 0 }
		if hit then
			session.Streak += 1
			session.BestStreak = math.max(session.BestStreak, session.Streak)
			session.Goals += 1
			local fire = t < session.FireUntil
			local base = SHOOT.HitXP * (hit.Corner and SHOOT.TopCornerBonus or 1) * (fire and SHOOT.FireMultiplier or 1)
			result.XP = reward(player, session, base)
			result.Result = hit.Corner and "corner" or "hit"
			result.Target = hit.Id
			StatService.Count(player, "Goals", 1)
			if hit.Corner then StatService.Count(player, "TopCorners", 1) end
			if session.Streak % SHOOT.StreakForFire == 0 then
				session.FireUntil = t + SHOOT.FireSeconds
				result.OnFire = true
			end
			session.Targets[hit.Id] = nil
			refillTargets(session)
			result.Targets = targetList(session)
		elseif inGoal then
			session.Streak = 0
			result.Result = "goal"
			result.XP = reward(player, session, SHOOT.OnTargetXP)
		else
			session.Streak = 0
			result.Result = "miss"
		end
		result.Streak = session.Streak
		result.FireUntil = session.FireUntil
		return result
	end,
}

ticks.Shooting = function(player, session, t)
	local changed = false
	for id, target in pairs(session.Targets) do
		if target.Expires and t > target.Expires then
			session.Targets[id] = nil
			changed = true
		end
	end
	if changed then
		refillTargets(session)
		send(player, "targets", { Targets = targetList(session) })
	end
	if t - session.LastAction > SHOOT.IdleEnd then TrainingService.End(player, "idle") end
end

--------------------------------------------------------------------------------
-- Passing
--------------------------------------------------------------------------------

local PASS = Config.Drills.Passing

local function lightNext(session, delay)
	local rec = session.Station
	local choices = {}
	for _, target in ipairs(rec.Targets) do
		if not (session.Lit and session.Lit.Id == target.Id) then
			local ring = target.Kind == "Ring"
			if not ring or rng:NextNumber() < PASS.RingChance * 2 then table.insert(choices, target) end
		end
	end
	if #choices == 0 then choices = rec.Targets end
	local target = choices[rng:NextInteger(1, #choices)]
	local p = progress(session.Player, session)
	local since = now() + (delay or PASS.NextDelay)
	session.Lit = { Id = target.Id, Since = since, Expires = since + PASS.TargetLife * (1 - 0.35 * p) }
	return session.Lit
end

starters.Passing = function(player, session)
	local rec = session.Station
	freeze(player, true)
	local forward = DrillMath.Flat(rec.Facing.LookVector).Unit
	placeAt(player, CFrame.lookAt(rec.Spot + Vector3.new(0, 3, 0) - forward * 2, rec.Spot + Vector3.new(0, 3, 0) + forward * 10))
	session.LastPass = 0
	session.Good, session.Passes = 0, 0
	lightNext(session, 1.2)
	session.Summary = function(s) return { Good = s.Good, Passes = s.Passes } end
	local targets = {}
	for _, target in ipairs(rec.Targets) do
		table.insert(targets, { Id = target.Id, Kind = target.Kind, Pos = target.Pos, Center = target.Center, Model = target.Model })
	end
	send(player, "start", {
		Kind = "Passing", Station = rec.Id, Spot = rec.Spot, Facing = rec.Facing, Targets = targets, Lit = session.Lit,
		MaxDistance = PASS.MaxDistance, Stat = "PAS", Area = rec.Area,
	})
end

function TrainingService.ResolvePass(player, spot, targetPos, kind, aim, power)
	local p = Config.Progress(statLevel(player, "PAS"))
	local sideSd = Config.Lerp(PASS.LateralEasy, PASS.LateralHard, p)
	local lengthSd = Config.Lerp(PASS.LengthEasy, PASS.LengthHard, p)
	local landing = DrillMath.PassLanding(spot, aim, power, PASS.MaxDistance, sideSd, lengthSd, rng)
	local lengthErr, sideErr = DrillMath.PassError(spot, targetPos, landing)
	local width = kind == "Ring" and PASS.RingWidth or PASS.DummyWidth
	local depth = kind == "Ring" and PASS.RingDepth or PASS.DummyDepth
	local success = math.abs(sideErr) <= width and math.abs(lengthErr) <= depth
	local accuracy = math.clamp(1 - 0.5 * math.abs(sideErr) / width - 0.5 * math.abs(lengthErr) / depth, 0, 1)
	return success, landing, accuracy
end

actions.Passing = {
	Pass = function(player, session, x, z, power)
		if type(x) ~= "number" or type(z) ~= "number" or type(power) ~= "number" then return nil end
		if x ~= x or z ~= z or power ~= power then return nil end
		local t = now()
		if t - session.LastPass < PASS.PassCooldown then return { Result = "wait" } end
		local lit = session.Lit
		if not lit or t < lit.Since - 0.15 then return { Result = "wait" } end
		session.LastPass = t
		session.LastAction = t
		session.Passes += 1
		local rec = session.Station
		local target
		for _, tgt in ipairs(rec.Targets) do
			if tgt.Id == lit.Id then target = tgt end
		end
		local success, landing, accuracy = TrainingService.ResolvePass(player, rec.Spot, target.Pos, target.Kind,
			Vector3.new(x, 0, z), math.clamp(power, 0, 1))
		local result = { Success = success, Landing = landing, Target = target.Id, XP = 0 }
		if success then
			local reaction = t - lit.Since
			local speed
			if reaction <= PASS.QuickTime then
				speed = 1.3
			elseif reaction >= PASS.SlowTime then
				speed = 0.75
			else
				speed = 1.3 - 0.55 * (reaction - PASS.QuickTime) / (PASS.SlowTime - PASS.QuickTime)
			end
			local base = PASS.PassXP * (0.7 + 0.6 * accuracy) * speed * (target.Kind == "Ring" and PASS.RingBonus or 1)
			result.XP = reward(player, session, base)
			result.Quick = reaction <= PASS.QuickTime
			session.Good += 1
			StatService.Count(player, "Passes", 1)
		end
		result.Next = lightNext(session)
		return result
	end,
}

ticks.Passing = function(player, session, t)
	if session.Lit and t > session.Lit.Expires then
		send(player, "lit", { Lit = lightNext(session), Missed = true })
	end
	if t - session.LastAction > PASS.IdleEnd then TrainingService.End(player, "idle") end
end

--------------------------------------------------------------------------------
-- Courses: the Speed Course and the Dribbling Cones
--------------------------------------------------------------------------------

local function beginRun(player, session)
	local rec = session.Station
	local drill = Config.Drills[session.Kind]
	freeze(player, true)
	placeAt(player, rec.Start)
	session.GoAt = now() + drill.Countdown
	session.Next = 1
	session.Prev = nil
	session.Penalty = 0
	session.Touched = {}
	session.Touches, session.Misses = 0, 0
	session.Running = false
	session.Done = false
	send(player, "run", { GoAt = session.GoAt })
end

local function courseSpeed(player, session)
	if session.Kind == "Dribbling" then return Config.DribbleSpeed(statLevel(player, "DRI")) end
	return Config.TrackSpeed(statLevel(player, "PAC"))
end

local function startCourse(player, session)
	local rec = session.Station
	if not rec.MinLength then
		local length, from = 0, DrillMath.Flat(rec.Start.Position)
		for _, check in ipairs(rec.Checks) do
			local to = DrillMath.Flat(check.Pos)
			length += (to - from).Magnitude
			from = to
		end
		rec.MinLength = length
	end
	session.Runs, session.BestTime = 0, nil
	session.Summary = function(s) return { Runs = s.Runs, Best = s.BestTime } end
	send(player, "start", {
		Kind = session.Kind, Station = rec.Id, Start = rec.Start, Checks = rec.Checks, Cones = rec.Cones, Length = rec.Length,
		Stat = session.Stat, Area = rec.Area, Lobby = rec.Id == "Lobby_Speed",
		Auto = session.Kind == "Speed" and Config.Drills.Speed.Auto or nil,
	})
	beginRun(player, session)
end
starters.Speed = startCourse
starters.Dribbling = startCourse

local function finishRun(player, session, t)
	local drill = Config.Drills[session.Kind]
	local rec = session.Station
	local raw = t - session.GoAt
	local speed = session.Speed
	-- the shortest way through every checkpoint, run flat out
	local fastest = rec.MinLength / (speed * drill.Slack)
	session.Running = false
	session.Done = true
	freeze(player, true)
	if raw < fastest then
		send(player, "runDone", { Rejected = true, Time = raw })
	else
		local time = raw + session.Penalty
		local par = rec.Length / speed * (session.Kind == "Speed" and 1.12 or 1.15)
		local factor = math.clamp(par / time, 0.5, drill.MaxFactor)
		local perfect = session.Kind == "Dribbling" and session.Touches == 0 and session.Misses == 0
		local base = drill.BaseXP * factor * (perfect and drill.PerfectBonus or 1)
		local xp = reward(player, session, base)
		session.Runs += 1
		local best = session.BestTime == nil or time < session.BestTime
		if best then session.BestTime = time end
		local record = false
		if session.Kind == "Speed" and rec.Id == "Lobby_Speed" then
			local data = DataService.Get(player)
			local old = data and data.Counters.SpeedBest or 0
			record = old == 0 or time < old
			StatService.Count(player, "SpeedBest", math.floor(time * 100 + 0.5) / 100, "min")
			StatService.Count(player, "SpeedRuns", 1)
			StatService.Sync(player)
		end
		if perfect then StatService.Count(player, "PerfectRuns", 1) end
		send(player, "runDone", {
			Time = time, Raw = raw, Penalty = session.Penalty, XP = xp, Perfect = perfect, Touches = session.Touches,
			Misses = session.Misses, Best = session.BestTime, Record = record,
		})
	end
	task.delay(2.6, function()
		if sessions[player] == session then beginRun(player, session) end
	end)
end

local function tickCourse(player, session, t)
	local rec = session.Station
	local drill = Config.Drills[session.Kind]
	local root, humanoid = rootOf(player)
	if not (root and humanoid) then return end
	if session.Done then return end
	if not session.Running then
		if t >= session.GoAt then
			session.Running = true
			session.Speed = courseSpeed(player, session)
			humanoid.WalkSpeed = session.Speed
			session.LastAction = t
		end
		return
	end
	local pos = DrillMath.Flat(root.Position)
	-- walked away from the course
	if (pos - DrillMath.Flat(rec.Center)).Magnitude > rec.Extent then
		TrainingService.End(player, "left")
		return
	end
	if t - session.GoAt > drill.Timeout then
		send(player, "runDone", { TimedOut = true })
		session.Done = true
		task.delay(1.5, function()
			if sessions[player] == session then beginRun(player, session) end
		end)
		return
	end
	-- cones touched
	if rec.Cones then
		for i, conePos in ipairs(rec.Cones) do
			if not session.Touched[i] and (pos - DrillMath.Flat(conePos)).Magnitude < drill.ConeRadius then
				session.Touched[i] = true
				session.Touches += 1
				session.Penalty += drill.TouchPenalty
				send(player, "cone", { Index = i, Touch = true, Penalty = session.Penalty })
			end
		end
	end
	-- the next checkpoint: crossed when you go from behind it to past it
	local check = rec.Checks[session.Next]
	if not check then return end
	local rel = pos - DrillMath.Flat(check.Pos)
	local along = rel:Dot(check.Dir)
	local side = rel:Dot(DrillMath.Right(check.Dir))
	local before = session.Prev
	session.Prev = along
	if before == nil or not (before < 0 and along >= 0) then return end
	if check.Kind == "Cone" then
		if math.abs(side) > 9 then
			session.Prev = nil
			return
		end
		local good = (side >= 0 and 1 or -1) == check.Side
		if not good then
			session.Misses += 1
			session.Penalty += drill.MissPenalty
		end
		send(player, "check", { Index = session.Next, Good = good, Penalty = session.Penalty })
	else
		if math.abs(side) > (check.Width or 8) then
			session.Prev = along -- went round it: come back through
			return
		end
		send(player, "check", { Index = session.Next, Good = true, Penalty = session.Penalty })
	end
	session.Next += 1
	session.Prev = nil
	if session.Next > #rec.Checks then finishRun(player, session, t) end
end
ticks.Speed = tickCourse
ticks.Dribbling = tickCourse
actions.Speed = {}
actions.Dribbling = {}

--------------------------------------------------------------------------------
-- Defending: the Tackle Zone
--------------------------------------------------------------------------------

local DEF = Config.Drills.Defending

local function spawnWave(player, session)
	local rec = session.Station
	session.Wave += 1
	session.WaveGoals = 0
	local count = math.min(1 + (session.Wave - 1) // 2, 4)
	local speed = math.min(DEF.SpeedStart + session.Wave * DEF.SpeedPerWave + session.Difficulty * 6, DEF.SpeedMax)
	local line = rec.GoalLine
	local list = {}
	for k = 1, count do
		local startSide = (rng:NextNumber() * 2 - 1) * (rec.Width / 2 - 4)
		local endSide = (rng:NextNumber() * 2 - 1) * (rec.Width / 2 - 7)
		local startPos = (line * CFrame.new(startSide, 0, -rec.Length)).Position
		local endPos = (line * CFrame.new(endSide, 0, 0)).Position
		local att = {
			Id = session.NextId, Start = startPos, End = endPos, T0 = now() + 1 + (k - 1) * 1.3,
			Duration = (endPos - startPos).Magnitude / speed, Amp = DEF.ZigZag * (0.5 + rng:NextNumber() * 0.5),
			Freq = 1.2 + rng:NextNumber() * 0.9,
		}
		session.NextId += 1
		session.Attackers[att.Id] = att
		table.insert(list, att)
	end
	send(player, "wave", { Wave = session.Wave, Attackers = list, Lives = session.Lives })
end

starters.Defending = function(player, session)
	local rec = session.Station
	StatService.SetBusy(player, true)
	local _, humanoid = rootOf(player)
	if humanoid then
		humanoid.WalkSpeed = Config.WalkSpeed(statLevel(player, "PAC")) + 2
		humanoid.JumpPower = Config.Speed.JumpPower
	end
	placeAt(player, rec.Start)
	session.Attackers = {}
	session.NextId = 1
	session.Wave = 0
	session.Lives = DEF.Lives
	session.Stops = 0
	session.LastTackle = 0
	session.NextWaveAt = now() + 2
	session.Summary = function(s) return { Waves = s.Wave, Stops = s.Stops } end
	send(player, "start", {
		Kind = "Defending", Station = rec.Id, GoalLine = rec.GoalLine, Length = rec.Length, Width = rec.Width, Lives = session.Lives,
		Stat = "DEF", Area = rec.Area,
	})
end

-- The attacker a tackle reaches, if any (shared with the stadium).
function TrainingService.TackleCheck(player, attackers, t)
	local root = rootOf(player)
	if not root then return nil end
	local reach = DEF.Reach + DEF.ReachPerLevel * math.max(0, statLevel(player, "DEF") - Config.StartLevel)
	local ping = math.clamp(player:GetNetworkPing() or 0, 0, 0.4)
	local pos = DrillMath.Flat(root.Position)
	local best, bestDist = nil, math.huge
	for _, att in pairs(attackers) do
		if t >= att.T0 - 0.2 and not DrillMath.AttackerDone(att, t) then
			for _, back in ipairs({ 0, ping * 0.5, ping }) do
				local d = (DrillMath.Flat(DrillMath.AttackerPos(att, t - back)) - pos).Magnitude
				if d < bestDist then best, bestDist = att, d end
			end
		end
	end
	if best and bestDist <= reach then return best end
	return nil
end

actions.Defending = {
	Tackle = function(player, session)
		local t = now()
		if t - session.LastTackle < DEF.TackleCooldown then return { Result = "wait" } end
		session.LastTackle = t
		session.LastAction = t
		local att = TrainingService.TackleCheck(player, session.Attackers, t)
		if not att then return { Result = "miss" } end
		session.Attackers[att.Id] = nil
		session.Stops += 1
		StatService.Count(player, "Tackles", 1)
		local xp = reward(player, session, DEF.StopXP * (1 + 0.08 * (session.Wave - 1)))
		return { Result = "stop", Attacker = att.Id, XP = xp }
	end,
}

ticks.Defending = function(player, session, t)
	local rec = session.Station
	local root = rootOf(player)
	if root and (DrillMath.Flat(root.Position) - DrillMath.Flat((rec.GoalLine * CFrame.new(0, 0, -rec.Length / 2)).Position)).Magnitude > rec.Length then
		TrainingService.End(player, "left")
		return
	end
	local left = 0
	for id, att in pairs(session.Attackers) do
		if DrillMath.AttackerDone(att, t) then
			session.Attackers[id] = nil
			session.Lives -= 1
			session.WaveGoals += 1
			send(player, "goalAgainst", { Attacker = id, Lives = session.Lives })
			if session.Lives <= 0 then
				TrainingService.End(player, "lives")
				return
			end
		else
			left += 1
		end
	end
	if session.Wave > 0 and left == 0 and not session.NextWaveAt then
		if session.WaveGoals == 0 then
			local xp = reward(player, session, DEF.WaveBonus * session.Wave)
			send(player, "waveClear", { Wave = session.Wave, XP = xp })
		end
		session.NextWaveAt = t + DEF.WaveGap
	end
	if session.NextWaveAt and t >= session.NextWaveAt then
		session.NextWaveAt = nil
		spawnWave(player, session)
	end
end

--------------------------------------------------------------------------------
-- Gym
--------------------------------------------------------------------------------

local GYM = Config.Drills.Gym

local function newRep(session, delay)
	local p = progress(session.Player, session)
	local index = session.Rep
	local period = Config.Lerp(GYM.PeriodStart, GYM.PeriodEnd, (index - 1) / math.max(1, GYM.Reps - 1)) * (1 - 0.15 * p)
	local width = Config.Lerp(GYM.ZoneEasy, GYM.ZoneHard, p)
	local center = 0.3 + rng:NextNumber() * 0.5
	session.RepData = {
		Index = index, Start = now() + (delay or 0.5), Period = period, Center = center, Width = width, Perfect = GYM.Perfect, Pressed = false,
	}
	return session.RepData
end

-- Where the body goes on each machine (everyone sees it; the lifting itself
-- is drawn on the player's own screen, TrainingClient):
--   Squat  standing under the bar, facing out
--   Bench  lying on the bench, head under the bar
--   Sled   behind the sled, facing it
local function gymPose(player, rec)
	local root, humanoid = rootOf(player)
	if not (root and humanoid) then return rec.Facing + Vector3.new(0, 3, 0) end
	-- the machine's own frame (StationBuilder.Gym): the spot is 3.5 in front
	-- of it, and its front (where the camera is) is +Z
	local mcf = CFrame.lookAt(rec.Spot, rec.Spot - rec.Facing.LookVector) * CFrame.new(0, 0, -3.5)
	local stand = humanoid.HipHeight + root.Size.Y / 2 + 0.25
	if rec.Machine == "Bench" then
		local pos = (mcf * CFrame.new(0, 1.6 + root.Size.Z / 2 + 0.05, 0.1)).Position
		local up = -mcf.LookVector            -- head toward the bar
		local back = Vector3.new(0, -1, 0)    -- lying on the back, face up
		local right = up:Cross(back)
		return CFrame.fromMatrix(pos, right, up)
	elseif rec.Machine == "Sled" then
		local pos = (mcf * CFrame.new(0, stand, 0.9)).Position
		return CFrame.lookAt(pos, pos + mcf.LookVector)
	end
	local pos = (mcf * CFrame.new(0, stand, 0.9)).Position
	return CFrame.lookAt(pos, pos - mcf.LookVector)
end

starters.Gym = function(player, session)
	local rec = session.Station
	freeze(player, true)
	local root = rootOf(player)
	placeAt(player, gymPose(player, rec))
	if root then
		root.Anchored = true
		session.Cleanup = function()
			if root.Parent then
				root.Anchored = false
				placeAt(player, rec.Facing + Vector3.new(0, 3, 0))
			end
		end
	end
	session.Rep = 1
	session.Set, session.GoodInSet = 1, 0
	session.Good, session.Perfects = 0, 0
	session.Summary = function(s) return { Good = s.Good, Perfects = s.Perfects, Sets = s.Set - 1 } end
	newRep(session, 1.2)
	send(player, "start", {
		Kind = "Gym", Station = rec.Id, Machine = rec.Machine, Bar = rec.Bar, Camera = rec.Camera, Spot = rec.Spot,
		Rep = session.RepData, Reps = GYM.Reps, Stat = "PHY", Area = rec.Area,
	})
end

local function nextRep(player, session)
	if session.Rep >= GYM.Reps then
		local bonus = session.GoodInSet > 0 and reward(player, session, GYM.SetBonus * session.GoodInSet) or 0
		send(player, "setDone", { Set = session.Set, Good = session.GoodInSet, XP = bonus })
		session.Set += 1
		session.Rep = 1
		session.GoodInSet = 0
		send(player, "rep", { Rep = newRep(session, GYM.RestSeconds) })
	else
		session.Rep += 1
		send(player, "rep", { Rep = newRep(session, 0.45) })
	end
end

actions.Gym = {
	Lift = function(player, session, tPress)
		local rep = session.RepData
		local t = now()
		if not rep or rep.Pressed or t < rep.Start - 0.05 then return { Result = "wait" } end
		local ping = math.clamp(player:GetNetworkPing() or 0, 0, 0.5)
		local guess = t - ping * 0.5
		if type(tPress) ~= "number" or tPress ~= tPress or math.abs(tPress - guess) > GYM.PressWindow + ping * 0.5 then
			tPress = guess
		end
		rep.Pressed = true
		session.LastAction = t
		local m = DrillMath.Marker(rep, tPress)
		local off = math.abs(m - rep.Center)
		local result = { Marker = m, XP = 0 }
		if off <= rep.Perfect / 2 then
			result.Result = "perfect"
			result.XP = reward(player, session, GYM.PerfectXP)
			session.Perfects += 1
			session.Good += 1
			session.GoodInSet += 1
			StatService.Count(player, "PerfectReps", 1)
		elseif off <= rep.Width / 2 then
			result.Result = "good"
			result.XP = reward(player, session, GYM.GoodXP)
			session.Good += 1
			session.GoodInSet += 1
		else
			result.Result = "miss"
		end
		task.defer(nextRep, player, session)
		return result
	end,
}

ticks.Gym = function(player, session, t)
	local rep = session.RepData
	if rep and not rep.Pressed and t > rep.Start + rep.Period * 4 then
		rep.Pressed = true
		send(player, "repMissed", {})
		nextRep(player, session)
	end
	if t - session.LastAction > 45 then TrainingService.End(player, "idle") end
end

--------------------------------------------------------------------------------
-- The stadium match plugs in here (MatchService)
--------------------------------------------------------------------------------

function TrainingService.AddKind(kind, starter, kindActions, tick)
	starters[kind] = starter
	actions[kind] = kindActions
	ticks[kind] = tick
end

TrainingService.Reward = reward
TrainingService.Send = send
TrainingService.Freeze = freeze
TrainingService.PlaceAt = placeAt
TrainingService.Now = now
TrainingService.Rng = rng
TrainingService.StatLevel = statLevel

--------------------------------------------------------------------------------
-- Auto-Train (a pass): XP while standing in the lobby
--------------------------------------------------------------------------------

local function autoTrain(t)
	for _, player in ipairs(Players:GetPlayers()) do
		if not sessions[player] and StatService.HasPass(player, "AutoTrain") then
			local root = rootOf(player)
			local data = DataService.Get(player)
			if root and data and DrillMath.Flat(root.Position).Magnitude <= Config.AutoTrain.Radius then
				if t - (lastAFK[player] or 0) >= Config.AutoTrain.Every then
					lastAFK[player] = t
					-- the lowest stat that is not maxed
					local pick, level = nil, math.huge
					for _, stat in ipairs(Config.StatOrder) do
						if data.Stats[stat] < Config.MaxLevel and data.Stats[stat] < level then pick, level = stat, data.Stats[stat] end
					end
					if pick then
						StatService.AddXP(player, pick, Config.AutoTrain.XP * Config.LevelBonus(level), 1)
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

function TrainingService.Init(remotes, records)
	TrainEvent = remotes.TrainEvent
	Notify = remotes.Notify
	stations = records
	for id, rec in pairs(records) do
		if rec.Prompt then
			rec.Prompt.Triggered:Connect(function(player)
				TrainingService.Start(player, id)
			end)
		end
	end
	remotes.Train.OnServerInvoke = function(player, action, ...)
		if action == "Leave" then
			-- the EXIT button: stop, then stand back on the drill's start pad
			local session = sessions[player]
			local anchor = session and session.Station and session.Station.Prompt and session.Station.Prompt.Parent
			TrainingService.End(player, "leave")
			if anchor and anchor:IsA("BasePart") then
				placeAt(player, CFrame.new(anchor.Position + Vector3.new(0, 1, 0)))
			end
			return true
		end
		local session = sessions[player]
		if not session then return nil end
		local handler = actions[session.Kind] and actions[session.Kind][action]
		if not handler then return nil end
		local ok, result = pcall(handler, player, session, ...)
		if not ok then
			warn("[Training] " .. tostring(action) .. " failed:", result)
			return nil
		end
		return result
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		for player, session in pairs(sessions) do
			if not player.Parent then
				sessions[player] = nil
			else
				local tick = ticks[session.Kind]
				if tick then
					local ok, err = pcall(tick, player, session, t)
					if not ok then warn("[Training] tick failed:", err) end
				end
			end
		end
		accumulator += dt
		if accumulator >= 1 then
			accumulator = 0
			autoTrain(t)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastAFK[player] = nil
	end)
end

-- Dying or resetting ends the drill.
function TrainingService.CharacterAdded(player)
	if sessions[player] then TrainingService.End(player, "respawn") end
end

return TrainingService
