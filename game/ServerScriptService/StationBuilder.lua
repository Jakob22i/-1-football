-- Builds one training station of each kind at a given spot, and returns a
-- record the TrainingService uses: where to stand, where the goal and the
-- targets are, the course checkpoints, and the START prompt.
--
-- Every builder takes (parent, cf, opts). cf is where the player starts,
-- LookVector pointing into the drill. opts: Id, Area, Compact (a smaller
-- version for the academies), Color.

local MapKit = require(script.Parent:WaitForChild("MapKit"))
local PlayerFigure = require(game:GetService("ReplicatedStorage"):WaitForChild("PlayerFigure"))
local RigService = require(script.Parent:WaitForChild("RigService"))

local part, patch, line, cylinder, rod, ball, disc = MapKit.part, MapKit.patch, MapKit.line, MapKit.cylinder, MapKit.rod, MapKit.ball, MapKit.disc
local COL = MapKit.Colors
local rgb = MapKit.rgb
local V = Vector3.new

local StationBuilder = {}

local function flat(v) return V(v.X, 0, v.Z) end

-- A striped grass pitch patch, centred on cf.
local function pitch(parent, cf, width, depth, stripes)
	stripes = stripes or math.max(2, math.floor(depth / 8))
	local each = depth / stripes
	for i = 0, stripes - 1 do
		local z = -depth / 2 + each * (i + 0.5)
		patch(parent, "Grass", width, each + 0.02, cf * CFrame.new(0, 0, z), (i % 2 == 0) and COL.Grass or COL.GrassLight, Enum.Material.Grass, 0.2)
	end
end

local function station(parent, opts, kind)
	local model = Instance.new("Model")
	model.Name = opts.Id or kind
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Area", opts.Area or "Lobby")
	model.Parent = parent
	return model
end

local function startPrompt(model, at, title, color)
	MapKit.startPad(model, at, color, "\u{25B6} " .. title)
	local prompt = MapKit.prompt(model, "Prompt", at + V(0, 2.5, 0), "Start", title, 9)
	return prompt
end

-- A goal: posts, crossbar and a net of thin bars. goalCF sits on the goal
-- line's middle, LookVector toward the field.
local function goal(parent, goalCF, width, height, depth, color)
	local folder = Instance.new("Model")
	folder.Name = "Goal"
	folder.Parent = parent
	local white = color or COL.White
	local function at(x, y, z) return (goalCF * CFrame.new(x, y, z)).Position end
	for _, x in ipairs({ -width / 2, width / 2 }) do
		cylinder(folder, "Post", height, 0.7, at(x, 0, 0), white, Enum.Material.SmoothPlastic)
		rod(folder, "Back", at(x, height, 0), at(x, 0, depth), 0.25, white, Enum.Material.SmoothPlastic)
	end
	rod(folder, "Crossbar", at(-width / 2 - 0.35, height, 0), at(width / 2 + 0.35, height, 0), 0.7, white, Enum.Material.SmoothPlastic)
	rod(folder, "BaseBar", at(-width / 2, 0.15, depth), at(width / 2, 0.15, depth), 0.25, white, Enum.Material.SmoothPlastic)
	local net = rgb(235, 240, 245)
	local props = { Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false }
	-- the net: back, roof and sides as a grid of thin bars
	for x = -width / 2 + 2, width / 2 - 2, 2 do
		local p = part(folder, "Net", V(0.12, 0.12, math.sqrt(height * height + depth * depth)), CFrame.lookAt(at(x, height, 0), at(x, 0, depth)) * CFrame.new(0, 0, -math.sqrt(height * height + depth * depth) / 2), net, Enum.Material.SmoothPlastic, props)
		p.Name = "Net"
	end
	for k = 1, 3 do
		local y = height * (1 - k / 4)
		local z = depth * (k / 4)
		part(folder, "Net", V(width, 0.12, 0.12), CFrame.new(at(0, y, z)) * (goalCF - goalCF.Position), net, Enum.Material.SmoothPlastic, props)
	end
	for _, x in ipairs({ -width / 2, width / 2 }) do
		for k = 1, 3 do
			local z = depth * k / 4
			part(folder, "Net", V(0.12, height * (1 - k / 4), 0.12), CFrame.new(at(x, height * (1 - k / 4) / 2, z)) * (goalCF - goalCF.Position), net, Enum.Material.SmoothPlastic, props)
		end
	end
	-- a solid invisible back so balls do not fly through
	part(folder, "Backstop", V(width, height, 0.4), goalCF * CFrame.new(0, height / 2, depth + 0.3), net, Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = true })
	return folder
