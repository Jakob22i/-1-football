-- The upgrade moment, the best feeling in the game. When OVR goes up:
--
--   1. the screen dims a little
--   2. your card flies from the corner to the middle
--   3. the old OVR rolls up to the new one (rising chime and a cheer)
--   4. confetti in the tier's colours (or your celebration: fireworks,
--      lightning, hearts)
--   5. a NEW TIER flips the card over to the new design with a bigger
--      burst and "GOLD UNLOCKED!"
--   6. the card flies back to the corner
--
-- 2 to 4 seconds. Ups that come in while it plays are joined into one.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))
local CardView = require(ReplicatedStorage:WaitForChild("CardView"))
local CardUI = require(script.Parent:WaitForChild("CardUI"))

local UpgradeFX = {}

local ctx
local player = Players.LocalPlayer
local new = FKit.new
local C = FKit.Color
local playing = false
local pending = nil

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function screen()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function celebration()
	local ok, cosmetics = pcall(function() return HttpService:JSONDecode(player:GetAttribute("Cosmetics") or "{}") end)
	local id = ok and cosmetics.Celebration or "Celebration_Confetti"
	return (Config.Cosmetics[id] and Config.Cosmetics[id].Name) or "Confetti"
end

--------------------------------------------------------------------------------
-- Particles (plain frames moved every frame)
--------------------------------------------------------------------------------

local particles = {}
local stepping

local function stepParticles(dt)
	for i = #particles, 1, -1 do
		local p = particles[i]
		p.Age += dt
		if p.Age >= p.Life or not p.Frame.Parent then
			p.Frame:Destroy()
			table.remove(particles, i)
		else
			p.Vel += Vector2.new(0, p.Gravity * dt)
			p.Pos += p.Vel * dt
			p.Frame.Position = UDim2.fromOffset(p.Pos.X, p.Pos.Y)
			p.Frame.Rotation += p.Spin * dt
			local fade = math.clamp((p.Age - p.Life * 0.6) / (p.Life * 0.4), 0, 1)
			if p.Frame:IsA("TextLabel") then p.Frame.TextTransparency = fade else p.Frame.BackgroundTransparency = fade end
		end
	end
	if #particles == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function particle(frame, pos, vel, life, gravity, spin)
	table.insert(particles, { Frame = frame, Pos = pos, Vel = vel, Life = life, Age = 0, Gravity = gravity or 700, Spin = spin or 0 })
	if not stepping then stepping = RunService.RenderStepped:Connect(stepParticles) end
end

-- A burst from a point on the screen (pixels) in the given colours.
local function burst(center, colors, count, style, speed)
	style = style or "Confetti"
	speed = speed or 1
	if style == "Fireworks" then
		for k = 1, 3 do
			local at = center + Vector2.new((k - 2) * 220 + math.random(-40, 40), -120 + math.random(-60, 40))
			task.delay((k - 1) * 0.18, function()
				for i = 1, math.floor(count / 2) do
					local a = i / (count / 2) * math.pi * 2
					local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = colors[(i + k) % #colors + 1],
						BorderSizePixel = 0, ZIndex = 60, Parent = ctx.Overlay })
					FKit.corner(f, UDim.new(0.5, 0))
					particle(f, at, Vector2.new(math.cos(a), math.sin(a)) * (260 + math.random(0, 120)) * speed, 1.1, 260)
				end
			end)
		end
		return
	end
	if style == "Hearts" then
		for i = 1, math.floor(count * 0.6) do
			local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1,
				Text = "\u{2764}", TextScaled = true, TextColor3 = colors[i % #colors + 1], Font = Enum.Font.GothamBold, ZIndex = 60, Parent = ctx.Overlay })
			particle(l, center + Vector2.new(math.random(-160, 160), math.random(-40, 60)), Vector2.new(math.random(-80, 80), -math.random(200, 420)) * speed,
				1.6, 120, math.random(-60, 60))
		end
		return
	end
	if style == "Lightning" then
		local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 240, 255), BackgroundTransparency = 0.3, ZIndex = 55, Parent = ctx.Overlay })
		tween(flash, 0.35, { BackgroundTransparency = 1 })
		task.delay(0.4, function() flash:Destroy() end)
		for b = 1, 4 do
			local x = center.X + (b - 2.5) * 140
			for k = 0, 5 do
				local seg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 46), Rotation = (k % 2 == 0) and 25 or -25,
					BackgroundColor3 = Color3.fromRGB(200, 240, 255), BorderSizePixel = 0, ZIndex = 58, Parent = ctx.Overlay })
				particle(seg, Vector2.new(x + ((k % 2 == 0) and 8 or -8), center.Y - 260 + k * 40), Vector2.zero, 0.45, 0)
			end
		end
		-- and ordinary confetti too
	end
	for i = 1, count do
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			BackgroundColor3 = colors[i % #colors + 1],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 60,
			Parent = ctx.Overlay,
		})
		local a = math.random() * math.pi * 2
		local v = Vector2.new(math.cos(a), math.sin(a) - 0.6) * (320 + math.random() * 420) * speed
		particle(f, center, v, 1.4 + math.random() * 0.6, 900, math.random(-400, 400))
	end
