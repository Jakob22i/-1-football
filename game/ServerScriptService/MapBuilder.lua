-- Builds the whole map from code on the empty baseplate:
--
--   the lobby     a small stadium plaza (spawn on the centre spot, stands,
--                 floodlights, leaderboards, the Position Board) with exits
--   the stations  round it: Speed Course (north), Shooting, Passing, the Gym
--                 (south), Dribbling Cones, the Tackle Zone, the VIP lounge
--   east          the academy avenue: PRO (70), ELITE (80), LEGEND (90), each
--                 behind a glowing gate, each with every drill and better XP
--   west          the STADIUM behind the 75 gate, for matches
--
-- Returns the station records (see StationBuilder) and the boards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local MapKit = require(script.Parent:WaitForChild("MapKit"))
local StationBuilder = require(script.Parent:WaitForChild("StationBuilder"))

local part, patch, line, cylinder, ring, disc, ball = MapKit.part, MapKit.patch, MapKit.line, MapKit.cylinder, MapKit.ring, MapKit.disc, MapKit.ball
local COL = MapKit.Colors
local rgb = MapKit.rgb
local V = Vector3.new

local MapBuilder = {}

local PLAZA_RADIUS = 56
local STAND_DEPTH = 13

local STAT_COLOR = {}
for stat, def in pairs(Config.Stats) do STAT_COLOR[stat] = def.Color end

local function dir(deg)
	local a = math.rad(deg)
	return V(math.cos(a), 0, math.sin(a))
end

local function lookOut(pos, deg)
	return CFrame.lookAt(pos, pos + dir(deg))
end

--------------------------------------------------------------------------------
-- Plaza
--------------------------------------------------------------------------------

-- The exits (degrees, 0 = east, 90 = south) and what they lead to.
local EXITS = {
	{ Angle = -90, Label = "SPEED COURSE", Stat = "PAC" },
	{ Angle = -60, Label = "VIP LOUNGE", Color = rgb(255, 200, 40) },
	{ Angle = -30, Label = "SHOOTING", Stat = "SHO" },
	{ Angle = 0, Label = "ACADEMIES", Color = rgb(60, 200, 255) },
	{ Angle = 30, Label = "PASSING", Stat = "PAS" },
	{ Angle = 90, Label = "GYM", Stat = "PHY" },
	{ Angle = 150, Label = "DRIBBLING", Stat = "DRI" },
	{ Angle = 180, Label = "STADIUM", Color = rgb(255, 90, 90) },
	{ Angle = 210, Label = "TACKLE ZONE", Stat = "DEF" },
}
local EXIT_HALF = 8 -- degrees either side of an exit left open

local function buildStands(parent, from, to, colors)
	-- three tiers of steps round an arc, with seats in two colours
	local span = to - from
	local steps = math.max(3, math.floor(span / 4))
	for tier = 0, 2 do
		local radius = PLAZA_RADIUS + 2 + tier * 4 + 2
		local height = 1.6 * (tier + 1)
		for k = 0, steps - 1 do
			local a0 = math.rad(from + span * k / steps)
			local a1 = math.rad(from + span * (k + 1) / steps)
			local am = (a0 + a1) / 2
			local chord = 2 * radius * math.sin((a1 - a0) / 2) + 0.3
			local pos = V(math.cos(am) * radius, height / 2, math.sin(am) * radius)
			local cf = CFrame.lookAt(pos, V(0, height / 2, 0))
			part(parent, "Step", V(chord, height, 4), cf, COL.ConcreteDark, Enum.Material.Concrete)
			-- seats on top
			local seatColor = colors[(k + tier) % 2 + 1]
			part(parent, "Seat", V(chord - 0.8, 0.9, 1.6), cf * CFrame.new(0, height / 2 + 0.45, 0.6), seatColor, Enum.Material.SmoothPlastic)
		end
	end
	-- a back wall
	local wallRadius = PLAZA_RADIUS + STAND_DEPTH + 1
	for k = 0, steps - 1 do
		local a0 = math.rad(from + span * k / steps)
		local a1 = math.rad(from + span * (k + 1) / steps)
		local am = (a0 + a1) / 2
		local chord = 2 * wallRadius * math.sin((a1 - a0) / 2) + 0.4
		local pos = V(math.cos(am) * wallRadius, 3.5, math.sin(am) * wallRadius)
		part(parent, "Wall", V(chord, 7, 1.2), CFrame.lookAt(pos, V(0, 3.5, 0)), COL.Navy, Enum.Material.SmoothPlastic)
	end
end