end
StationBuilder.Goal = goal

-- A training dummy: a real Roblox character in a yellow bib on a round
-- stand, facing `lookAt` (the passer). The character arrives a moment after
-- the map is built (RigService makes it); the model is there from the start.
local function dummy(parent, at, lookAt, seed)
	local stand = Instance.new("Model")
	stand.Name = "DummyStand"
	stand.Parent = parent
	disc(stand, "Base", at, 3.4, COL.NavyDark, 0.4, Enum.Material.SmoothPlastic)
	local m = Instance.new("Model")
	m.Name = "Dummy"
	m.Parent = parent
	local middle = at + V(0, 3.4, 0)
	local facing = flat((lookAt or (at + V(0, 0, 1))) - at)
	if facing.Magnitude < 0.01 then facing = V(0, 0, 1) end
	task.spawn(function()
		RigService.WaitReady(60)
		if not m.Parent then return end
		local fig = PlayerFigure.Build(m, "Dummy", { Seed = seed, Avatars = false, Name = "Character", Still = true })
		PlayerFigure.Pose(fig, CFrame.lookAt(middle, middle + facing.Unit))
	end)
	return m
end
StationBuilder.Dummy = dummy

-- A traffic cone: three stacked cylinders and a white band.
local function cone(parent, at)
	local m = Instance.new("Model")
	m.Name = "Cone"
	m.Parent = parent
	part(m, "Foot", V(2.2, 0.25, 2.2), CFrame.new(at + V(0, 0.125, 0)), COL.Orange, Enum.Material.SmoothPlastic)
	cylinder(m, "Low", 0.9, 1.6, at + V(0, 0.25, 0), COL.Orange, Enum.Material.SmoothPlastic)
	cylinder(m, "Band", 0.45, 1.2, at + V(0, 1.15, 0), COL.White, Enum.Material.SmoothPlastic)
	cylinder(m, "Top", 0.9, 0.8, at + V(0, 1.6, 0), COL.Orange, Enum.Material.SmoothPlastic)
	return m
end

--------------------------------------------------------------------------------
-- Shooting: stand at the edge of the box, shoot at the targets in the goal.
--------------------------------------------------------------------------------

function StationBuilder.Shooting(parent, cf, opts)
	local model = station(parent, opts, "Shooting")
	local distance = opts.Compact and 18 or 20
	local goalCF = cf * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
	pitch(model, cf * CFrame.new(0, 0, -distance + 14), 50, 44)
	-- box lines
	local function g(x, z) return (goalCF * CFrame.new(x, 0, z)).Position end
	line(model, g(-25, 0), g(25, 0), 0.5)
	line(model, g(-20, 0), g(-20, -17), 0.5)
	line(model, g(20, 0), g(20, -17), 0.5)
	line(model, g(-20, -17), g(20, -17), 0.5)
	line(model, g(-9, 0), g(-9, -6), 0.5)
	line(model, g(9, 0), g(9, -6), 0.5)
	line(model, g(-9, -6), g(9, -6), 0.5)
	goal(model, goalCF, 24, 8, 6)
	disc(model, "Spot", cf.Position, 1.6, COL.White, 0.26, Enum.Material.SmoothPlastic, { CanCollide = false })
	local prompt = startPrompt(model, (cf * CFrame.new(0, 0, 3)).Position, "SHOOTING", opts.Color)
	return {
		Kind = "Shooting", Model = model, Prompt = prompt,
		Spot = cf.Position, Facing = cf, Goal = goalCF, GoalWidth = 24, GoalHeight = 8,
	}
end

--------------------------------------------------------------------------------
-- Passing: dummies and rings light up one at a time.
--------------------------------------------------------------------------------

