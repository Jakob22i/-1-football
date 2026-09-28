-- Everything you see and press while training. The server decides what
-- happens; this draws it: the targets and the ball, the aim and the power
-- bar, the lit passing targets, the countdown and timer on the courses, the
-- attackers in the Tackle Zone, the gym's timing bar, and the stadium match.
--
-- Controls: aim with the mouse (or tap/drag on a phone), hold the mouse or
-- the big button to power up, let go to shoot or pass. F / click / TACKLE to
-- tackle. Space / click / LIFT in the gym.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))
local DrillMath = require(ReplicatedStorage:WaitForChild("DrillMath"))
local StudTexture = require(ReplicatedStorage:WaitForChild("StudTexture"))
local PlayerFigure = require(ReplicatedStorage:WaitForChild("PlayerFigure"))
local Icons = require(ReplicatedStorage:WaitForChild("Icons"))

local TrainingClient = {}

local ctx
local player = Players.LocalPlayer
local new = FKit.new
local C = FKit.Color
local hud = {}
local S = nil          -- the running session
local controllers = {}

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- A phone or tablet with no mouse.
local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function statColor(stat)
	return Config.Stats[stat] and Config.Stats[stat].Color or C.Gold
end

local function rootOf()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------------------------------------
-- Local 3D things (only this player sees them)
--------------------------------------------------------------------------------

-- The player's own movement keys (off while a drill moves you by itself).
local function setControls(on)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = module:GetControls()
		if on then controls:Enable() else controls:Disable() end
	end)
end

local function localFolder()
	local f = workspace:FindFirstChild("LocalDrill")
	if not f then
		f = Instance.new("Folder")
		f.Name = "LocalDrill"
		f.Parent = workspace
		StudTexture.Watch(f)
	end
	return f
end

local function lpart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- A football: white with black patches.
local function makeBall(parent)
	local m = Instance.new("Model")
	m.Name = "Ball"
	local core = lpart(m, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = C.White })
	for _, d in ipairs({
		Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
		Vector3.new(0.6, 0.6, 0.6).Unit, Vector3.new(-0.6, 0.6, -0.6).Unit,
	}) do
		lpart(m, { Name = "Patch", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = C.Ink, CFrame = CFrame.new(d * 0.58) })
	end
	m.PrimaryPart = core
	m.Parent = parent
	return m
end

-- A real Roblox character (attackers, teammates, the keeper): your
-- friends' avatars when there are some, see PlayerFigure.
local figureCount = math.random(0, 50)
local function makeFigure(parent, kitName)
	figureCount += 1
	return PlayerFigure.Build(parent, kitName, { Local = true, Seed = figureCount })
end

-- Stands the figure on `pos` facing `facing`; with a stride it runs.
local function placeFigure(fig, pos, facing, stride)
	local flat = DrillMath.Flat(facing)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	-- the figure's pivot is the torso, 3 studs up
	PlayerFigure.Pose(fig, CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0) + flat), stride)
end

local function highlight(model, color)
	local h = Instance.new("Highlight")
	h.FillColor = color or C.Gold
	h.OutlineColor = C.White
	h.FillTransparency = 0.35
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = localFolder()
	return h
end

-- A bouncing arrow over something.
local function arrow(parent, text, color)
	local anchor = lpart(parent, { Name = "Arrow", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1 })
	local gui = new("BillboardGui", { Size = UDim2.fromOffset(90, 90), AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor, Parent = anchor })
	local l = FKit.text(gui, text or "\u{2B07}", 60, color or C.Gold, { Size = UDim2.fromScale(1, 1) })
	return anchor, gui, l
end

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

local function setCamera(cf, fov)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	tween(cam, 0.5, { CFrame = cf, FieldOfView = fov or 60 })
end

local function resetCamera()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then cam.CameraSubject = humanoid end
end

-- Where the mouse or a touch points, as a ray.
local lastTouch = nil
local function pointerRay()
	local cam = workspace.CurrentCamera
	if lastTouch then return cam:ScreenPointToRay(lastTouch.X, lastTouch.Y) end
	local m = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(m.X, m.Y)
end

local function rayPlane(ray, point, normal)
	local denom = ray.Direction:Dot(normal)
	if math.abs(denom) < 1e-4 then return nil end
	local t = (point - ray.Origin):Dot(normal) / denom
	if t < 0 then return nil end
	return ray.Origin + ray.Direction * t
end

--------------------------------------------------------------------------------
-- The training HUD
--------------------------------------------------------------------------------

local function buildHud()
	local root = new("Frame", { Name = "Training", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = ctx.Gui })
	FKit.screenScale(root, 1000, 560)
	hud.Root = root

	-- XP bar for the stat you are training, bottom centre
	local xpHolder = new("Frame", {
		Name = "XPBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(460, 62),
		BackgroundTransparency = 1, Parent = root,
	})
	hud.XPHolder = xpHolder
	hud.XP = FKit.bar(xpHolder, { Position = UDim2.fromOffset(40, 24), Size = UDim2.new(1, -40, 0, 34) })
	local badge = new("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.White, ZIndex = 3, Parent = xpHolder })
	FKit.corner(badge, UDim.new(0.5, 0))
	hud.XPBadgeGradient = FKit.gradient(badge, { C.White, C.Grey }, 90)
	FKit.stroke(badge, 4, C.Ink, true)
	hud.XPIcon = Icons.new(badge, "ball", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 4 })
	hud.XPStat = FKit.text(xpHolder, "SHO 60", 24, C.White, {
		Position = UDim2.fromOffset(64, -6), Size = UDim2.fromOffset(200, 28), TextXAlignment = Enum.TextXAlignment.Left,
	})
	hud.XPMult = FKit.text(xpHolder, "", 20, C.Gold, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -4), Size = UDim2.fromOffset(200, 26), TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- a line about the drill (streak, time, wave, rep) over the bar
	hud.Info = FKit.fit(root, "", 30, C.White, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -86), Size = UDim2.fromOffset(620, 36), RichText = true,
	})

	-- EXIT: in every drill, top right (or X on a keyboard); the server stops
	-- the drill and puts you back on its start pad
	hud.Leave = FKit.button(root, "\u{2715} EXIT", FKit.Palette.red, {
		Name = "Exit", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(140, 50),
	})
	hud.Leave.Label.Text = "EXIT"
	hud.Leave.Label.Position = UDim2.fromOffset(44, 1)
	hud.Leave.Label.Size = UDim2.new(1, -50, 1, -4)
	Icons.new(hud.Leave, "cross", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -1), Size = UDim2.fromOffset(30, 30), ZIndex = hud.Leave.ZIndex + 2 })
	hud.LeaveHint = FKit.text(hud.Leave, "PRESS X", 14, C.White, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(120, 18), ZIndex = 5,
	})
	hud.Leave.Activated:Connect(function() TrainingClient.Leave() end)

	-- the big action button (a must on phones, handy with a mouse too)
	local action, actionLabel = FKit.button(root, "SHOOT", FKit.Palette.orange, {
		Name = "Action", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -170, 1, -26), Size = UDim2.fromOffset(104, 104),
	})
	for _, d in ipairs(action:GetDescendants()) do
		if d:IsA("UICorner") then d.CornerRadius = UDim.new(0.5, 0) end
	end
	action:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	actionLabel.Size = UDim2.new(1, -20, 0.5, 0)
	actionLabel.Position = UDim2.new(0, 10, 0.22, 0)
	hud.Action, hud.ActionLabel = action, actionLabel
	action.MouseButton1Down:Connect(function()
		if S and S.Ctl and S.Ctl.PressBegan then S.Ctl.PressBegan(S, true) end
	end)
	action.MouseButton1Up:Connect(function()
		if S and S.Ctl and S.Ctl.PressEnded then S.Ctl.PressEnded(S, true) end
	end)

	-- power meter, with a green zone and (passing) where the target is
	local power = new("Frame", {
		Name = "Power", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -132), Size = UDim2.fromOffset(340, 30),
		BackgroundColor3 = C.Track, Visible = false, Parent = root,
	})
	FKit.corner(power, UDim.new(0.5, 0))
	FKit.stroke(power, 3.5, C.Ink, true)
	hud.PowerGreen = new("Frame", { BackgroundColor3 = C.Green, BackgroundTransparency = 0.2, Size = UDim2.fromScale(0.18, 1), Position = UDim2.fromScale(0.68, 0), Parent = power })
	hud.PowerFill = new("Frame", { BackgroundColor3 = C.White, Size = UDim2.fromScale(0, 1), Parent = power })
	FKit.corner(hud.PowerFill, UDim.new(0.5, 0))
	FKit.gradient(hud.PowerFill, { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 30) }, 0)
	hud.PowerFill.BackgroundTransparency = 0.15
	hud.PowerIdeal = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 6, 1, 12),
		BackgroundColor3 = C.White, Visible = false, ZIndex = 3, Parent = power })
	FKit.stroke(hud.PowerIdeal, 2, C.Ink, true)
	FKit.text(power, "POWER", 16, C.White, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(100, 18) })
	hud.Power = power

	-- the gym's timing bar
	local timing = new("Frame", {
		Name = "Timing", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -140), Size = UDim2.fromOffset(560, 56),
		BackgroundColor3 = C.Track, Visible = false, Parent = root,
	})
	FKit.corner(timing, 16)
	FKit.stroke(timing, 4, C.Ink, true)
	hud.TimingZone = new("Frame", { BackgroundColor3 = C.Green, Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.4, 0), Parent = timing })
	FKit.gradient(hud.TimingZone, { Color3.fromRGB(170, 255, 120), C.GreenDark }, 90)
	hud.TimingPerfect = new("Frame", { BackgroundColor3 = C.Gold, Size = UDim2.fromScale(0.05, 1), Position = UDim2.fromScale(0.475, 0), ZIndex = 2, Parent = timing })
	hud.TimingMarker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 10, 1, 18),
		BackgroundColor3 = C.White, ZIndex = 4, Parent = timing })
	FKit.corner(hud.TimingMarker, 4)
	FKit.stroke(hud.TimingMarker, 3, C.Ink, true)
	hud.Timing = timing

	-- big words in the middle (countdown, GOAL!)
	hud.Center = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = root })

	-- the score in a match
	local score = FKit.panel(root, { Name = "Score", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(300, 54), Visible = false }, 16)
	hud.ScoreText = FKit.fit(score, "YOU 0 - 0 THEM", 30, C.White, { Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4) })
	hud.Score = score
