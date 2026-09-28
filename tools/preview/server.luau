-- Runs the real football server against one pretend player and plays every
-- drill like a player would (aiming at targets, running the courses,
-- tackling, pressing in the green), then prints what happened: XP, stats,
-- OVR, and anything that went wrong.
--   DRILLS="Shooting,Passing,Speed,Dribbling,Defending,Gym,Match"
--   SECONDS=40   how long each drill runs

local SECONDS_EACH = SECONDS or 40

-- A clock we move ourselves, and task.delay that waits for it.
CLOCK = 1000
INST.GetServerTimeNow = function() return CLOCK end
INST.GetNetworkPing = function() return 0.06 end
INST.IsStudio = function() return true end
INST.PromptGamePassPurchase = function() end
INST.PromptProductPurchase = function() end
INST.UserOwnsGamePassAsync = function() return false end
INST.BindToClose = function() end
INST.GetFriendsOnline = function() return {} end
INST.GetDataStore = function() error("no DataStore in the preview") end
INST.GetOrderedDataStore = function() error("no DataStore in the preview") end
local timers = {}
task.delay = function(d, fn, ...)
	local args = table.pack(...)
	table.insert(timers, { T = CLOCK + (d or 0), F = fn, A = args })
end
local function fire(inst, name, ...)
	local sigs = rawget(inst, "__signals")
	if sigs[name] then sigs[name]:Fire(...) end
end
local RunService = game:GetService("RunService")
local function advance(dt)
	CLOCK += dt
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].T <= CLOCK then
			table.insert(due, table.remove(timers, i))
		end
	end
	table.sort(due, function(a, b) return a.T < b.T end)
	for _, t in ipairs(due) do
		local ok, err = pcall(t.F, table.unpack(t.A, 1, t.A.n))
		if not ok then print("TIMER ERROR", err) end
	end
	fire(RunService, "Heartbeat", dt)
end

-- What the server tells the client, counted and some of it kept.
local events = {}
local last = {}
INST.FireClient = function(self, who, kind, data)
	local key = self.Name .. ":" .. tostring(kind)
	events[key] = (events[key] or 0) + 1
	last[key] = data
	if self.Name == "Notify" then print("NOTIFY", kind, data) end
	if self.Name == "Progress" and kind == "ovrUp" then print(("  OVR UP %d -> %d  (%s -> %s)"):format(data.Old, data.New, data.OldTier, data.NewTier)) end
	if self.Name == "TrainEvent" and kind == "ended" then print("  ended:", data.Kind, data.Reason, "XP", data.XP) end
end
INST.FireAllClients = function() end

-- The server's own folder.
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")

-- One player.
local Players = game:GetService("Players")
local plr = newInstance("Player")
plr.Name = "Tester"
plr.DisplayName = "Tester"
plr.UserId = 1
plr.Parent = Players
local rig = MockRig(nil)
rig.Name = "Tester"
rig.Parent = workspace
plr.Character = rig
INST.GetPlayers = function(self)
	if self == Players then return { plr } end
	return {}
end
local root = rig:FindFirstChild("HumanoidRootPart")
local hum = rig:FindFirstChildOfClass("Humanoid")

local ok, err = pcall(MODULES.Main)
if not ok then print("MAIN ERROR", err) end
fire(Players, "PlayerAdded", plr)
advance(0.1)

local Config = require("FootballConfig")
local DrillMath = require("DrillMath")
local TrainingService = require("TrainingService")
local DataService = require("DataService")
local StatService = require("StatService")
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local train = Remotes:FindFirstChild("Train")
local request = Remotes:FindFirstChild("Request")
local data = DataService.Get(plr)
print("data loaded", data ~= nil, "OVR", StatService.OVR(data))

local function invoke(...)
	return train.OnServerInvoke(plr, ...)
end

local function moveTo(target, dt)
	-- walk toward a point at the humanoid's speed
	local speed = hum.WalkSpeed
	local pos = root.Position
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if d.Magnitude < 0.01 or speed <= 0 then return true end
	local step = math.min(d.Magnitude, speed * dt)
	root.CFrame = CFrame.new(pos + d.Unit * step)
	return d.Magnitude <= step + 0.01
end

local function stats()
	local parts = {}
	for _, s in ipairs(Config.StatOrder) do table.insert(parts, s .. " " .. data.Stats[s]) end
	return table.concat(parts, "  ") .. "   OVR " .. StatService.OVR(data)
end

local function startAt(id)
	local rec
	for _, child in ipairs(workspace.Map:GetDescendants()) do
		if child.Name == id then rec = child end
	end
	local okStart = TrainingService.Start(plr, id)
	advance(0.05)
	return okStart