function StationBuilder.Passing(parent, cf, opts)
	local model = station(parent, opts, "Passing")
	pitch(model, cf * CFrame.new(0, 0, -22), 90, 60)
	disc(model, "Spot", cf.Position, 1.6, COL.White, 0.26, Enum.Material.SmoothPlastic, { CanCollide = false })
	local targets = {}
	local layout = opts.Compact and {
		{ "Dummy", -35, 20 }, { "Dummy", -10, 32 }, { "Dummy", 15, 42 }, { "Dummy", 38, 26 }, { "Ring", 0, 22 }, { "Ring", 26, 34 },
	} or {
		{ "Dummy", -42, 20 }, { "Dummy", -20, 34 }, { "Dummy", 4, 46 }, { "Dummy", 24, 30 }, { "Dummy", 44, 40 },
		{ "Ring", -8, 22 }, { "Ring", -32, 36 }, { "Ring", 16, 38 },
	}
	for i, spec in ipairs(layout) do
		local angle = math.rad(spec[2])
		local pos = (cf * CFrame.new(math.sin(angle) * spec[3], 0, -math.cos(angle) * spec[3])).Position
		pos = V(pos.X, 0, pos.Z)
		local target = { Id = i, Kind = spec[1], Pos = pos }
		if spec[1] == "Dummy" then
			target.Model = dummy(model, pos, V(cf.Position.X, 0, cf.Position.Z), i * 17)
		else
			-- a hoop on a stand, facing the passer
			local hoop = Instance.new("Model")
			hoop.Name = "Ring"
			hoop.Parent = model
			local face = CFrame.lookAt(pos + V(0, 2.6, 0), V(cf.Position.X, 2.6, cf.Position.Z))
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				local p = face * CFrame.new(math.cos(a) * 2.2, math.sin(a) * 2.2, 0) * CFrame.Angles(0, 0, a)
				part(hoop, "Hoop", V(0.5, 1.85, 0.5), p, rgb(60, 230, 255), Enum.Material.Neon, { CanCollide = false })
			end
			cylinder(hoop, "Stand", 0.4, 0.5, pos, COL.Metal, Enum.Material.Metal)
			rod(hoop, "Leg", pos + V(0, 0, 0), pos + V(0, 0.4, 0), 0.5, COL.Metal, Enum.Material.Metal)
			target.Model = hoop
			target.Center = pos + V(0, 2.6, 0)
		end
		line(model, cf.Position, pos, 0.25, 0.23, rgb(200, 240, 200))
		table.insert(targets, target)
	end
	local prompt = startPrompt(model, (cf * CFrame.new(0, 0, 3)).Position, "PASSING", opts.Color)
	return { Kind = "Passing", Model = model, Prompt = prompt, Spot = cf.Position, Facing = cf, Targets = targets }
end

--------------------------------------------------------------------------------
-- Dribbling: a slalom out, round the flag, and a slalom back.
--------------------------------------------------------------------------------

function StationBuilder.Dribbling(parent, cf, opts)
	local model = station(parent, opts, "Dribbling")
	local count = opts.Compact and 6 or 8
	local spacing = 8
	local offset = 14 -- the return lane, to the right
	local outLength = 8 + count * spacing
	local look = flat(cf.LookVector).Unit
	local right = look:Cross(Vector3.yAxis)
	local origin = flat(cf.Position)
	patch(model, "Turf", offset + 14, outLength + 14, CFrame.lookAt(origin + right * offset / 2 + look * (outLength / 2), origin + right * offset / 2 + look * outLength),
		rgb(60, 150, 70), Enum.Material.Grass, 0.2)
	local checks = {}
	local cones = {}
	-- out
	for i = 1, count do
		local pos = origin + look * (4 + i * spacing)
		cone(model, pos)
		table.insert(cones, pos)
		table.insert(checks, { Kind = "Cone", Pos = pos, Dir = look, Side = (i % 2 == 1) and 1 or -1 })
	end
	-- the turn: round the flag, cross over to the return lane
	local flagPos = origin + look * (outLength + 4) + right * (offset / 2)
	cylinder(model, "FlagPole", 7, 0.3, flagPos, COL.White, Enum.Material.SmoothPlastic)
	part(model, "Flag", V(0.1, 1.6, 2.4), CFrame.new(flagPos + V(0, 6.2, 0)) * CFrame.lookAt(Vector3.zero, right) * CFrame.new(0, 0, -1.2),
		COL.Red, Enum.Material.SmoothPlastic, { CanCollide = false })
	table.insert(checks, { Kind = "Turn", Pos = flagPos, Dir = right, Width = 12 })
	-- back
	local back = origin + right * offset
	for i = count, 1, -1 do
		local pos = back + look * (4 + i * spacing + spacing / 2)
		cone(model, pos)
		table.insert(cones, pos)
		table.insert(checks, { Kind = "Cone", Pos = pos, Dir = -look, Side = (i % 2 == 1) and 1 or -1 })
	end
	-- lines: start (out lane) and finish (return lane)
	line(model, origin - right * 4, origin + right * 4, 0.6, 0.24, COL.White)
	local finish = back + look * 2
	line(model, finish - right * 4, finish + right * 4, 0.8, 0.24, rgb(255, 230, 60))
	table.insert(checks, { Kind = "Finish", Pos = finish, Dir = -look, Width = 12 })
	local startCF = CFrame.lookAt(origin - look * 2 + V(0, 3, 0), origin + look * 10 + V(0, 3, 0))
	local prompt = startPrompt(model, origin - look * 4, "DRIBBLING", opts.Color)
	-- length of the route (for par time), weaving adds a bit
	local length = (outLength + 4) * 2 + math.pi * offset / 2
	return {
		Kind = "Dribbling", Model = model, Prompt = prompt, Start = startCF, Checks = checks, Cones = cones,
		Length = length * 1.1, Center = origin + look * (outLength / 2) + right * (offset / 2), Extent = outLength + 30,
	}