end

-- Big words in the middle that pop and fade.
local function shout(text, color, size, hold)
	local l = FKit.text(hud.Center, text, size or 64, C.White, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, (size or 64) + 12), ZIndex = 30,
	})
	l.TextStroke.Thickness = math.clamp((size or 64) / 10, 3, 7)
	FKit.gradient(l, { (color or C.Gold):Lerp(C.White, 0.6), color or C.Gold }, 90)
	FKit.pop(l, 0.4, 0.35)
	task.delay(hold or 0.9, function()
		if not l.Parent then return end
		tween(l, 0.3, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, -30) })
		tween(l.TextStroke, 0.3, { Transparency = 1 })
		task.delay(0.35, function() l:Destroy() end)
	end)
	return l
end
TrainingClient.Shout = function(...) return shout(...) end

-- "+12 XP" floating up off your head.
-- "+12 XP" in the middle of the screen (like Muscle Legends): it pops in a
-- little to the side, floats up and fades. Pops close together stack up.
local popsLive = 0
local function xpPop(amount, stat)
	local gui = ctx.Gui
	if not gui then return end
	popsLive += 1
	local lift = math.min(popsLive - 1, 3) * 34
	local holder = new("Frame", {
		Name = "XPPop", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.16, 0, 0.44, -lift), Size = UDim2.fromOffset(260, 64),
		ZIndex = 40, Parent = gui,
	})
	local color = statColor(stat)
	local l = FKit.text(holder, "+" .. Config.Short(amount) .. " XP", 46, C.White, { Size = UDim2.new(1, 0, 0.72, 0), ZIndex = 41 })
	local shade = l:FindFirstChild("TextShade")
	if shade then shade:Destroy() end
	FKit.gradient(l, { color:Lerp(C.White, 0.55), color }, 90)
	local tag = Config.Stats[stat] and FKit.text(holder, Config.Stats[stat].Name:upper(), 20, color:Lerp(C.White, 0.3), {
		Position = UDim2.fromScale(0, 0.7), Size = UDim2.new(1, 0, 0.3, 0), ZIndex = 41,
	})
	FKit.pop(holder, 0.3, 0.22)
	tween(holder, 1.2, { Position = holder.Position - UDim2.fromOffset(0, 70) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.8, function()
		for _, t in ipairs({ l, tag }) do
			if t then
				tween(t, 0.4, { TextTransparency = 1 })
				tween(t.TextStroke, 0.4, { Transparency = 1 })
			end
		end
	end)
	task.delay(1.25, function()
		popsLive = math.max(0, popsLive - 1)
		holder:Destroy()
	end)
end

local function setXPBar(stat)
	if stat == "ALL" or not Config.Stats[stat] then
		hud.XPHolder.Visible = false
		return
	end
	hud.XPHolder.Visible = true
	local def = Config.Stats[stat]
	local level = player:GetAttribute(stat) or Config.StartLevel
	local xp = player:GetAttribute("XP_" .. stat) or 0
	local need = player:GetAttribute("Need_" .. stat) or 1
	Icons.set(hud.XPIcon, Icons.Stat[stat] or "star")
	hud.XPBadgeGradient.Color = ColorSequence.new(def.Color:Lerp(C.White, 0.4), def.Color)
	hud.XP.Gradient.Color = ColorSequence.new(def.Color:Lerp(C.White, 0.45), def.Color)
	hud.XPStat.Text = ("%s %d"):format(stat, level)
	if level >= Config.MaxLevel then
		hud.XP.Set(1, "MAX", true)
	else
		hud.XP.Set(xp / math.max(need, 1), ("%s / %s XP"):format(Config.Short(xp), Config.Short(need)), true)
	end
	local mult = player:GetAttribute("XPMultiplier") or 1
	hud.XPMult.Text = mult > 1.001 and ("x%.2g XP"):format(mult) or ""
end

function TrainingClient.OnXP(data)
	if data.Amount and data.Amount > 0 then xpPop(data.Amount, data.Stat) end
	if S and S.Stat == data.Stat and data.Need then
		if data.Need == 0 then
			hud.XP.Set(1, "MAX")
		else
			hud.XP.Set(data.XP / data.Need, ("%s / %s XP"):format(Config.Short(data.XP), Config.Short(data.Need)))
		end
		hud.XPStat.Text = ("%s %d"):format(data.Stat, data.Level or 0)
	end
end

function TrainingClient.OnStatUp(data)
	if S and S.Stat == data.Stat then
		FKit.pop(hud.XPHolder, 1.15, 0.3)
		shout(("+1 %s!"):format(data.Stat), statColor(data.Stat), 54, 0.7)
	end
end

--------------------------------------------------------------------------------
-- Power (hold to charge: 0 -> 1 -> 0 over and over)
--------------------------------------------------------------------------------

local CHARGE_TIME = 1.05

local function chargeValue(since)
	local x = (os.clock() - since) / CHARGE_TIME % 2
	return x <= 1 and x or 2 - x
end

local function showPower(on, green, ideal)
	hud.Power.Visible = on
	if green then
		hud.PowerGreen.Visible = true
		hud.PowerGreen.Position = UDim2.fromScale(green[1], 0)
		hud.PowerGreen.Size = UDim2.fromScale(green[2] - green[1], 1)
	else
		hud.PowerGreen.Visible = false
	end
	hud.PowerIdeal.Visible = ideal ~= nil
	if ideal then hud.PowerIdeal.Position = UDim2.fromScale(math.clamp(ideal, 0, 1), 0.5) end
end

--------------------------------------------------------------------------------
-- Shooting (also the stadium's attack moments)
--------------------------------------------------------------------------------

-- A shooting setup: the goal, targets (or a keeper), the aim ring, the ball.
local function shootSetup(s, spot, goalCF, width, height, green)
	s.Spot, s.Goal, s.GoalW, s.GoalH, s.Green = spot, goalCF, width, height, green
	s.Aim = { 0, height / 2 }
	s.TargetParts = {}
	local folder = localFolder()
	s.Ball = makeBall(folder)
	local goalMid = DrillMath.GoalPoint(goalCF, 0, 0)
	local back = DrillMath.Flat(spot - goalMid).Unit
	s.BallHome = spot + Vector3.new(0, 0.8, 0) - back * 1.4
	s.Ball:PivotTo(CFrame.new(s.BallHome))
	s.Reticle = lpart(folder, { Name = "Aim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.6, 1.6), Color = C.White, Material = Enum.Material.Neon, Transparency = 0.2 })
	s.ReticleDot = lpart(folder, { Name = "AimDot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.45, 0.45), Color = C.Red, Material = Enum.Material.Neon })
	local camPos = spot + back * 13 + Vector3.new(0, 7.5, 0)
	setCamera(CFrame.lookAt(camPos, goalMid + Vector3.new(0, 3.2, 0)), 55)
	showPower(false)
end

local function goalCFrameAt(s, u, v, out)
	return s.Goal * CFrame.new(u, v, -(out or 0.3)) * CFrame.Angles(0, math.rad(90), 0)
end

local function buildTargets(s, list)
	for _, parts in pairs(s.TargetParts) do
		for _, p in ipairs(parts) do p:Destroy() end
	end
	s.TargetParts = {}
	s.TargetList = {}
	for _, t in ipairs(list or {}) do
		local folder = localFolder()
		local outer = t.Corner and Color3.fromRGB(255, 200, 30) or Color3.fromRGB(255, 60, 70)
		local parts = {
			lpart(folder, { Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, t.R * 2, t.R * 2), Color = outer, Material = Enum.Material.Neon }),
			lpart(folder, { Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, t.R * 1.3, t.R * 1.3), Color = C.White, Material = Enum.Material.Neon }),
			lpart(folder, { Name = "Target", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, t.R * 0.6, t.R * 0.6), Color = outer, Material = Enum.Material.Neon }),
		}
		s.TargetParts[t.Id] = parts
		table.insert(s.TargetList, t)
	end
end

local function updateTargets(s, now)
	for _, t in ipairs(s.TargetList or {}) do
		local parts = s.TargetParts[t.Id]
		if parts then
			local u, v = DrillMath.TargetPos(t, now)
			for i, p in ipairs(parts) do p.CFrame = goalCFrameAt(s, u, v, 0.3 + i * 0.03) end
		end
	end
end

local function updateAim(s)
	local hit = rayPlane(pointerRay(), s.Goal.Position, s.Goal.LookVector)
	if hit then
		local lp = s.Goal:PointToObjectSpace(hit)
		s.Aim = { math.clamp(lp.X, -s.GoalW / 2 - 3, s.GoalW / 2 + 3), math.clamp(lp.Y, 0, s.GoalH + 3) }
	end
	s.Reticle.CFrame = goalCFrameAt(s, s.Aim[1], s.Aim[2], 0.6)
	s.ReticleDot.CFrame = goalCFrameAt(s, s.Aim[1], s.Aim[2], 0.62)
end

-- The ball flies to (u, v) on the goal mouth by `arrive`, then drops.
local function flyBall(s, u, v, arrive, inGoal)
	local ball = s.Ball
	local from = s.BallHome
	local to = DrillMath.GoalPoint(s.Goal, u, v) - s.Goal.LookVector * (inGoal and -1.5 or -3)
	local mid = (from + to) / 2 + Vector3.new(0, 2 + (to - from).Magnitude * 0.05, 0)
	local started = os.clock()
	local duration = math.max(0.2, arrive - ctx.Now())
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / duration, 0, 1)
		local a = from:Lerp(mid, k)
		local b = mid:Lerp(to, k)
		ball:PivotTo(CFrame.new(a:Lerp(b, k)) * CFrame.Angles(k * 20, k * 12, 0))
		if k >= 1 then conn:Disconnect() end
	end)
	task.delay(duration, function()
		if inGoal then ctx.Sound("Net") end
		task.wait(0.5)
		if ball.Parent then ball:PivotTo(CFrame.new(s.BallHome)) end
	end)
end

local function shootPressBegan(s)
	if s.Charging or not s.CanShoot then return end
	s.Charging = true
	s.ChargeSince = os.clock()
	showPower(true, s.Green)
end

local function shootPressEnded(s, send)
	if not s.Charging then return end
	s.Charging = false
	local power = chargeValue(s.ChargeSince)
	showPower(false)
	ctx.Sound("Kick")
	local u, v = s.Aim[1], s.Aim[2]
	task.spawn(function()
		local ok, result = pcall(function() return ctx.Remotes.Train:InvokeServer("Shoot", u, v, power) end)
		if ok and result and result.U then send(s, result) end
	end)
end

controllers.Shooting = {
	Action = "SHOOT",
	Start = function(s, data)
		shootSetup(s, data.Spot, data.Goal, data.GoalWidth, data.GoalHeight, data.Green)
		buildTargets(s, data.Targets)
		s.CanShoot = true
		s.Streak = 0
		s.FireUntil = 0
		hud.Info.Text = (touchOnly() and "Tap to aim, hold SHOOT" or "Aim with the mouse, hold to power up")
			.. ", let go in the <font color=\"#6BFF7A\">green</font>!"
	end,
	Update = function(s)
		local now = ctx.Now()
		updateTargets(s, now)
		updateAim(s)
		if s.Charging then hud.PowerFill.Size = UDim2.fromScale(chargeValue(s.ChargeSince), 1) end
		if s.FireUntil > now then
			hud.Info.Text = ("\u{1F525} <font color=\"#FFB020\">ON FIRE x2 XP</font>  %ds   STREAK %d"):format(math.ceil(s.FireUntil - now), s.Streak)
		elseif s.Streak > 0 then
			hud.Info.Text = ("STREAK %d  <font color=\"#FFD84A\">%d more for ON FIRE</font>"):format(s.Streak, 5 - s.Streak % 5)
		end
	end,
	PressBegan = function(s) shootPressBegan(s) end,
	PressEnded = function(s)
		shootPressEnded(s, function(ss, r)
			flyBall(ss, r.U, r.V, r.Time, r.Result ~= "miss")
			local wait = math.max(0, r.Time - ctx.Now())
			task.delay(wait, function()
				if S ~= ss then return end
				if r.Result == "corner" then
					shout("TOP CORNER!", C.Gold, 70)
					ctx.Sound("Perfect")
					ctx.Sound("Cheer", 0.6)
				elseif r.Result == "hit" then
					shout("GOAL!", C.Green, 70)
					ctx.Sound("Ding")
				elseif r.Result == "goal" then
					shout("ON TARGET", C.White, 44)
				else
					shout("MISS", C.Red, 50)
					ctx.Sound("Miss")
				end
				if r.OnFire then
					shout("\u{1F525} ON FIRE! x2 XP \u{1F525}", C.Orange, 60, 1.3)
					ctx.Sound("Fire")
				end
				ss.Streak = r.Streak or 0
				ss.FireUntil = r.FireUntil or 0
				if r.Targets then buildTargets(ss, r.Targets) end
			end)
		end)
	end,
	Event = function(s, kind, data)
		if kind == "targets" then buildTargets(s, data.Targets) end
	end,
	Stop = function() end,
}

--------------------------------------------------------------------------------
-- Passing (also the stadium's pass moments)
--------------------------------------------------------------------------------

local function passSetup(s, spot, facing, maxDistance)
	s.Spot, s.MaxDistance = spot, maxDistance
	local folder = localFolder()
	s.Ball = makeBall(folder)
	local forward = DrillMath.Flat(facing.LookVector).Unit
	s.BallHome = spot + Vector3.new(0, 0.8, 0) + forward * 1.4
	s.Ball:PivotTo(CFrame.new(s.BallHome))
	s.AimLine = lpart(folder, { Name = "AimLine", Size = Vector3.new(0.3, 0.1, 1), Color = C.Gold, Material = Enum.Material.Neon, Transparency = 0.25 })
	s.AimRing = lpart(folder, { Name = "AimRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3.2, 3.2), Color = C.Gold, Material = Enum.Material.Neon, Transparency = 0.45 })
	s.Aim = spot + forward * 25
	setCamera(CFrame.lookAt(spot - forward * 15 + Vector3.new(0, 17, 0), spot + forward * 24), 58)
end

local function updatePassAim(s)
	local hit = rayPlane(pointerRay(), Vector3.new(0, 0.2, 0), Vector3.yAxis)
	if hit then s.Aim = Vector3.new(hit.X, 0, hit.Z) end
	local from = DrillMath.Flat(s.Spot) + Vector3.new(0, 0.3, 0)
	local to = DrillMath.Flat(s.Aim) + Vector3.new(0, 0.3, 0)
	local length = math.max(0.5, (to - from).Magnitude)
	s.AimLine.Size = Vector3.new(0.3, 0.1, length)
	s.AimLine.CFrame = CFrame.lookAt((from + to) / 2, to)
	s.AimRing.CFrame = CFrame.new(to) * CFrame.Angles(0, 0, math.rad(90))
end

local function rollBall(s, landing, lift)
	local ball = s.Ball
	local from = s.BallHome
	local to = DrillMath.Flat(landing) + Vector3.new(0, 0.8, 0)
	local distance = (to - from).Magnitude
	local duration = 0.35 + distance / 55
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = 1 - (1 - k) ^ 2
		local pos = from:Lerp(to, eased) + Vector3.new(0, (lift or 0) * math.sin(math.pi * eased), 0)
		ball:PivotTo(CFrame.new(pos) * CFrame.Angles(eased * distance * 0.8, 0, 0))
		if k >= 1 then conn:Disconnect() end
	end)
	task.delay(duration + 0.5, function()
		if ball.Parent then ball:PivotTo(CFrame.new(s.BallHome)) end
	end)
	return duration
end

local function litTarget(s)
	for _, t in ipairs(s.Targets or {}) do
		if s.Lit and t.Id == s.Lit.Id then return t end
	end
	return nil
end

local function showLit(s)
	if s.Highlight then s.Highlight:Destroy(); s.Highlight = nil end
	if s.LitArrow then s.LitArrow:Destroy(); s.LitArrow = nil end
	local t = litTarget(s)
	if not t then return end
	s.LitShown = false
	s.LitWaitTarget = t
end

controllers.Passing = {
	Action = "PASS",
	Start = function(s, data)
		passSetup(s, data.Spot, data.Facing, data.MaxDistance)
		s.Targets = data.Targets
		s.Lit = data.Lit
		showLit(s)
		hud.Info.Text = "Pass to the target that lights up. Hold, then let go at the white line!"
	end,
	Update = function(s)
		local now = ctx.Now()
		updatePassAim(s)
		local t = s.LitWaitTarget
		if t and not s.LitShown and now >= s.Lit.Since then
			s.LitShown = true
			s.Highlight = highlight(t.Model, t.Kind == "Ring" and Color3.fromRGB(60, 230, 255) or C.Gold)
			local anchor = arrow(localFolder(), "\u{2B07}", C.Gold)
			anchor.CFrame = CFrame.new((t.Center or t.Pos) + Vector3.new(0, 9, 0))
			s.LitArrow = anchor
			s.LitBase = anchor.CFrame
			ctx.Sound("Beep", 1, 1.4)
		end
		if s.LitArrow and s.LitBase then
			s.LitArrow.CFrame = s.LitBase + Vector3.new(0, math.sin(os.clock() * 6) * 0.7, 0)
		end
		if s.Lit and now < s.Lit.Expires and s.LitShown then
			local left = s.Lit.Expires - now
			hud.Info.Text = ("PASS NOW!  <font color=\"#FFD84A\">%.1fs</font>"):format(left)
		end
		if s.Charging then hud.PowerFill.Size = UDim2.fromScale(chargeValue(s.ChargeSince), 1) end
	end,
	PressBegan = function(s)
		if s.Charging then return end
		s.Charging = true
		s.ChargeSince = os.clock()
		local t = litTarget(s)
		local ideal = t and (DrillMath.Flat(t.Pos) - DrillMath.Flat(s.Spot)).Magnitude / s.MaxDistance
		showPower(true, nil, ideal)
	end,
	PressEnded = function(s)
		if not s.Charging then return end
		s.Charging = false
		local power = chargeValue(s.ChargeSince)
		showPower(false)
		ctx.Sound("Kick", 0.8, 1.15)
		local aim = s.Aim
		task.spawn(function()
			local ok, r = pcall(function() return ctx.Remotes.Train:InvokeServer("Pass", aim.X, aim.Z, power) end)
			if not (ok and r and r.Landing) or S ~= s then return end
			local target = litTarget(s)
			local duration = rollBall(s, r.Landing, target and target.Kind == "Ring" and 2.6 or 0)
			task.delay(duration, function()
				if S ~= s then return end
				if r.Success then
					shout(r.Quick and "QUICK PASS!" or "NICE PASS!", C.Green, 60)
					ctx.Sound("Ding")
				else
					shout("MISSED", C.Red, 50)
					ctx.Sound("Miss")
				end
				if r.Next then
					s.Lit = r.Next
					showLit(s)
				end
			end)
		end)
	end,
	Event = function(s, kind, data)
		if kind == "lit" then
			if data.Missed then shout("TOO SLOW!", C.Red, 44) end
			s.Lit = data.Lit
			showLit(s)
		end
	end,
	Stop = function(s)
		if s.Highlight then s.Highlight:Destroy() end
	end,
}

--------------------------------------------------------------------------------
-- Courses: the Speed Course and the Dribbling Cones
--------------------------------------------------------------------------------

local function countdown(s, goAt)
	s.CountFrom = nil
	s.GoAt = goAt
end

local function markNext(s)
	local check = s.Checks[s.Next]
	if not check then
		if s.Marker then s.Marker.Transparency = 1 end
		return
	end
	local pos = check.Pos + Vector3.new(0, 7, 0)
	if check.Kind == "Cone" then
		pos = check.Pos + DrillMath.Right(check.Dir) * check.Side * 2.6 + Vector3.new(0, 4.5, 0)
	end
	s.MarkerBase = CFrame.new(pos)
	s.MarkerLabel.Text = (check.Kind == "Finish") and "\u{1F3C1}" or "\u{2B07}"
end

local function courseStart(s, data)
	s.Checks = data.Checks
	s.Cones = data.Cones
	s.Next = 1
	s.Penalty = 0
	local anchor, _, l = arrow(localFolder(), "\u{2B07}", C.Gold)
	s.Marker, s.MarkerLabel = anchor, l
	if data.Kind == "Dribbling" then
		s.Ball = makeBall(localFolder())
	end
	-- find the cone models near each cone position (to wobble them)
	s.ConeModels = {}
	if s.Cones then
		local station = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild(data.Station, true)
		for i, pos in ipairs(s.Cones) do
			for _, m in ipairs(station and station:GetChildren() or {}) do
				if m.Name == "Cone" and m:IsA("Model") then
					local p = m:GetPivot().Position
					if (DrillMath.Flat(p) - DrillMath.Flat(pos)).Magnitude < 1 then s.ConeModels[i] = m end
				end
			end
		end
	end
	markNext(s)
	resetCamera()
end

local function courseUpdate(s)
	local now = ctx.Now()
	if s.GoAt then
		local left = s.GoAt - now
		if left > 0 then
			local n = math.ceil(left)
			if n ~= s.CountShown then
				s.CountShown = n
				shout(tostring(n), C.White, 110, 0.6)
				ctx.Sound("Beep")
			end
			hud.Info.Text = "GET READY..."
		else
			if s.CountShown and s.CountShown > 0 then
				s.CountShown = 0
				shout("GO!", C.Green, 120, 0.7)
				ctx.Sound("Go")
				ctx.Sound("Whistle", 0.6)
				s.Running = true
				s.RunStart = s.GoAt
			end
			if s.Running then
				hud.Info.Text = ("TIME <font color=\"#FFD84A\">%.1fs</font>%s"):format(now - s.RunStart,
					s.Penalty > 0 and ("  <font color=\"#FF6A6A\">+%ds</font>"):format(s.Penalty) or "")
			end
		end
	end
	if s.Marker and s.MarkerBase then
		s.Marker.CFrame = s.MarkerBase + Vector3.new(0, math.sin(os.clock() * 6) * 0.6, 0)
	end
	-- the ball at your feet
	if s.Ball then
		local root = rootOf()
		if root then
			local look = DrillMath.Flat(root.CFrame.LookVector)
			if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
			local pos = root.Position + look.Unit * 2.2 + Vector3.new(0, -2.2, 0)
			local speed = root.AssemblyLinearVelocity.Magnitude
			s.Roll = (s.Roll or 0) + speed * 0.02
			s.Ball:PivotTo(CFrame.new(pos + Vector3.new(0, math.abs(math.sin(s.Roll * 1.2)) * 0.3, 0)) * CFrame.Angles(-s.Roll, 0, 0))
		end
	end
end

local function courseEvent(s, kind, data)
	if kind == "run" then
		s.Next = 1
		s.Penalty = 0
		s.Running = false
		s.CountShown = nil
		countdown(s, data.GoAt)
		markNext(s)
	elseif kind == "check" then
		s.Next = data.Index + 1
		s.Penalty = data.Penalty or s.Penalty
		if data.Good then
			ctx.Sound("Tick", 1, 1.6)
		else
			shout("WRONG SIDE! +2s", C.Red, 46)
			ctx.Sound("Error")
		end
		markNext(s)
	elseif kind == "cone" then
		s.Penalty = data.Penalty or s.Penalty
		shout("CONE! +1s", C.Orange, 46)
		ctx.Sound("Cone")
		local m = s.ConeModels and s.ConeModels[data.Index]
		if m then
			local home = m:GetPivot()
			m:PivotTo(home * CFrame.Angles(math.rad(18), 0, 0))
			task.delay(0.25, function() if m.Parent then m:PivotTo(home) end end)
		end
	elseif kind == "runDone" then
		s.Running = false
		s.GoAt = nil
		if data.Rejected then
			shout("RUN NOT COUNTED", C.Red, 50, 1.4)
		elseif data.TimedOut then
			shout("TIME UP!", C.Red, 60, 1.2)
		else
			local lines = ("%.2fs"):format(data.Time)
			shout(data.Perfect and "PERFECT RUN!" or (data.Record and "NEW RECORD!" or "FINISH!"), data.Perfect and C.Gold or C.Green, 70, 1.6)
			ctx.Sound(data.Perfect and "Perfect" or "Chime")
			ctx.Sound("Cheer", 0.5)
			hud.Info.Text = ("TIME <font color=\"#FFD84A\">%s</font>   BEST <font color=\"#6BFF7A\">%.2fs</font>"):format(lines, data.Best or data.Time)
		end
	end
end

-- The Speed Course runs itself: your character runs round the track on
-- its own, never stopping (the next point is set before it gets to the
-- last one), and XP comes every second while you run.
local function humanoidOf()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function autoStart(s, data)
	s.Path, s.Loop, s.Dir = data.Path, data.Loop, 1
	s.Speed = data.Speed or 20
	s.Laps = 0
	setControls(false)
	-- start from the nearest point ahead
	local root = rootOf()
	local best, bestD = 1, math.huge
	for i, p in ipairs(s.Path) do
		local d = root and (DrillMath.Flat(p) - DrillMath.Flat(root.Position)).Magnitude or 0
		if d < bestD then best, bestD = i, d end
	end
	s.I = s.Loop and (best % #s.Path + 1) or best
	resetCamera()
end

local function autoUpdate(s)
	local humanoid, root = humanoidOf(), rootOf()
	if not (humanoid and root and s.Path) then return end
	local target = s.Path[s.I]
	local d = (DrillMath.Flat(target) - DrillMath.Flat(root.Position)).Magnitude
	if d < math.max(3.5, humanoid.WalkSpeed * 0.32) then
		if s.Loop then
			s.I = s.I % #s.Path + 1
		else
			s.I += s.Dir
			if s.I > #s.Path then s.Dir, s.I = -1, #s.Path - 1 end
			if s.I < 1 then s.Dir, s.I = 1, 2 end
		end
		s.MoveAt = nil
		target = s.Path[s.I]
	end
	if not s.MoveAt or os.clock() - s.MoveAt > 2 then
		s.MoveAt = os.clock()
		humanoid:MoveTo(target)
	end
	hud.Info.Text = ("AUTO RUN   SPEED <font color=\"#6BE4FF\">%d</font>%s"):format(math.floor(humanoid.WalkSpeed + 0.5),
		s.Best and ("   BEST LAP <font color=\"#FFD84A\">%.1fs</font>"):format(s.Best) or "")
end

local function autoEvent(s, kind, data)
	if kind == "lap" then
		s.Laps, s.Best = data.Laps, data.Best
		shout(("LAP %.1fs"):format(data.Time), C.Green, 44, 0.9)
		ctx.Sound("Chime")
	elseif kind == "speed" then
		s.Speed = data.Speed
		shout("FASTER!", Color3.fromRGB(90, 220, 255), 46, 0.8)
	end
end

local function autoStop()
	setControls(true)
	local humanoid, root = humanoidOf(), rootOf()
	if humanoid and root then humanoid:MoveTo(root.Position) end
end

controllers.Speed = {
	Action = nil,
	Start = function(s, data)
		s.AutoRun = data.Auto and data.Path ~= nil
		if s.AutoRun then return autoStart(s, data) end
		return courseStart(s, data)
	end,
	Update = function(s, dt)
		if s.AutoRun then return autoUpdate(s, dt) end
		return courseUpdate(s, dt)
	end,
	Event = function(s, kind, data)
		if s.AutoRun then return autoEvent(s, kind, data) end
		return courseEvent(s, kind, data)
	end,
	Stop = function(s)
		if s.AutoRun then autoStop() end
	end,
}
controllers.Dribbling = { Action = nil, Start = courseStart, Update = courseUpdate, Event = courseEvent }

--------------------------------------------------------------------------------
-- Defending (also the stadium's defend moments)
--------------------------------------------------------------------------------

local function addAttackers(s, list)
	s.Attackers = s.Attackers or {}
	for _, att in ipairs(list) do
		local fig = makeFigure(localFolder(), "Attacker")
		local ball = makeBall(localFolder())
		s.Attackers[att.Id] = { Data = att, Figure = fig, Ball = ball }
		placeFigure(fig, att.Start, att.End - att.Start)
	end
end

local function removeAttacker(s, id, tackled)
	local a = s.Attackers and s.Attackers[id]
	if not a then return end
	s.Attackers[id] = nil
	if tackled then
		local pivot = a.Figure:GetPivot()
		a.Figure:PivotTo(pivot * CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(80), 0, 0))
		task.delay(0.8, function()
			a.Figure:Destroy()
			a.Ball:Destroy()
		end)
	else
		a.Figure:Destroy()
		a.Ball:Destroy()
	end
end

local function updateAttackers(s)
	local now = ctx.Now()
	local root = rootOf()
	local reach = Config.Drills.Defending.Reach + Config.Drills.Defending.ReachPerLevel * math.max(0, (player:GetAttribute("DEF") or 60) - 60)
	local nearest, nearestD = nil, math.huge
	for _, a in pairs(s.Attackers or {}) do
		local d = a.Data
		local pos = DrillMath.AttackerPos(d, now)
		local ahead = DrillMath.AttackerPos(d, now + 0.1)
		placeFigure(a.Figure, pos, ahead - pos, now >= d.T0 and now * 11 or nil)
		local dir = DrillMath.Flat(ahead - pos)
		local lead = dir.Magnitude > 0.01 and dir.Unit * 1.8 or Vector3.zero
		a.Ball:PivotTo(CFrame.new(pos + lead + Vector3.new(0, 0.8, 0)) * CFrame.Angles(now * 8, 0, 0))
		if root and now >= d.T0 then
			local dist = (DrillMath.Flat(pos) - DrillMath.Flat(root.Position)).Magnitude
			if dist < nearestD then nearest, nearestD = pos, dist end
		end
	end
	if not s.ReachRing then
		s.ReachRing = lpart(localFolder(), { Name = "Reach", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6, 6), Color = C.Green,
			Material = Enum.Material.Neon, Transparency = 0.4 })
	end
	if nearest and nearestD <= reach then
		s.ReachRing.Transparency = 0.35
		s.ReachRing.CFrame = CFrame.new(DrillMath.Flat(nearest) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		s.ReachRing.Transparency = 1
	end
end

local function tackle(s)
	if (s.LastTackle or 0) > os.clock() - 0.35 then return end
	s.LastTackle = os.clock()
	ctx.Sound("Whoosh", 0.8, 1.4)
	task.spawn(function()
		local ok, r = pcall(function() return ctx.Remotes.Train:InvokeServer("Tackle") end)
		if not (ok and r) or S ~= s then return end
		if r.Result == "stop" then
			removeAttacker(s, r.Attacker, true)
			shout("TACKLE!", C.Blue, 64)
			ctx.Sound("Tackle")
		elseif r.Result == "miss" then
			shout("TOO FAR!", C.Grey, 40, 0.5)
		end
	end)
end

local function hearts(n)
	local t = {}
	for i = 1, Config.Drills.Defending.Lives do
		table.insert(t, i <= n and "<font color=\"#FF4A5A\">\u{2764}</font>" or "<font color=\"#555A70\">\u{2764}</font>")
	end
	return table.concat(t, " ")
end

controllers.Defending = {
	Action = "TACKLE",
	Start = function(s, data)
		s.Lives = data.Lives
		s.Wave = 0
		s.Attackers = {}
		resetCamera()
		hud.Info.Text = touchOnly() and "Run to the attackers and press TACKLE!" or "Run to the attackers and tackle! (F, click or TACKLE)"
	end,
	Update = function(s)
		updateAttackers(s)
		if s.Wave > 0 then hud.Info.Text = ("WAVE %d   %s"):format(s.Wave, hearts(s.Lives)) end
	end,
	PressBegan = function(s) tackle(s) end,
	Event = function(s, kind, data)
		if kind == "wave" then
			s.Wave = data.Wave
			s.Lives = data.Lives
			addAttackers(s, data.Attackers)
			shout("WAVE " .. data.Wave, C.Blue, 64, 0.9)
			ctx.Sound("Whistle", 0.7)
		elseif kind == "goalAgainst" then
			removeAttacker(s, data.Attacker, false)
			s.Lives = data.Lives
			shout("THEY SCORED!", C.Red, 60)
			ctx.Sound("Groan")
		elseif kind == "waveClear" then
			shout("WAVE CLEAR!", C.Green, 60)
			ctx.Sound("Chime")
		end
	end,
	Stop = function() end,
}

--------------------------------------------------------------------------------
-- Gym
--------------------------------------------------------------------------------

-- The body lifting: the joints of your own character bend with `p`
-- (0 = the top of the lift, 1 = the bottom), and the bar or sled moves with
-- your hands. Each lift runs one rep (LIFT_TIME).
local JOINTS = {
	Root = "LowerTorso", Waist = "UpperTorso",
	RightShoulder = "RightUpperArm", LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm", LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg", LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg", LeftKnee = "LeftLowerLeg",
}
local r = math.rad
local POSES = {
	-- hands up by the shoulders holding the bar, then sit down into a squat
	Squat = function(p)
		return {
			Root = CFrame.new(0, -1.25 * p, 0),
			Waist = CFrame.Angles(r(-18 * p), 0, 0), -- lean forward
			RightShoulder = CFrame.Angles(r(160), 0, r(18)), LeftShoulder = CFrame.Angles(r(160), 0, r(-18)),
			RightElbow = CFrame.Angles(r(115), 0, 0), LeftElbow = CFrame.Angles(r(115), 0, 0),
			RightHip = CFrame.Angles(r(85 * p), 0, 0), LeftHip = CFrame.Angles(r(85 * p), 0, 0),
			RightKnee = CFrame.Angles(r(-105 * p), 0, 0), LeftKnee = CFrame.Angles(r(-105 * p), 0, 0),
		}
	end,
	-- lying on the bench: arms straight up at the top, bent at the bottom
	Bench = function(p)
		return {
			RightShoulder = CFrame.Angles(r(90 - 100 * p), 0, r(8 + 30 * p)), LeftShoulder = CFrame.Angles(r(90 - 100 * p), 0, r(-8 - 30 * p)),
			RightElbow = CFrame.Angles(r(105 * p), 0, 0), LeftElbow = CFrame.Angles(r(105 * p), 0, 0),
			RightHip = CFrame.Angles(r(-10), 0, 0), LeftHip = CFrame.Angles(r(-10), 0, 0),
			RightKnee = CFrame.Angles(r(-25), 0, 0), LeftKnee = CFrame.Angles(r(-25), 0, 0),
		}
	end,
	-- leaning into the sled: arms on the handles, legs driving
	Sled = function(p, t)
		local stride = math.sin(t * 9) * 32 * (1 - p)
		return {
			Root = CFrame.Angles(r(-28), 0, 0) * CFrame.new(0, -0.3, 0),
			Waist = CFrame.Angles(r(-8), 0, 0),
			RightShoulder = CFrame.Angles(r(95), 0, 0), LeftShoulder = CFrame.Angles(r(95), 0, 0),
			RightElbow = CFrame.Angles(r(35), 0, 0), LeftElbow = CFrame.Angles(r(35), 0, 0),
			RightHip = CFrame.Angles(r(30 + stride), 0, 0), LeftHip = CFrame.Angles(r(30 - stride), 0, 0),
			RightKnee = CFrame.Angles(r(-40), 0, 0), LeftKnee = CFrame.Angles(r(-40), 0, 0),
		}
	end,
}

local function liftStart(s)
	local character = player.Character
	if not character then return end
	s.Joints = {}
	for name, partName in pairs(JOINTS) do
		local holder = character:FindFirstChild(partName)
		local motor = holder and holder:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then s.Joints[name] = { Motor = motor, C0 = motor.C0 } end
	end
	-- the machine's moving parts, kept relative to the bar
	s.Moving = {}
	local bar = s.Bar
	if bar and bar.Parent then
		s.BarHome = bar.CFrame
		for _, d in ipairs(bar.Parent:GetChildren()) do
			if d:IsA("BasePart") and (d.Name == "Bar" or d.Name == "Plate" or (s.Machine == "Sled" and (d.Name == "Sled" or d.Name == "Handles"))) then
				table.insert(s.Moving, { Part = d, Home = d.CFrame, Rel = bar.CFrame:ToObjectSpace(d.CFrame) })
			end
		end
	end
	local root = rootOf()
	s.RootHome = root and root.CFrame
	s.P = 0
	s.PGoal = 0
end

local LIFT_TIME = 0.5 -- one lift: down and back up (the sled: a push and back)

local function liftUpdate(s, dt)
	if not s.Joints then return end
	local k = s.RepT and math.clamp((os.clock() - s.RepT) / LIFT_TIME, 0, 1) or 1
	local wave = math.sin(k * math.pi)
	-- squat and bench start at the top (0); the sled starts back (1)
	s.P = s.Machine == "Sled" and 1 - wave or wave
	local pose = POSES[s.Machine] or POSES.Squat
	local offsets = pose(s.P, os.clock())
	for name, j in pairs(s.Joints) do
		if j.Motor.Parent then j.Motor.C0 = j.C0 * (offsets[name] or CFrame.identity) end
	end
	local character = player.Character
	local rh = character and character:FindFirstChild("RightHand")
	local lh = character and character:FindFirstChild("LeftHand")
	if s.BarHome and #s.Moving > 0 then
		local target
		if s.Machine == "Sled" then
			-- the sled slides forward as you drive, back as you reset
			local root = rootOf()
			local fwd = root and DrillMath.Flat(root.CFrame.LookVector) or Vector3.zero
			if fwd.Magnitude > 0 then fwd = fwd.Unit end
			target = s.BarHome + fwd * 1.8 * (1 - s.P)
			if root and s.RootHome then root.CFrame = s.RootHome + fwd * 1.8 * (1 - s.P) end
		elseif rh and lh then
			-- the bar sits in your hands
			local mid = (rh.Position + lh.Position) / 2
			local rot = s.BarHome - s.BarHome.Position
			target = CFrame.new(mid) * rot
		end
		if target then
			local delta = target
			for _, m in ipairs(s.Moving) do
				if m.Part.Parent then m.Part.CFrame = delta * m.Rel end
			end
		end
	end
end

local function liftStop(s)
	for _, j in pairs(s.Joints or {}) do
		if j.Motor.Parent then j.Motor.C0 = j.C0 end
	end
	for _, m in ipairs(s.Moving or {}) do
		if m.Part.Parent then m.Part.CFrame = m.Home end
	end
	s.Joints, s.Moving = nil, nil
end

-- One lift on screen: the body goes through a rep and a little "+1" pops.
local function liftBar(s)
	s.RepT = os.clock()
end

controllers.Gym = {
	Action = "LIFT",
	Start = function(s, data)
		s.Bar = data.Bar
		s.Machine = data.Machine
		s.PerXP = data.PerXP or 3
		s.Lifts, s.Next = 0, s.PerXP
		hud.Timing.Visible = false
		if data.Camera then setCamera(CFrame.lookAt(data.Camera.Position, data.Spot + Vector3.new(0, 3, 0)), 55) end
		-- the server has put you on the machine: start moving with it
		task.delay(0.2, function()
			if S == s then pcall(liftStart, s) end
		end)
	end,
	Update = function(s, dt)
		liftUpdate(s, dt or 1 / 60)
		local tip = touchOnly() and "Tap LIFT!" or "Click to lift!"
		hud.Info.Text = ("%s   LIFTS <font color=\"#FFD84A\">%d</font>   XP in <font color=\"#6BFF7A\">%d</font>"):format(tip, s.Lifts, s.Next)
	end,
	PressBegan = function(s)
		task.spawn(function()
			local ok, r = pcall(function() return ctx.Remotes.Train:InvokeServer("Lift") end)
			if not (ok and r) or S ~= s or r.Result ~= "lift" then return end
			s.Lifts, s.Next = r.Lifts, r.Next
			liftBar(s)
			ctx.Sound(r.XP > 0 and "Chime" or "Clank", 0.6, 0.9 + math.random() * 0.25)
		end)
	end,
	Event = function(s, kind, data)
		if kind == "lift" then
			-- resting: it lifted by itself
			s.Lifts, s.Next = data.Lifts, data.Next
			liftBar(s)
			ctx.Sound("Clank", 0.35)
		end
	end,
	Stop = function(s)
		liftStop(s)
		if s.Bar and s.BarHome then s.Bar.CFrame = s.BarHome end
	end,
}

--------------------------------------------------------------------------------
-- The stadium match
--------------------------------------------------------------------------------

local function clearMoment(s)
	for _, x in ipairs(s.MomentParts or {}) do x:Destroy() end
	s.MomentParts = {}
	if s.Ball then s.Ball:Destroy(); s.Ball = nil end
	for _, key in ipairs({ "Reticle", "ReticleDot", "AimLine", "AimRing", "Highlight", "ReachRing", "LitArrow" }) do
		if s[key] then s[key]:Destroy(); s[key] = nil end
	end
	if s.Attackers then
		for id in pairs(s.Attackers) do removeAttacker(s, id, false) end
	end
	s.Attackers = nil
	s.Keeper = nil
	s.Mode = nil
	s.Charging = false
	showPower(false)
end

local function setScore(us, them)
	hud.ScoreText.Text = ("YOU %d - %d THEM"):format(us, them)
end

controllers.Match = {
	Action = "PLAY",
	Start = function(s, data)
		hud.Score.Visible = true
		setScore(0, 0)
		s.MomentParts = {}
		shout("KICK OFF!", C.Gold, 76, 1.2)
		ctx.Sound("Whistle")
		ctx.Sound("Cheer", 0.6)
		hud.Info.Text = ("You vs a <font color=\"#FF6A6A\">%d OVR</font> team"):format(data.Opponent)
	end,
	Update = function(s)
		local now = ctx.Now()
		if s.Mode == "Attack" then
			updateAim(s)
			if s.Keeper then
				local k = s.Keeper
				local u = k.Amp * math.sin(k.Freq * (now - k.T0) + k.Phase)
				placeFigure(s.KeeperFigure, DrillMath.GoalPoint(s.Goal, u, 0) + s.Goal.LookVector * 1.5, s.Goal.LookVector)
			end
			if s.Charging then hud.PowerFill.Size = UDim2.fromScale(chargeValue(s.ChargeSince), 1) end
		elseif s.Mode == "Pass" then
			updatePassAim(s)
			if s.Charging then hud.PowerFill.Size = UDim2.fromScale(chargeValue(s.ChargeSince), 1) end
		elseif s.Mode == "Defend" then
			updateAttackers(s)
		end
	end,
	PressBegan = function(s)
		if s.Mode == "Attack" then
			shootPressBegan(s)
		elseif s.Mode == "Pass" then
			controllers.Passing.PressBegan(s)
		elseif s.Mode == "Defend" then
			tackle(s)
		end
	end,
	PressEnded = function(s)
		if s.Mode == "Attack" then
			shootPressEnded(s, function(ss, r)
				flyBall(ss, r.U, r.V, r.Time, r.Result ~= "miss")
			end)
			s.CanShoot = false
		elseif s.Mode == "Pass" then
			if not s.Charging then return end
			s.Charging = false
			local power = chargeValue(s.ChargeSince)
			showPower(false)
			ctx.Sound("Kick", 0.8, 1.15)
			local aim = s.Aim
			task.spawn(function()
				local ok, r = pcall(function() return ctx.Remotes.Train:InvokeServer("Pass", aim.X, aim.Z, power) end)
				if ok and r and r.Landing and S == s and s.Ball then rollBall(s, r.Landing, 0) end
			end)
		end
	end,
	Event = function(s, kind, data)
		if kind == "moment" then
			clearMoment(s)
			s.Mode = data.Type
			setScore(data.Us, data.Them)
			local titles = { Attack = "ATTACK! Beat the keeper", Pass = "PASS! Find the free teammate", Defend = "DEFEND! Stop their striker" }
			shout(titles[data.Type], C.White, 48, 1.2)
			hud.Info.Text = ("MOMENT %d / %d"):format(data.Index, data.Total)
			if data.Type == "Attack" then
				shootSetup(s, data.Spot, data.Goal, data.GoalWidth, data.GoalHeight, data.Green)
				s.CanShoot = true
				s.Keeper = data.Keeper
				s.KeeperFigure = makeFigure(localFolder(), "Keeper")
				table.insert(s.MomentParts, s.KeeperFigure)
				table.insert(s.MomentParts, s.Reticle)
			elseif data.Type == "Pass" then
				local forward = CFrame.lookAt(data.Spot, data.Teammates[1])
				passSetup(s, data.Spot, forward, data.MaxDistance)
				s.Targets = {}
				for i, pos in ipairs(data.Teammates) do
					local fig = makeFigure(localFolder(), "Teammate")
					placeFigure(fig, pos, data.Spot - pos)
					table.insert(s.MomentParts, fig)
					table.insert(s.Targets, { Id = i, Kind = "Dummy", Pos = pos, Model = fig })
				end
				s.Lit = { Id = data.Free }
				local t = s.Targets[data.Free]
				s.Highlight = highlight(t.Model, C.Gold)
				local anchor = arrow(localFolder(), "\u{2B07}", C.Gold)
				anchor.CFrame = CFrame.new(t.Pos + Vector3.new(0, 9, 0))
				s.LitArrow = anchor
			else
				resetCamera()
				addAttackers(s, data.Attackers)
			end
		elseif kind == "matchEvent" then
			setScore(data.Us, data.Them)
			local color = data.Good and C.Green or C.Red
			if data.Goal then
				shout("GOAL!!!", C.Gold, 96, 1.4)
				ctx.Sound("Cheer")
				ctx.Sound("Net")
			elseif data.Against then
				shout("THEY SCORE", C.Red, 70, 1.2)
				ctx.Sound("Groan")
			end
			ctx.Toast(data.Text, data.Good and "good" or "error")
			hud.Info.Text = data.Text
			local _ = color
		elseif kind == "matchEnd" then
			clearMoment(s)
			resetCamera()
			setScore(data.Us, data.Them)
			local text = data.Result == "win" and "YOU WIN!" or (data.Result == "draw" and "DRAW" or "YOU LOST")
			shout(("%s %d-%d"):format(text, data.Us, data.Them), data.Result == "win" and C.Gold or (data.Result == "draw" and C.White or C.Red), 84, 2.5)
			ctx.Sound("Whistle")
			if data.Result == "win" then ctx.Sound("Cheer") end
			hud.Info.Text = ("+%s XP to every stat!"):format(Config.Short(data.XP / 6))
		end
	end,
	Stop = function(s)
		clearMoment(s)
		hud.Score.Visible = false
	end,
}

--------------------------------------------------------------------------------
-- Session start / stop and input
--------------------------------------------------------------------------------

-- Leave the drill you are in (the EXIT button or X).
function TrainingClient.Leave()
	if not S or S.Leaving then return end
	local s = S
	s.Leaving = true
	ctx.Sound("Click")
	task.spawn(function() pcall(function() ctx.Remotes.Train:InvokeServer("Leave") end) end)
	-- if the server never answered, the button works again
	task.delay(2, function() s.Leaving = nil end)
end

local function stopSession()
	local s = S
	if not s then return end
	S = nil
	if s.Ctl and s.Ctl.Stop then pcall(s.Ctl.Stop, s) end
	local folder = workspace:FindFirstChild("LocalDrill")
	if folder then folder:ClearAllChildren() end
	resetCamera()
	hud.Root.Visible = false
	hud.Power.Visible = false
	hud.Timing.Visible = false
	hud.Score.Visible = false
end

local function startSession(data)
	stopSession()
	local ctl = controllers[data.Kind]
	if not ctl then return end
	S = { Kind = data.Kind, Stat = data.Stat, Ctl = ctl, Data = data }
	hud.Root.Visible = true
	hud.Info.Text = ""
	setXPBar(data.Stat)
	hud.Action.Visible = ctl.Action ~= nil
	hud.LeaveHint.Visible = not touchOnly()
	if ctl.Action then hud.ActionLabel.Text = ctl.Action end
	local title = Config.Drills[data.Kind] and Config.Drills[data.Kind].Title or data.Kind
	local area = Config.Areas[data.Area]
	shout(title, statColor(data.Stat), 58, 1.2)
	if area and area.Mult and area.Mult > 1 then
		ctx.Toast(("%s: x%.2g XP"):format(area.Title, area.Mult), "gold")
	end
	ctx.Sound("Whistle", 0.5)
	local ok, err = pcall(ctl.Start, S, data)
	if not ok then warn("[Training] start failed:", err) end
end

function TrainingClient.Init(c)
	ctx = c
	buildHud()
	ctx.InDrill = function() return S ~= nil end

	ctx.Remotes.TrainEvent.OnClientEvent:Connect(function(kind, data)
		data = data or {}
		if kind == "start" then
			startSession(data)
		elseif kind == "ended" then
			local summary = data.Summary or {}
			stopSession()
			if data.XP and data.XP > 0 then
				ctx.Toast(("Training done: +%s XP"):format(Config.Short(data.XP)), "good")
			elseif data.Reason == "left" then
				ctx.Toast("You left the drill area.", "info")
			elseif data.Reason == "lives" then
				ctx.Toast(("Game over! You reached wave %d."):format(summary.Waves or 0), "info")
			end
		elseif S and S.Ctl.Event then
			local ok, err = pcall(S.Ctl.Event, S, kind, data)
			if not ok then warn("[Training] event failed:", kind, err) end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if S and S.Ctl.Update then
			local ok, err = pcall(S.Ctl.Update, S, dt)
			if not ok and not S.Warned then
				S.Warned = true
				warn("[Training] update failed:", err)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not S then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			if gameProcessed then return end
			lastTouch = input.Position
			if S.Kind == "Defending" or (S.Kind == "Match" and S.Mode == "Defend") then return end
			return
		end
		if gameProcessed then return end
		lastTouch = nil
		local key = input.KeyCode
		if key == Enum.KeyCode.X then
			TrainingClient.Leave()
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.Space or key == Enum.KeyCode.F
			or key == Enum.KeyCode.ButtonR2 or key == Enum.KeyCode.ButtonA then
			if S.Kind == "Speed" or S.Kind == "Dribbling" then return end
			if key == Enum.KeyCode.Space and (S.Kind == "Defending" or (S.Kind == "Match" and S.Mode == "Defend")) then return end
			if S.Ctl.PressBegan then S.Ctl.PressBegan(S, false) end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = input.Position
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			lastTouch = nil
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not S then return end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.Space or key == Enum.KeyCode.F
			or key == Enum.KeyCode.ButtonR2 or key == Enum.KeyCode.ButtonA then
			if S.Ctl.PressEnded then S.Ctl.PressEnded(S, false) end
		end
	end)

	player.CharacterAdded:Connect(function()
		stopSession()
	end)
end

return TrainingClient