local function floodlight(parent, at)
	local m = Instance.new("Model")
	m.Name = "Floodlight"
	m.Parent = parent
	cylinder(m, "Pole", 38, 1.4, at, COL.Metal, Enum.Material.Metal)
	local head = CFrame.lookAt(at + V(0, 38, 0), V(0, 0, 0))
	part(m, "Frame", V(9, 5, 1), head, COL.NavyDark)
	for x = -1, 1 do
		for y = 0, 1 do
			local lamp = part(m, "Lamp", V(2.4, 1.8, 0.4), head * CFrame.new(x * 2.8, -1 + y * 2.2, -0.6), rgb(255, 255, 235), Enum.Material.Neon)
			if x == 0 and y == 0 then
				local light = Instance.new("SpotLight")
				light.Angle = 70
				light.Range = 60
				light.Brightness = 2
				light.Face = Enum.NormalId.Front
				light.Parent = lamp
			end
		end
	end
end

-- A leaderboard: a big board on legs with a title and ten rows.
local function leaderboard(parent, name, title, subtitle, cf, color)
	local model, _, gui = MapKit.sign(parent, name, 22, 26, cf, {}, { COL.NavyDark, color }, 4)
	local header = Instance.new("Frame")
	header.Size = UDim2.fromScale(1, 0.16)
	header.BackgroundColor3 = color
	header.BorderSizePixel = 0
	header.Parent = gui
	MapKit.uiText(header, title, 5, COL.White, { Size = UDim2.fromScale(0.94, 0.66), Position = UDim2.fromScale(0.03, 0.04) })
	MapKit.uiText(header, subtitle, 3, COL.White, { Size = UDim2.fromScale(0.94, 0.3), Position = UDim2.fromScale(0.03, 0.68) })
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromScale(0.03, 0.18 + (i - 1) * 0.08)
		row.Size = UDim2.fromScale(0.94, 0.072)
		row.BackgroundColor3 = (i % 2 == 0) and rgb(30, 44, 96) or rgb(22, 34, 78)
		row.BorderSizePixel = 0
		row.Parent = gui
		local rank = MapKit.uiText(row, "#" .. i, 3, i <= 3 and ({ rgb(255, 215, 60), rgb(220, 225, 235), rgb(230, 150, 80) })[i] or COL.White,
			{ Size = UDim2.fromScale(0.14, 0.9), Position = UDim2.fromScale(0.01, 0.05) })
		local who = MapKit.uiText(row, "-", 3, COL.White, { Size = UDim2.fromScale(0.58, 0.8), Position = UDim2.fromScale(0.17, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
		local value = MapKit.uiText(row, "", 3, rgb(255, 225, 90), { Size = UDim2.fromScale(0.24, 0.8), Position = UDim2.fromScale(0.75, 0.1), TextXAlignment = Enum.TextXAlignment.Right })
		rows[i] = { Rank = rank, Name = who, Value = value }
	end
	return { Model = model, Rows = rows }
end

local function buildPlaza(parent)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = parent
	disc(plaza, "Floor", V(0, 0, 0), PLAZA_RADIUS * 2 + 6, COL.Concrete, 0.3, Enum.Material.Concrete)
	-- the centre circle of a pitch in the middle
	disc(plaza, "CentreGrass", V(0, 0.02, 0), 46, COL.Grass, 0.32, Enum.Material.Grass)
	ring(plaza, "CentreLine", V(0, 0, 0), 15, 0.7, COL.Line, 48, 0.36)
	ring(plaza, "Edge", V(0, 0, 0), 23, 0.9, COL.Line, 60, 0.36)
	disc(plaza, "CentreSpot", V(0, 0.05, 0), 2.2, COL.Line, 0.34, Enum.Material.SmoothPlastic)
	-- a halfway line across the grass
	line(plaza, V(-23, 0, 0), V(23, 0, 0), 0.7, 0.37)

	-- the stands between the exits
	local angles = {}
	for _, exit in ipairs(EXITS) do table.insert(angles, exit.Angle) end
	table.sort(angles)
	for i, a in ipairs(angles) do
		local b = angles[i % #angles + 1]
		if b <= a then b += 360 end
		buildStands(plaza, a + EXIT_HALF, b - EXIT_HALF, (i % 2 == 0) and { rgb(40, 120, 255), COL.White } or { rgb(255, 70, 80), COL.White })
	end

	-- floodlights and signposts at the exits
	for _, a in ipairs({ -135, -45, 45, 135 }) do
		floodlight(plaza, dir(a) * (PLAZA_RADIUS + 20))
	end
	for _, exit in ipairs(EXITS) do
		local color = exit.Stat and STAT_COLOR[exit.Stat] or exit.Color
		local pos = dir(exit.Angle) * (PLAZA_RADIUS - 6)
		local cf = CFrame.lookAt(pos, V(0, 0, 0))
		local text = exit.Stat and (Config.Stats[exit.Stat].Icon .. " " .. exit.Label) or exit.Label
		MapKit.sign(plaza, "Signpost", 11, 3.2, cf, {
			{ text, COL.White, 2, 3 },
			{ exit.Stat and ("+ " .. exit.Stat) or "\u{2192}", color, 1.2, 3 },
		}, { COL.NavyDark, color }, 5)
	end

	-- the spawn on the centre spot
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = V(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, 0.2, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plaza
	return plaza
end

--------------------------------------------------------------------------------
-- Paths between places
--------------------------------------------------------------------------------

local function path(parent, a, b, width)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	return part(parent, "Path", V(width or 12, 0.24, length), CFrame.lookAt(V(mid.X, 0.12, mid.Z), V(b.X, 0.12, b.Z)), COL.Path, Enum.Material.Concrete)
end

--------------------------------------------------------------------------------
-- Gates that open at an OVR (or with the VIP pass)
--------------------------------------------------------------------------------

local function gate(parent, name, cf, width, need, title, color, vip)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("NeedOVR", need or 0)
	m:SetAttribute("NeedPass", vip and "VIP" or "")
	m.Parent = parent
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Pillar", V(3, 16, 3), cf * CFrame.new(s * (width / 2 + 1.5), 8, 0), COL.NavyDark)
		part(m, "PillarCap", V(3.6, 1, 3.6), cf * CFrame.new(s * (width / 2 + 1.5), 16.5, 0), color, Enum.Material.Neon)
	end
	part(m, "Beam", V(width + 6, 3, 3), cf * CFrame.new(0, 17.5, 0), COL.NavyDark)
	local barrier = part(m, "Barrier", V(width, 15, 0.6), cf * CFrame.new(0, 7.5, 0), color, Enum.Material.ForceField, { CanCollide = true })
	barrier.Transparency = 0.15
	local text = vip and "VIP ONLY" or (need .. " OVR")
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = MapKit.surface(m:FindFirstChild("Beam"), face, 20)
		MapKit.uiText(gui, title .. "  \u{2022}  " .. text, 3, COL.White, { Size = UDim2.fromScale(0.96, 0.8), Position = UDim2.fromScale(0.02, 0.1) })
	end
	local label = part(m, "Label", V(width - 2, 4, 0.2), cf * CFrame.new(0, 11, 0), COL.White, Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = MapKit.surface(label, face, 20)
		MapKit.uiText(gui, "\u{1F512} " .. text, 3, COL.White, { Name = "Status" })
	end
	return m
end

--------------------------------------------------------------------------------
-- A zone of stations (the lobby ring, or an academy)
--------------------------------------------------------------------------------

local function stationSign(parent, cf, stat, title, area)
	local color = STAT_COLOR[stat]
	local def = Config.Stats[stat]
	local sub = area and area ~= "Lobby" and Config.Areas[area].Title or ("TRAINS " .. def.Name:upper())
	MapKit.sign(parent, "StationSign", 18, 7, cf, {
		{ def.Icon .. " " .. title, COL.White, 2.2, 5 },
		{ "+" .. stat .. "  \u{2022}  " .. sub, color, 1, 4 },
	}, { COL.NavyDark, color }, 6)
end

local function register(records, rec, id, area)
	rec.Id = id
	rec.Area = area
	rec.Model.Name = id
	records[id] = rec
	return rec
end

-- The lobby's six stations round the plaza.
local function buildLobbyStations(parent, records)
	local folder = Instance.new("Folder")
	folder.Name = "Training"
	folder.Parent = parent

	-- Speed Course: an oval to the north
	local speedCenter = V(0, 0, -178)
	local speed = StationBuilder.Speed(folder, CFrame.lookAt(speedCenter, speedCenter + V(1, 0, 0)), { Id = "Lobby_Speed", Color = STAT_COLOR.PAC })
	register(records, speed, "Lobby_Speed", "Lobby")
	stationSign(folder, CFrame.lookAt(V(-24, 0, -140), V(-24, 0, 0)), "PAC", "SPEED COURSE")
	path(folder, dir(-90) * PLAZA_RADIUS, V(0, 0, -142), 12)

	-- Shooting (north-east)
	local shootSpot = dir(-30) * 128
	register(records, StationBuilder.Shooting(folder, lookOut(shootSpot, -30), { Id = "Lobby_Shooting", Color = STAT_COLOR.SHO }), "Lobby_Shooting", "Lobby")
	stationSign(folder, CFrame.lookAt(shootSpot + dir(-30) * -10 + dir(60) * 16, V(0, 0, 0)), "SHO", "SHOOTING PRACTICE")
	path(folder, dir(-30) * PLAZA_RADIUS, shootSpot + dir(-30) * -4, 12)

	-- Passing (south-east)
	local passSpot = dir(30) * 124
	register(records, StationBuilder.Passing(folder, lookOut(passSpot, 30), { Id = "Lobby_Passing", Color = STAT_COLOR.PAS }), "Lobby_Passing", "Lobby")
	stationSign(folder, CFrame.lookAt(passSpot + dir(30) * -10 + dir(120) * 16, V(0, 0, 0)), "PAS", "PASSING DRILL")
	path(folder, dir(30) * PLAZA_RADIUS, passSpot + dir(30) * -4, 12)

	-- Dribbling (south-west)
	local dribbleStart = dir(150) * 122
	register(records, StationBuilder.Dribbling(folder, lookOut(dribbleStart, 150), { Id = "Lobby_Dribbling", Color = STAT_COLOR.DRI }), "Lobby_Dribbling", "Lobby")
	stationSign(folder, CFrame.lookAt(dribbleStart + dir(150) * -8 + dir(60) * 14, V(0, 0, 0)), "DRI", "DRIBBLING CONES")
	path(folder, dir(150) * PLAZA_RADIUS, dribbleStart + dir(150) * -6, 12)

	-- Tackle Zone (north-west)
	local defendLine = dir(210) * 122
	register(records, StationBuilder.Defending(folder, lookOut(defendLine, 210), { Id = "Lobby_Defending", Color = STAT_COLOR.DEF }), "Lobby_Defending", "Lobby")
	stationSign(folder, CFrame.lookAt(defendLine + dir(210) * -6 + dir(300) * 32, V(0, 0, 0)), "DEF", "TACKLE ZONE")
	path(folder, dir(210) * PLAZA_RADIUS, defendLine + dir(210) * 6, 12)

	-- Gym (south): a roofed building with three machines
	local gymCenter = V(0, 0, 150)
	local gym = Instance.new("Model")
	gym.Name = "GymBuilding"
	gym.Parent = folder
	patch(gym, "Floor", 64, 34, CFrame.new(gymCenter), COL.Rubber, Enum.Material.SmoothPlastic, 0.3)
	for _, x in ipairs({ -32, 32 }) do part(gym, "Wall", V(1.5, 14, 34), CFrame.new(gymCenter + V(x, 7, 0)), COL.White) end
	part(gym, "BackWall", V(65, 14, 1.5), CFrame.new(gymCenter + V(0, 7, 17)), COL.White)
	part(gym, "Stripe", V(65.2, 2, 1.6), CFrame.new(gymCenter + V(0, 10, 17)), STAT_COLOR.PHY, Enum.Material.SmoothPlastic)
	part(gym, "Roof", V(68, 1.2, 38), CFrame.new(gymCenter + V(0, 14.6, 0)), COL.NavyDark)
	for _, x in ipairs({ -32, 32 }) do part(gym, "FrontPost", V(1.5, 14, 1.5), CFrame.new(gymCenter + V(x, 7, -17)), COL.White) end
	local gymCF = CFrame.lookAt(gymCenter + V(0, 0, 4), gymCenter + V(0, 0, 20))
	for _, rec in ipairs(StationBuilder.Gym(folder, gymCF, { Id = "Lobby_Gym", Color = STAT_COLOR.PHY })) do
		register(records, rec, "Lobby_Gym_" .. rec.Machine, "Lobby")
	end
	MapKit.sign(gym, "GymSign", 26, 6, CFrame.lookAt(gymCenter + V(0, 9, -17.8), gymCenter + V(0, 9, -40)), {
		{ "\u{1F4AA} GYM", COL.White, 2, 5 }, { "+PHY  \u{2022}  PRESS IN THE GREEN", STAT_COLOR.PHY, 1, 4 },
	}, { COL.NavyDark, STAT_COLOR.PHY }, 0)
	path(folder, dir(90) * PLAZA_RADIUS, gymCenter + V(0, 0, -17), 12)
end

-- The VIP lounge: two stations with better XP and some sofas.
local function buildVIP(parent, records)
	local folder = Instance.new("Model")
	folder.Name = "VIPLounge"
	folder.Parent = parent
	local center = V(56, 0, -100)
	local gold = rgb(255, 200, 40)
	patch(folder, "Carpet", 64, 40, CFrame.new(center), rgb(120, 20, 40), Enum.Material.Fabric, 0.3)
	for _, x in ipairs({ -32, 32 }) do part(folder, "Wall", V(1.5, 12, 40), CFrame.new(center + V(x, 6, 0)), rgb(30, 20, 40)) end
	part(folder, "BackWall", V(65, 12, 1.5), CFrame.new(center + V(0, 6, -20)), rgb(30, 20, 40))
	part(folder, "Roof", V(68, 1, 44), CFrame.new(center + V(0, 12.5, 0)), rgb(30, 20, 40))
	part(folder, "GoldTrim", V(68.4, 0.6, 44.4), CFrame.new(center + V(0, 12, 0)), gold, Enum.Material.Neon)
	-- front wall with the VIP gate
	for _, x in ipairs({ -22, 22 }) do part(folder, "Front", V(20, 12, 1.5), CFrame.new(center + V(x, 6, 20)), rgb(30, 20, 40)) end
	gate(workspace:FindFirstChild("Gates") or parent, "VIPGate", CFrame.lookAt(center + V(0, 0, 20), center + V(0, 0, 40)), 22, 0, "VIP LOUNGE", gold, true)
	-- sofas
	for _, x in ipairs({ -24, 24 }) do
		part(folder, "Sofa", V(8, 2, 3.5), CFrame.new(center + V(x, 1, 14)), rgb(200, 30, 60))
		part(folder, "SofaBack", V(8, 3, 1), CFrame.new(center + V(x, 2.5, 15.8)), rgb(200, 30, 60))
	end
	-- a goal on the back wall and a squat rack
	local shootSpot = center + V(-12, 0, 6)
	register(records, StationBuilder.Shooting(folder, CFrame.lookAt(shootSpot, shootSpot + V(0, 0, -1)), { Id = "VIP_Shooting", Compact = true, Color = gold }),
		"VIP_Shooting", "VIP")
	local gymCF = CFrame.lookAt(center + V(18, 0, 2), center + V(18, 0, -10))
	for _, rec in ipairs(StationBuilder.Gym(folder, gymCF, { Id = "VIP_Gym", Machines = { "Squat" }, Color = gold })) do
		register(records, rec, "VIP_Gym_" .. rec.Machine, "VIP")
	end
	path(folder, dir(-60) * PLAZA_RADIUS, center + V(0, 0, 21), 10)
end

-- An academy: every drill again in a fenced zone behind a gate.
local function buildAcademy(parent, records, area, center)
	local def = Config.Areas[area]
	local folder = Instance.new("Folder")
	folder.Name = area .. "Academy"
	folder.Parent = parent
	local color = def.Color
	local function at(x, z) return center + V(x, 0, z) end
	-- ground and a low fence
	patch(folder, "Ground", 260, 230, CFrame.new(center), rgb(76, 166, 70), Enum.Material.Grass, 0.1)
	for _, z in ipairs({ -115, 115 }) do part(folder, "Fence", V(260, 3, 1), CFrame.new(at(0, z) + V(0, 1.5, 0)), color, Enum.Material.SmoothPlastic) end
	for _, x in ipairs({ -130, 130 }) do
		for _, zs in ipairs({ { -115, -9 }, { 9, 115 } }) do
			local len = zs[2] - zs[1]
			part(folder, "Fence", V(1, 3, len), CFrame.new(at(x, (zs[1] + zs[2]) / 2) + V(0, 1.5, 0)), color, Enum.Material.SmoothPlastic)
		end
	end
	path(folder, at(-130, 0), at(130, 0), 14)
	gate(workspace:FindFirstChild("Gates") or parent, area .. "Gate", CFrame.lookAt(at(-130, 0), at(-140, 0)), 16, def.NeedOVR, def.Title, color)
	-- a title board
	MapKit.sign(folder, "Title", 36, 8, CFrame.lookAt(at(-100, -24), at(-140, -24)), {
		{ def.Title, COL.White, 2, 6 }, { ("x%.2g XP  \u{2022}  HARDER DRILLS"):format(def.Mult), color, 1, 4 },
	}, { COL.NavyDark, color }, 5)

	local function opts(id) return { Id = id, Compact = true, Color = color } end
	register(records, StationBuilder.Shooting(folder, CFrame.lookAt(at(-70, -26), at(-70, -60)), opts(area .. "_Shooting")), area .. "_Shooting", area)
	register(records, StationBuilder.Passing(folder, CFrame.lookAt(at(4, -18), at(4, -60)), opts(area .. "_Passing")), area .. "_Passing", area)
	register(records, StationBuilder.Dribbling(folder, CFrame.lookAt(at(62, -14), at(62, -60)), opts(area .. "_Dribbling")), area .. "_Dribbling", area)
	register(records, StationBuilder.Defending(folder, CFrame.lookAt(at(100, 24), at(100, 60)), opts(area .. "_Defending")), area .. "_Defending", area)
	register(records, StationBuilder.Speed(folder, CFrame.lookAt(at(-104, 92), at(0, 92)), opts(area .. "_Speed")), area .. "_Speed", area)
	for _, rec in ipairs(StationBuilder.Gym(folder, CFrame.lookAt(at(20, 52), at(20, 70)), { Id = area .. "_Gym", Machines = { "Squat", "Sled" }, Color = color })) do
		register(records, rec, area .. "_Gym_" .. rec.Machine, area)
	end
	-- little signs for each drill
	for _, s in ipairs({
		{ "SHO", "SHOOTING", at(-92, -18), at(-92, 40) }, { "PAS", "PASSING", at(-18, -10), at(-18, 40) },
		{ "DRI", "DRIBBLING", at(40, -8), at(40, 40) }, { "DEF", "TACKLE ZONE", at(76, 16), at(76, -40) },
		{ "PAC", "SPRINT", at(-110, 80), at(-110, 0) }, { "PHY", "GYM", at(-2, 44), at(-2, 0) },
	}) do
		local c = STAT_COLOR[s[1]]
		MapKit.sign(folder, "Sign", 12, 3.6, CFrame.lookAt(s[3], s[4]), {
			{ Config.Stats[s[1]].Icon .. " " .. s[2], COL.White, 2, 3 }, { "+" .. s[1], c, 1, 3 },
		}, { COL.NavyDark, c }, 4)
	end
end

--------------------------------------------------------------------------------
-- The stadium
--------------------------------------------------------------------------------

local function buildStadium(parent, records)
	local folder = Instance.new("Model")
	folder.Name = "Stadium"
	folder.Parent = parent
	local center = V(-340, 0, 0)
	local length, width = 112, 72
	local pitchCF = CFrame.lookAt(center, center + V(-1, 0, 0)) -- attack toward the west goal
	-- the pitch with stripes and lines
	for i = 0, 13 do
		local x = -length / 2 + (i + 0.5) * length / 14
		patch(folder, "Grass", length / 14 + 0.02, width + 8, pitchCF * CFrame.new(0, 0, x), (i % 2 == 0) and COL.Grass or COL.GrassLight, Enum.Material.Grass, 0.25)
	end
	local function p(x, z) return (pitchCF * CFrame.new(x, 0, z)).Position end
	-- touchlines and halfway line (pitch space: x across, z along; the far goal is at z = -length/2)
	line(folder, p(-width / 2, -length / 2), p(-width / 2, length / 2), 0.6, 0.3)
	line(folder, p(width / 2, -length / 2), p(width / 2, length / 2), 0.6, 0.3)
	line(folder, p(-width / 2, -length / 2), p(width / 2, -length / 2), 0.6, 0.3)
	line(folder, p(-width / 2, length / 2), p(width / 2, length / 2), 0.6, 0.3)
	line(folder, p(-width / 2, 0), p(width / 2, 0), 0.6, 0.3)
	ring(folder, "Circle", center, 10, 0.6, COL.Line, 40, 0.3)
	for _, s in ipairs({ -1, 1 }) do
		local gl = s * length / 2
		line(folder, p(-18, gl), p(-18, gl - s * 16), 0.6, 0.3)
		line(folder, p(18, gl), p(18, gl - s * 16), 0.6, 0.3)
		line(folder, p(-18, gl - s * 16), p(18, gl - s * 16), 0.6, 0.3)
	end
	-- goals: theirs at the far end (z = -length/2), ours at the near end
	local theirGoal = CFrame.lookAt(p(0, -length / 2), p(0, 0))
	local ourGoal = CFrame.lookAt(p(0, length / 2), p(0, 0))
	StationBuilder.Goal(folder, theirGoal, 24, 8, 6)
	StationBuilder.Goal(folder, ourGoal, 24, 8, 6)
	-- stands on all four sides with a crowd of coloured blocks
	local crowd = { rgb(255, 70, 80), rgb(40, 130, 255), COL.White, rgb(255, 210, 40), rgb(60, 200, 90) }
	local seed = 7
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	for side = 1, 4 do
		local along = (side <= 2) and (length + 20) or (width + 20)
		local offset = (side <= 2) and (width / 2 + 10) or (length / 2 + 10)
		local sign = (side % 2 == 0) and 1 or -1
		for tier = 0, 4 do
			local cfTier
			if side <= 2 then
				cfTier = pitchCF * CFrame.new(sign * (offset + tier * 3.5), 1.2 + tier * 2.4, 0) * CFrame.Angles(0, math.rad(90 * sign), 0)
			else
				cfTier = pitchCF * CFrame.new(0, 1.2 + tier * 2.4, sign * (offset + tier * 3.5)) * CFrame.Angles(0, (sign > 0) and math.pi or 0, 0)
			end
			part(folder, "Stand", V(along, 2.4 + tier * 2.4, 3.5), cfTier * CFrame.new(0, -(tier * 1.2), 0), COL.ConcreteDark, Enum.Material.Concrete)
			for k = 0, math.floor(along / 3) - 1 do
				if rnd() < 0.75 then
					part(folder, "Fan", V(1.4, 1.8, 1), cfTier * CFrame.new(-along / 2 + 1.5 + k * 3, 2.1, 0), crowd[math.floor(rnd() * #crowd) + 1],
						Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
				end
			end
		end
	end
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		floodlight(folder, p(c[1] * (width / 2 + 30), c[2] * (length / 2 + 26)))
	end
	-- a scoreboard over the west stand
	local _, _, gui = MapKit.sign(folder, "Scoreboard", 30, 10, CFrame.lookAt(p(0, -length / 2 - 30), p(0, 0)), {}, { COL.NavyDark, rgb(255, 90, 90) }, 16)
	local score = MapKit.uiText(gui, "HOME 0 - 0 AWAY", 5, COL.White, { Name = "Score", Size = UDim2.fromScale(0.9, 0.6), Position = UDim2.fromScale(0.05, 0.2) })
	-- the way in: a gate at 75 OVR, then the kick-off spot
	gate(workspace:FindFirstChild("Gates") or parent, "StadiumGate", CFrame.lookAt(V(-196, 0, 0), V(-186, 0, 0)), 16, Config.Areas.Stadium.NeedOVR, "STADIUM", rgb(255, 90, 90))
	path(folder, V(-PLAZA_RADIUS, 0, 0), V(-260, 0, 0), 14)
	local kickoff = V(-262, 0, 0)
	MapKit.startPad(folder, kickoff, rgb(255, 90, 90), "\u{26BD} PLAY MATCH")
	local prompt = MapKit.prompt(folder, "Prompt", kickoff + V(0, 2.5, 0), "Play", "Stadium Match", 10)
	MapKit.sign(folder, "MatchSign", 20, 6, CFrame.lookAt(V(-252, 0, -18), V(-200, 0, -18)), {
		{ "\u{1F3DF} STADIUM MATCH", COL.White, 2, 5 }, { "WIN = HUGE XP FOR EVERY STAT", rgb(255, 200, 60), 1, 4 },
	}, { COL.NavyDark, rgb(255, 90, 90) }, 5)

	local rec = {
		Kind = "Match", Model = folder, Prompt = prompt, Pitch = pitchCF, Length = length, Width = width,
		TheirGoal = theirGoal, OurGoal = ourGoal, Scoreboard = score, Kickoff = kickoff,
		AttackSpot = (theirGoal * CFrame.new(0, 0, -20)).Position,
		PassSpot = p(0, 6),
		Teammates = { p(-22, -18), p(0, -28), p(22, -18), p(-14, -38) },
		DefendLine = CFrame.lookAt(p(0, length / 2), p(0, 0)),
	}
	register(records, rec, "Stadium_Match", "Stadium")
	return rec
end

--------------------------------------------------------------------------------
-- Scenery
--------------------------------------------------------------------------------

local function tree(parent, at, size)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	cylinder(m, "Trunk", 5 * size, 1.4 * size, at, rgb(110, 76, 44), Enum.Material.Wood)
	ball(m, "Leaves", 8 * size, at + V(0, 7 * size, 0), rgb(56, 150, 60), Enum.Material.Grass)
	ball(m, "Leaves", 6 * size, at + V(1.6 * size, 9 * size, 0.8 * size), rgb(70, 170, 70), Enum.Material.Grass)
end

local function scatterTrees(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = parent
	local seed = 11
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local keepClear = {
		{ V(0, 0, 0), 90 }, { V(0, 0, -178), 90 }, { dir(-30) * 150, 45 }, { dir(30) * 150, 55 }, { V(0, 0, 150), 45 },
		{ dir(150) * 160, 55 }, { dir(210) * 160, 55 }, { V(56, 0, -100), 40 }, { V(-340, 0, 0), 120 }, { V(-230, 0, 0), 40 },
	}
	local count = 0
	for _ = 1, 400 do
		if count >= 70 then break end
		local pos = V(-560 + rnd() * 760, 0, -360 + rnd() * 720)
		local ok = pos.X < 190 and math.abs(pos.Z) > 12
		for _, zone in ipairs(keepClear) do
			if (pos - zone[1]).Magnitude < zone[2] then
				ok = false
				break
			end
		end
		if ok then
			tree(folder, pos, 0.8 + rnd() * 0.7)
			count += 1
		end
	end
end

--------------------------------------------------------------------------------
-- Build everything
--------------------------------------------------------------------------------

function MapBuilder.Build()
	local old = workspace:FindFirstChild("Map")
	if old then old:Destroy() end
	local map = Instance.new("Folder")
	map.Name = "Map"
	local gates = workspace:FindFirstChild("Gates") or Instance.new("Folder")
	gates.Name = "Gates"
	gates.Parent = workspace

	-- grass everywhere
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate.Color = rgb(78, 168, 70)
		baseplate.Material = Enum.Material.Grass
		for _, child in ipairs(baseplate:GetChildren()) do
			if child:IsA("Texture") or child:IsA("Decal") then child:Destroy() end
		end
	end
	local oldSpawn = workspace:FindFirstChild("SpawnLocation")
	if oldSpawn then oldSpawn:Destroy() end

	local records = {}
	buildPlaza(map)
	local boards = {}
	boards.HighestOVR = leaderboard(map, "Board_HighestOVR", "HIGHEST OVR", "THE BEST CARDS", CFrame.lookAt(dir(60) * 60, V(0, 0, 0)), rgb(255, 196, 30))
	boards.MostSeasons = leaderboard(map, "Board_MostSeasons", "MOST SEASONS", "NEW SEASONS STARTED", CFrame.lookAt(dir(120) * 60, V(0, 0, 0)), rgb(190, 110, 255))
	boards.FastestSpeed = leaderboard(map, "Board_FastestSpeed", "FASTEST SPEED COURSE", "BEST LAP TIME", CFrame.lookAt(dir(-120) * 60, V(0, 0, 0)), rgb(40, 220, 255))

	-- the Position Board (opens the positions menu)
	local posModel = MapKit.sign(map, "PositionBoard", 18, 9, CFrame.lookAt(dir(-12) * 44, V(0, 0, 0)), {
		{ "POSITION BOARD", COL.White, 2, 5 },
		{ "ST \u{2022} W \u{2022} CAM \u{2022} CM \u{2022} CB \u{2022} GK", rgb(255, 210, 60), 1.4, 4 },
		{ ("UNLOCKS AT %d OVR"):format(Config.PositionsUnlockOVR), rgb(160, 220, 255), 1, 3 },
	}, { COL.NavyDark, rgb(255, 210, 60) }, 2)
	local positionPrompt = MapKit.prompt(posModel, "Prompt", (CFrame.lookAt(dir(-12) * 44, V(0, 0, 0)) * CFrame.new(0, 2.5, -2.5)).Position,
		"Choose", "Position Board", 10)

	-- a big title board over the north stand
	MapKit.sign(map, "Title", 44, 12, CFrame.lookAt(V(0, 0, -76), V(0, 0, 0)), {
		{ Config.GameName, COL.White, 2.2, 7 }, { "\u{26BD} " .. Config.Tagline .. " \u{26BD}", rgb(255, 210, 60), 1, 5 },
	}, { COL.NavyDark, rgb(40, 130, 255) }, 14)

	buildLobbyStations(map, records)
	map.Parent = workspace -- gates look for workspace.Gates (made above)
	buildVIP(map, records)
	for _, spec in ipairs({ { "Pro", V(330, 0, 0) }, { "Elite", V(590, 0, 0) }, { "Legend", V(850, 0, 0) } }) do
		buildAcademy(map, records, spec[1], spec[2])
	end
	-- the avenue from the plaza to the academies
	path(map, V(PLAZA_RADIUS, 0, 0), V(200, 0, 0), 14)
	buildStadium(map, records)
	scatterTrees(map)

	return records, boards, { PositionPrompt = positionPrompt }
end

return MapBuilder