end

--------------------------------------------------------------------------------
-- Speed: a running track (the lobby) or a sprint lane (the academies).
--------------------------------------------------------------------------------

function StationBuilder.Speed(parent, cf, opts)
	local model = station(parent, opts, "Speed")
	local look = flat(cf.LookVector).Unit
	local right = look:Cross(Vector3.yAxis)
	local origin = flat(cf.Position)
	local checks = {}
	local length, path
	local startCF
	local center
	if opts.Compact then
		-- a straight sprint: 3 gates, 120 studs
		length = 120
		patch(model, "Lane", 12, length + 16, CFrame.lookAt(origin + look * (length / 2), origin + look * length), COL.Track, Enum.Material.SmoothPlastic, 0.2)
		for k = 1, 3 do
			local pos = origin + look * (length * k / 3)
			local gate = Instance.new("Model")
			gate.Name = "Gate"
			gate.Parent = model
			for _, side in ipairs({ -1, 1 }) do cylinder(gate, "Post", 9, 0.8, pos + right * side * 6.5, COL.White) end
			part(gate, "Beam", V(14, 1, 1), CFrame.lookAt(pos + V(0, 9, 0), pos + V(0, 9, 0) + look), k == 3 and rgb(255, 230, 60) or rgb(60, 220, 255), Enum.Material.Neon)
			table.insert(checks, { Kind = k == 3 and "Finish" or "Gate", Pos = pos, Dir = look, Width = 8 })
		end
		startCF = CFrame.lookAt(origin - look * 3 + V(0, 3, 0), origin + look * 10 + V(0, 3, 0))
		center = origin + look * (length / 2)
		-- the auto run: up the lane and back, over and over
		path = { origin + look * 4, origin + look * (length - 4) }
	else
		-- an oval: two straights and two bends; run anticlockwise seen from above
		local straight, radius, width = 90, 28, 10
		local function at(x, z) return origin + look * x + right * z end
		-- the track centre is `origin`; the home straight runs along +look at right = +radius
		patch(model, "Infield", radius * 2 - width, straight + 10, CFrame.lookAt(origin, origin + look), COL.Grass, Enum.Material.Grass, 0.2)
		for _, z in ipairs({ -radius, radius }) do
			patch(model, "Straight", width, straight, CFrame.lookAt(at(0, z), at(1, z)), COL.Track, Enum.Material.SmoothPlastic, 0.22)
			for lane = -1, 1 do
				line(model, at(-straight / 2, z + lane * 3.3), at(straight / 2, z + lane * 3.3), 0.25, 0.28)
			end
		end
		for _, endX in ipairs({ -straight / 2, straight / 2 }) do
			local sign = endX > 0 and 1 or -1
			local segments = 24
			for k = 0, segments - 1 do
				local a0 = (k / segments) * math.pi
				local a1 = ((k + 1) / segments) * math.pi
				local am = (a0 + a1) / 2
				local c = at(endX + sign * math.sin(am) * radius, math.cos(am) * radius)
				local tangent = (at(endX + sign * math.sin(a1) * radius, math.cos(a1) * radius) - at(endX + sign * math.sin(a0) * radius, math.cos(a0) * radius))
				part(model, "Bend", V(width, 0.22, tangent.Magnitude + 0.4), CFrame.lookAt(c + V(0, 0.11, 0), c + V(0, 0.11, 0) + tangent), COL.Track,
					Enum.Material.SmoothPlastic)
			end
		end
		-- start / finish line: chequered
		for k = 0, 9 do
			part(model, "Finish", V(1, 0.06, 1), CFrame.lookAt(at(0.5 * ((k % 2 == 0) and 1 or -1), radius - 4.5 + k), at(1, radius - 4.5 + k)) + V(0, 0.25, 0),
				(k % 2 == 0) and COL.White or COL.NavyDark, Enum.Material.SmoothPlastic, { CanCollide = false })
		end
		-- gates round the track (with arches you can see)
		-- points on the bends (no arch) keep runners on the track
		local function bend(endX, deg)
			local s = endX > 0 and 1 or -1
			local a = math.rad(deg)
			local pos = at(endX + s * math.sin(a) * radius, math.cos(a) * radius)
			local tangent = (look * math.cos(a) - right * math.sin(a) * s).Unit
			return { pos, tangent, "Bend" }
		end
		local gates = {
			bend(straight / 2, 50),
			{ at(straight / 2 + radius, 0), -right, "Gate" },
			bend(straight / 2, 130),
			{ at(0, -radius), -look, "Gate" },
			bend(-straight / 2, 130),
			{ at(-straight / 2 - radius, 0), right, "Gate" },
			bend(-straight / 2, 50),
			{ at(0, radius), look, "Finish" },
		}
		for _, gspec in ipairs(gates) do
			local pos, dir = gspec[1], gspec[2]
			if gspec[3] == "Bend" then
				table.insert(checks, { Kind = "Bend", Pos = pos, Dir = dir, Width = 8 })
				continue
			end
			local side = dir:Cross(Vector3.yAxis)
			local arch = Instance.new("Model")
			arch.Name = "Arch"
			arch.Parent = model
			for _, s in ipairs({ -1, 1 }) do cylinder(arch, "Post", 10, 0.8, pos + side * s * 6.2, COL.White) end
			part(arch, "Beam", V(13.2, 1.2, 1), CFrame.lookAt(pos + V(0, 10, 0), pos + V(0, 10, 0) + dir),
				gspec[3] == "Finish" and rgb(255, 230, 60) or rgb(60, 220, 255), Enum.Material.Neon)
			table.insert(checks, { Kind = gspec[3], Pos = pos, Dir = dir, Width = 8 })
		end
		length = straight * 2 + 2 * math.pi * radius
		startCF = CFrame.lookAt(at(-3, radius) + V(0, 3, 0), at(10, radius) + V(0, 3, 0))
		center = origin
		-- the auto run: round the middle of the track, lap after lap
		path = { at(0, radius), at(straight / 2, radius) }
		for k = 1, 7 do
			local a = k / 8 * math.pi
			table.insert(path, at(straight / 2 + math.sin(a) * radius, math.cos(a) * radius))
		end
		table.insert(path, at(straight / 2, -radius))
		table.insert(path, at(0, -radius))
		table.insert(path, at(-straight / 2, -radius))
		for k = 7, 1, -1 do
			local a = k / 8 * math.pi
			table.insert(path, at(-straight / 2 - math.sin(a) * radius, math.cos(a) * radius))
		end
		table.insert(path, at(-straight / 2, radius))
	end
	local prompt = startPrompt(model, (startCF * CFrame.new(0, -3, 3)).Position, "SPEED", opts.Color)
	return { Kind = "Speed", Model = model, Prompt = prompt, Start = startCF, Checks = checks, Length = length, Center = center, Extent = opts.Compact and 90 or 110,
		Path = path, Loop = not opts.Compact }