end

local drills = {}

-- An auto clicker: clicks the 5 pattern spots in turn, then rests (the
-- drill shoots by itself).
drills.Shooting = function()
	print("-- Shooting (pattern + auto clicker)")
	print("  start", startAt("Lobby_Shooting"))
	local s = TrainingService.Get(plr)
	local rec = s.Station
	local shoot = Config.Drills.Shooting
	local halfW = rec.GoalWidth / 2 - shoot.PatternRadius - 0.3
	local clicks, hits, i = 0, 0, 1
	local t0 = CLOCK
	while CLOCK - t0 < SECONDS_EACH do
		if CLOCK - t0 < SECONDS_EACH / 2 then
			local spot = shoot.Pattern[i]
			local v = math.clamp(spot[2] * rec.GoalHeight, shoot.PatternRadius + 0.3, rec.GoalHeight - shoot.PatternRadius - 0.3)
			local r = invoke("Shoot", spot[1] * halfW, v, 0.5)
			clicks += 1
			if r and (r.Result == "hit" or r.Result == "corner") then hits += 1 end
			i = i % #shoot.Pattern + 1
		end
		advance(0.9)
	end
	print(("  clicks %d, hits %d, all goals %d (the rest by itself)"):format(clicks, hits, s.Goals))
	invoke("Leave")
end

drills.Passing = function()
	print("-- Passing (pattern + auto clicker)")
	print("  start", startAt("Lobby_Passing"))
	local s = TrainingService.Get(plr)
	local rec = s.Station
	local clicks, good, i = 0, 0, 1
	local t0 = CLOCK
	while CLOCK - t0 < SECONDS_EACH do
		if CLOCK - t0 < SECONDS_EACH / 2 then
			local target = rec.Targets[i]
			local r = invoke("Pass", target.Pos.X, target.Pos.Z, 0.5)
			clicks += 1
			if r and r.Success then good += 1 end
			i = i % #rec.Targets + 1
		end
		advance(0.7)
	end
	print(("  clicks %d, good %d, all good passes %d"):format(clicks, good, s.Good))
	invoke("Leave")
end

local function runCourse(id, weave)
	print("  start", startAt(id))
	local s = TrainingService.Get(plr)
	local rec = s.Station
	local t0 = CLOCK
	local runs = 0
	while CLOCK - t0 < SECONDS_EACH and TrainingService.Get(plr) == s do
		-- wait for GO
		while not s.Running and CLOCK - t0 < SECONDS_EACH do advance(0.1) end
		-- follow the checkpoints (for cones: pass on the right side)
		while s.Running and CLOCK - t0 < SECONDS_EACH do
			local check = rec.Checks[s.Next]
			if not check then break end
			local goal = DrillMath.Flat(check.Pos)
			if check.Kind == "Cone" and weave then
				goal = goal + DrillMath.Right(check.Dir) * check.Side * 2.4 + check.Dir * 1.2
			else
				goal = goal + check.Dir * 1.5
			end
			local arrived = false
			local guard = 0
			while not arrived and s.Running and guard < 400 do
				arrived = moveTo(goal, 0.05)
				advance(0.05)
				guard += 1
			end
		end
		runs += 1
		advance(3)
	end
	print("  runs", runs, "best", s.BestTime, "last", last["TrainEvent:runDone"] and last["TrainEvent:runDone"].Time,
		last["TrainEvent:runDone"] and last["TrainEvent:runDone"].Rejected, "penalty", last["TrainEvent:runDone"] and last["TrainEvent:runDone"].Penalty)
	invoke("Leave")
end

drills.Speed = function()
	print("-- Speed Course (auto run)")
	print("  start", startAt("Lobby_Speed"))
	local s = TrainingService.Get(plr)
	local path = s.Station.Path
	local i, t0 = 1, CLOCK
	-- follow the path like the player's screen does
	while CLOCK - t0 < SECONDS_EACH and TrainingService.Get(plr) == s do
		if moveTo(path[i], 0.05) then i = i % #path + 1 end
		advance(0.05)
	end
	print("  speed", s.Speed, "laps", s.Laps, "best lap", s.BestTime)
	invoke("Leave")
end

drills.Dribbling = function()
	print("-- Dribbling (auto)")
	print("  start", startAt("Lobby_Dribbling"))
	local s = TrainingService.Get(plr)
	local path = s.Station.AutoPath
	local i, t0 = 2, CLOCK
	while CLOCK - t0 < SECONDS_EACH and TrainingService.Get(plr) == s do
		if moveTo(path[i], 0.05) then i = i % #path + 1 end
		advance(0.05)
	end
	print("  speed", s.Speed)
	invoke("Leave")