end
UpgradeFX.Burst = function(...) burst(...) end

-- Light rays turning behind something.
local function rays(center, color, size)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = ctx.Overlay,
	})
	for i = 1, 10 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, size * 0.09, 1, 0),
			Rotation = i * 18,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 41,
			Parent = holder,
		})
		FKit.gradient(ray, color, 90, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
		}))
	end
	tween(holder, 3.5, { Rotation = 60 }, Enum.EasingStyle.Linear)
	return holder
end

--------------------------------------------------------------------------------
-- The sequence
--------------------------------------------------------------------------------

local function tierColors(tier)
	local style = CardView.Styles[tier] or CardView.Styles.Bronze
	local colors = { style.Body[1], style.Body[2], C.White }
	if style.Glow then table.insert(colors, style.Glow) end
	if tier == "Legend" or tier == "WorldClass" then
		for _, c in ipairs(style.Border) do table.insert(colors, c) end
	end
	return colors
end

local function play(data)
	playing = true
	CardUI.Freeze(true)
	local view = screen()
	local inset = GuiService:GetGuiInset()
	local small = CardUI.Holder()
	local fromPos = small.AbsolutePosition + small.AbsoluteSize / 2 + inset
	local fromSize = small.AbsoluteSize
	local scale = math.clamp(view.Y * 0.55 / 420, 0.55, 1.15)
	local bigSize = Vector2.new(300, 420) * scale
	local center = Vector2.new(view.X / 2, view.Y * 0.46)

	-- 1. dim
	local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = ctx.Overlay })
	tween(dim, 0.2, { BackgroundTransparency = 0.5 })

	-- 2. the card flies to the middle
	local base = CardUI.Data()
	base.OVR = data.Old
	base.Tier = data.OldTier
	local big = CardView.new(ctx.Overlay, {
		Size = UDim2.fromOffset(fromSize.X, fromSize.Y), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fromPos.X, fromPos.Y), Viewport = true, ZIndex = 45,
	})
	big:Set(base)
	CardUI.ShowAvatar(big)
	CardUI.Track(big)
	ctx.Sound("Whoosh")
	tween(big.Frame, 0.45, { Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(bigSize.X, bigSize.Y) }, Enum.EasingStyle.Back)
	task.wait(0.45)

	-- 3. the number rolls up
	local glow = rays(center, (CardView.Styles[data.OldTier] or CardView.Styles.Bronze).Body[2], bigSize.Y * 1.8)
	ctx.Sound("Chime")
	ctx.Sound("Cheer", 0.8)
	local rollTime = math.clamp(0.25 + (data.New - data.Old) * 0.18, 0.45, 0.9)
	local started = os.clock()
	local shown = data.Old
	while true do
		local k = math.clamp((os.clock() - started) / rollTime, 0, 1)
		local eased = 1 - (1 - k) ^ 3
		local value = math.floor(data.Old + (data.New - data.Old) * eased + 0.001)
		if value ~= shown then
			shown = value
			big.OVR.Text = tostring(value)
			FKit.pop(big.OVR, 1.6, 0.25)
			ctx.Sound("Tick", 1, 1 + (value - 60) / 60)
		end
		if k >= 1 then break end
		RunService.RenderStepped:Wait()
	end
	big.OVR.Text = tostring(data.New)

	-- 4. confetti in the tier colours
	local style = celebration()
	burst(center, tierColors(data.NewTier), 60, style)

	-- 5. a new tier: the card flips over
	local newTier = Config.TierIndex(data.NewTier) > Config.TierIndex(data.OldTier)
	if newTier then
		task.wait(0.15)
		local aspect = big.Frame:FindFirstChildOfClass("UIAspectRatioConstraint")
		if aspect then aspect.Parent = nil end
		ctx.Sound("Whoosh", 1, 1.3)
		tween(big.Frame, 0.18, { Size = UDim2.fromOffset(0, bigSize.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.18)
		base.OVR = data.New
		base.Tier = data.NewTier
		big:Set(base)
		tween(big.Frame, 0.26, { Size = UDim2.fromOffset(bigSize.X, bigSize.Y) }, Enum.EasingStyle.Back)
		task.wait(0.26)
		if aspect then aspect.Parent = big.Frame end
		ctx.Sound(data.NewTier == "Legend" and "Legend" or "Tier")
		glow:Destroy()
		glow = rays(center, (CardView.Styles[data.NewTier] or CardView.Styles.Bronze).Body[2], bigSize.Y * 2.4)
		burst(center, tierColors(data.NewTier), 110, style, 1.35)
		local text = data.NewTier == "Legend" and "99 LEGEND!" or (Config.Tiers[data.NewTier].Label .. " UNLOCKED!")
		local banner = FKit.text(ctx.Overlay, text, 64, C.White, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(center.X, center.Y - bigSize.Y / 2 - 12),
			Size = UDim2.fromOffset(900, 76),
			ZIndex = 62,
		})
		banner.TextStroke.Thickness = 6
		FKit.gradient(banner, tierColors(data.NewTier), 90)
		FKit.pop(banner, 0.3, 0.4)
		task.delay(1.6, function()
			tween(banner, 0.3, { TextTransparency = 1 })
			tween(banner.TextStroke, 0.3, { Transparency = 1 })
			task.delay(0.35, function() banner:Destroy() end)
		end)
		task.wait(0.9)
	else
		base.OVR = data.New
		base.Tier = data.NewTier
		big:Set(base)
		task.wait(0.55)
	end

	-- 6. back to the corner
	tween(big.Frame, 0.4, { Position = UDim2.fromOffset(fromPos.X, fromPos.Y), Size = UDim2.fromOffset(fromSize.X, fromSize.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(dim, 0.4, { BackgroundTransparency = 1 })
	for _, d in ipairs(glow:GetDescendants()) do
		if d:IsA("Frame") then tween(d, 0.3, { BackgroundTransparency = 1 }) end
	end
	task.wait(0.4)
	big.Frame:Destroy()
	CardUI.Untrack(big)
	dim:Destroy()
	glow:Destroy()
	CardUI.Freeze(false)
	FKit.pop(small, 1.25, 0.35)
	playing = false
	if pending then
		local nextOne = pending
		pending = nil
		play(nextOne)
	end
end

function UpgradeFX.Queue(data)
	if playing then
		if pending then
			pending.New = data.New
			pending.NewTier = data.NewTier
		else
			pending = { Old = data.Old, New = data.New, OldTier = data.OldTier, NewTier = data.NewTier }
		end
		return
	end
	task.spawn(play, data)
end

-- A big line of text in the middle of the screen (seasons, LEGEND).
local function headline(title, line, colors, sound)
	local view = screen()
	local center = Vector2.new(view.X / 2, view.Y * 0.38)
	local g = rays(center, colors[1], 700)
	local t = FKit.text(ctx.Overlay, title, 86, C.White, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(1000, 96), ZIndex = 62,
	})
	t.TextStroke.Thickness = 7
	FKit.gradient(t, colors, 90)
	local l = FKit.text(ctx.Overlay, line, 30, C.White, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(center.X, center.Y + 54), Size = UDim2.fromOffset(1000, 36), ZIndex = 62,
	})
	FKit.pop(t, 0.3, 0.45)
	burst(center, colors, 120, celebration(), 1.4)
	ctx.Sound(sound or "Tier")
	ctx.Sound("Cheer")
	task.delay(3.2, function()
		for _, x in ipairs({ t, l }) do
			tween(x, 0.4, { TextTransparency = 1 })
			tween(x.TextStroke, 0.4, { Transparency = 1 })
		end
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("Frame") then tween(d, 0.4, { BackgroundTransparency = 1 }) end
		end
		task.delay(0.45, function()
			t:Destroy()
			l:Destroy()
			g:Destroy()
		end)
	end)
end

function UpgradeFX.Season(data)
	local color = Config.SeasonColor(data.Season) or C.Gold
	headline(("SEASON %d!"):format(data.Season), ("+%d%% XP forever. Your card starts again at 60."):format(math.floor(data.Bonus * 100 + 0.5)),
		{ C.White, color, color:Lerp(C.Ink, 0.3) }, "Legend")
	CardUI.Refresh()
end

function UpgradeFX.Legend()
	task.delay(3.2, function()
		headline("LEGEND", "You reached 99. Start a New Season from the menu!", CardView.Styles.Legend.Border, "Legend")
	end)
end

function UpgradeFX.Init(c)
	ctx = c
end

return UpgradeFX