end

--------------------------------------------------------------------------------
-- Defending: attackers run at your goal line.
--------------------------------------------------------------------------------

function StationBuilder.Defending(parent, cf, opts)
	local model = station(parent, opts, "Defending")
	local length = opts.Compact and 56 or 70
	local width = opts.Compact and 40 or 50
	local look = flat(cf.LookVector).Unit
	local right = look:Cross(Vector3.yAxis)
	local origin = flat(cf.Position)
	local goalLine = CFrame.lookAt(origin, origin + look)
	pitch(model, goalLine * CFrame.new(0, 0, -length / 2 + 2), width + 6, length + 10)
	line(model, origin - right * width / 2, origin + right * width / 2, 0.9, 0.25, rgb(255, 60, 60))
	for _, s in ipairs({ -1, 1 }) do
		line(model, origin + right * s * width / 2, origin + right * s * width / 2 + look * length, 0.5)
	end
	for k = 0, 8 do
		local p = origin + look * length + right * (-width / 2 + k * width / 8)
		line(model, p - right * 1.5, p + right * 1.5, 0.5, 0.25, rgb(255, 230, 60))
	end
	goal(model, goalLine * CFrame.new(0, 0, 2.5), 16, 6, 4)
	local prompt = startPrompt(model, origin + look * 9, "TACKLE ZONE", opts.Color)
	return {
		Kind = "Defending", Model = model, Prompt = prompt, GoalLine = goalLine, Length = length, Width = width,
		Start = CFrame.lookAt(origin + look * 12 + V(0, 3, 0), origin + look * 40 + V(0, 3, 0)),
	}