end

drills.Defending = function()
	print("-- Defending (pattern: click, then rest)")
	print("  start", startAt("Lobby_Defending"))
	local s = TrainingService.Get(plr)
	local t0 = CLOCK
	local tackles = 0
	while CLOCK - t0 < SECONDS_EACH and TrainingService.Get(plr) == s do
		if CLOCK - t0 < SECONDS_EACH / 2 then
			local r = invoke("Tackle")
			if r and r.Result == "stop" then tackles += 1 end
		end
		advance(0.4)
	end
	print("  clicked tackles", tackles, "all tackles", s.Stops, "lives", s.Lives)
	invoke("Leave")
end

drills.Gym = function()
	print("-- Gym (click to lift)")
	print("  start", startAt("Lobby_Gym_Squat"))
	local s = TrainingService.Get(plr)
	local t0 = CLOCK
	local clicks = 0
	-- click for half the time, then rest (it lifts by itself)
	while CLOCK - t0 < SECONDS_EACH do
		if CLOCK - t0 < SECONDS_EACH / 2 then
			local r = invoke("Lift")
			if r and r.Result == "lift" then clicks += 1 end
		end
		advance(0.1)
	end
	print("  clicked lifts", clicks, "all lifts", s.Lifts)
	invoke("Leave")
end

drills.Match = function()
	print("-- Match")
	for _, stat in ipairs(Config.StatOrder) do data.Stats[stat] = 78 end
	StatService.Sync(plr)
	print("  start", startAt("Stadium_Match"))
	local s = TrainingService.Get(plr)
	local t0 = CLOCK
	while CLOCK - t0 < 120 and TrainingService.Get(plr) == s do
		local m = s.Moment
		if m and not m.Done and CLOCK >= (m.Opens or 0) then
			if m.Type == "Attack" and not m.Shot then
				invoke("Shoot", (m.Keeper and -math.sign(math.sin(m.Keeper.Freq * (CLOCK - m.Keeper.T0) + m.Keeper.Phase)) * 9) or 9, 3, 0.77)
			elseif m.Type == "Pass" and not m.Passed then
				local target = m.Teammates[m.Free]
				invoke("Pass", target.X, target.Z, (DrillMath.Flat(target) - DrillMath.Flat(m.Spot)).Magnitude / Config.Drills.Passing.MaxDistance)
			elseif m.Type == "Defend" then
				local att = s.Attackers and next(s.Attackers) and s.Attackers[next(s.Attackers)]
				if att and CLOCK >= att.T0 then
					local p = DrillMath.AttackerPos(att, CLOCK)
					moveTo(p, 0.05)
					if (DrillMath.Flat(p) - DrillMath.Flat(root.Position)).Magnitude < 4 then invoke("Tackle") end
				end
			end
		end
		advance(0.05)
	end
	local e = last["TrainEvent:matchEnd"]
	print("  match:", e and (e.Result .. " " .. e.Us .. "-" .. e.Them .. " XP " .. e.XP) or "no result")
end

for name in string.gmatch(DRILLS or "Shooting,Passing,Speed,Dribbling,Defending,Gym,Match", "[^,]+") do
	local before = data.TotalXP
	local okDrill, errDrill = pcall(drills[name])
	if not okDrill then print("DRILL ERROR", name, errDrill) end
	print(("  XP gained %d   now: %s"):format(data.TotalXP - before, stats()))
end

-- menus (the server wants a moment between requests)
local function pause() local t = os.clock() while os.clock() - t < 0.17 do end end
print("-- Requests")
pause()
print("  daily", request.OnServerInvoke(plr, "ClaimDaily"))
pause()
print("  quest Goals", request.OnServerInvoke(plr, "ClaimQuest", "Goals"))
pause()
print("  position CB", request.OnServerInvoke(plr, "SetPosition", "CB"))
pause()
print("  season (too early)", request.OnServerInvoke(plr, "NewSeason"))
pause()
print("  buy 2x", request.OnServerInvoke(plr, "BuyPass", "DoubleXP"))
pause()
print("  buy stat point SHO", request.OnServerInvoke(plr, "BuyProduct", "StatPoint", "SHO"))
pause()
print("  equip neon", request.OnServerInvoke(plr, "Equip", "Border_Neon"))
print("  final", stats(), "Position", data.Position, "Boost left", data.Boost - os.time())
local counts = {}
for k, v in pairs(events) do table.insert(counts, k .. "=" .. v) end
table.sort(counts)
print("events:", table.concat(counts, " "))