end

--------------------------------------------------------------------------------
-- Gym: a squat rack, a bench and a sled (one station each).
--------------------------------------------------------------------------------

local function machine(parent, kind, cf)
	local m = Instance.new("Model")
	m.Name = kind
	m.Parent = parent
	disc(m, "Mat", cf.Position, 7, COL.Rubber, 0.25, Enum.Material.SmoothPlastic)
	local bar
	if kind == "Squat" then
		for _, s in ipairs({ -1, 1 }) do
			part(m, "Rack", V(0.6, 8, 0.6), cf * CFrame.new(s * 3.2, 4, 1.2), COL.Metal, Enum.Material.Metal)
			part(m, "Hook", V(0.8, 0.3, 1), cf * CFrame.new(s * 3.2, 5.2, 0.6), COL.NavyDark)
		end
		bar = rod(m, "Bar", (cf * CFrame.new(-4.2, 5.6, 0.6)).Position, (cf * CFrame.new(4.2, 5.6, 0.6)).Position, 0.3, COL.Metal, Enum.Material.Metal)
	elseif kind == "Bench" then
		part(m, "Bench", V(1.8, 1.4, 5.4), cf * CFrame.new(0, 0.9, -0.8), COL.Red)
		for _, s in ipairs({ -1, 1 }) do part(m, "Upright", V(0.4, 4.6, 0.4), cf * CFrame.new(s * 2.4, 2.3, 1.4), COL.Metal, Enum.Material.Metal) end
		bar = rod(m, "Bar", (cf * CFrame.new(-4, 4.4, 1.4)).Position, (cf * CFrame.new(4, 4.4, 1.4)).Position, 0.3, COL.Metal, Enum.Material.Metal)
	else
		part(m, "Sled", V(4, 1, 3), cf * CFrame.new(0, 0.5, -2.6), COL.Gold)
		part(m, "Handles", V(0.4, 3.8, 0.4), cf * CFrame.new(-1.4, 2.4, -1), COL.Metal, Enum.Material.Metal)
		part(m, "Handles", V(0.4, 3.8, 0.4), cf * CFrame.new(1.4, 2.4, -1), COL.Metal, Enum.Material.Metal)
		bar = part(m, "Bar", V(3.4, 1.2, 2.4), cf * CFrame.new(0, 1.6, -2.6), COL.NavyDark)
	end
	if kind ~= "Sled" then
		for _, s in ipairs({ -1, 1 }) do
			local plate = (cf * CFrame.new(s * 3.6, kind == "Squat" and 5.6 or 4.4, kind == "Squat" and 0.6 or 1.4)).Position
			local p = part(m, "Plate", V(0.5, 2.4, 2.4), CFrame.new(plate) * (cf - cf.Position), COL.NavyDark)
			p.Shape = Enum.PartType.Cylinder
		end
	end
	return m, bar
end

function StationBuilder.Gym(parent, cf, opts)
	local model = station(parent, opts, "Gym")
	local records = {}
	local kinds = opts.Machines or { "Squat", "Bench", "Sled" }
	local gap = 16
	for i, kind in ipairs(kinds) do
		local x = (i - (#kinds + 1) / 2) * gap
		local mcf = cf * CFrame.new(x, 0, 0)
		local m, bar = machine(model, kind, mcf)
		local spot = (mcf * CFrame.new(0, 0, 3.5)).Position
		local prompt = startPrompt(model, (mcf * CFrame.new(0, 0, 7)).Position, kind:upper(), opts.Color)
		table.insert(records, {
			Kind = "Gym", Machine = kind, Model = m, Bar = bar, Prompt = prompt,
			Spot = spot, Facing = CFrame.lookAt(spot, spot + flat(-mcf.LookVector)),
			Camera = mcf * CFrame.new(6, 6, 14),
		})
	end
	return records
end

return StationBuilder
