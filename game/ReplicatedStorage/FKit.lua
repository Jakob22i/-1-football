-- Small building blocks for the screen: frames, round corners, outlines,
-- gradients, chunky lettering and candy buttons. One look everywhere: bright
-- colours, thick navy outlines, white lettering, readable at a glance.

local TweenService = game:GetService("TweenService")

local FKit = {}

-- the Pet Simulator look: bold black outlines and a light gradient on text
local petSim = require(script.Parent:WaitForChild("FootballConfig")).Look == "PetSim"
FKit.PetSim = petSim

FKit.Font = Enum.Font.FredokaOne
FKit.Body = Enum.Font.FredokaOne

FKit.Color = {
	White = Color3.new(1, 1, 1),
	Ink = Color3.fromRGB(12, 18, 48),        -- every outline
	Navy = Color3.fromRGB(20, 34, 84),
	NavyLight = Color3.fromRGB(44, 70, 150),
	NavyDark = Color3.fromRGB(10, 16, 44),
	Green = Color3.fromRGB(70, 220, 90),
	GreenDark = Color3.fromRGB(16, 130, 50),
	Gold = Color3.fromRGB(255, 204, 40),
	GoldDark = Color3.fromRGB(200, 120, 0),
	Red = Color3.fromRGB(255, 70, 90),
	Blue = Color3.fromRGB(40, 160, 255),
	Orange = Color3.fromRGB(255, 150, 30),
	Purple = Color3.fromRGB(170, 90, 255),
	Pink = Color3.fromRGB(255, 90, 200),
	Grey = Color3.fromRGB(150, 160, 190),
	Track = Color3.fromRGB(14, 22, 60),
}
local C = FKit.Color

-- Button colours: { top, bottom, lip }.
FKit.Palette = {
	green = { Color3.fromRGB(170, 255, 120), Color3.fromRGB(60, 210, 80), Color3.fromRGB(14, 120, 44) },
	gold = { Color3.fromRGB(255, 244, 130), Color3.fromRGB(255, 196, 30), Color3.fromRGB(190, 100, 0) },
	blue = { Color3.fromRGB(150, 230, 255), Color3.fromRGB(40, 160, 255), Color3.fromRGB(16, 70, 170) },
	red = { Color3.fromRGB(255, 160, 150), Color3.fromRGB(255, 70, 90), Color3.fromRGB(150, 16, 40) },
	purple = { Color3.fromRGB(220, 170, 255), Color3.fromRGB(160, 80, 255), Color3.fromRGB(80, 20, 170) },
	orange = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(255, 140, 30), Color3.fromRGB(170, 70, 10) },
	navy = { Color3.fromRGB(90, 120, 220), Color3.fromRGB(44, 70, 150), Color3.fromRGB(14, 24, 70) },
	grey = { Color3.fromRGB(210, 215, 235), Color3.fromRGB(140, 150, 180), Color3.fromRGB(70, 76, 110) },
}

function FKit.new(class, props)
	local o = Instance.new(class)
	local parent = props and props.Parent
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	if parent then o.Parent = parent end
	return o
end
local new = FKit.new

function FKit.corner(parent, r)
	return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12), Parent = parent })
end

function FKit.stroke(parent, thickness, color, border, transparency)
	local s = new("UIStroke", {
		Thickness = thickness,
		Color = color or C.Ink,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	return s
end

-- colors: one Color3, two, or a list of stops.
function FKit.sequence(colors)
	if typeof(colors) == "Color3" then return ColorSequence.new(colors) end
	if #colors == 2 then return ColorSequence.new(colors[1], colors[2]) end
	local points = {}
	for i, c in ipairs(colors) do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

function FKit.gradient(parent, colors, rotation, transparency)
	local g = new("UIGradient", { Color = FKit.sequence(colors), Rotation = rotation or 90, Parent = parent })
	if transparency then g.Transparency = transparency end
	return g
end

-- Chunky lettering with a thick outline.
function FKit.text(parent, text, size, color, props)
	local l = new("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Font = FKit.Font,
		Text = text,
		TextSize = size,
		TextColor3 = color or C.White,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	new("UIStroke", {
		Name = "TextStroke",
		-- thick on big words, thin on small ones (fat outlines make small text blobby)
		Thickness = petSim and (size >= 26 and math.clamp(size / 7, 3, 6) or math.clamp(size / 11, 1, 2.5)) or math.clamp(size / 8, 1.5, 5),
		Color = petSim and Color3.fromRGB(8, 8, 16) or C.Ink,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = l,
	})
	if petSim and (color == nil or color == C.White) then
		-- white on top, a hint of cool blue at the bottom
		new("UIGradient", { Name = "TextShade", Rotation = 90, Color = ColorSequence.new(C.White, Color3.fromRGB(214, 228, 255)), Parent = l })
	end
	return l
end

-- Same, but sized by its box (TextScaled) with a limit.
function FKit.fit(parent, text, maxSize, color, props)
	local l = FKit.text(parent, text, maxSize, color, props)
	l.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = l })
	return l
end

local function scaleOf(obj)
	return obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = obj })
end
FKit.scaleOf = scaleOf

function FKit.pop(obj, from, time)
	local s = scaleOf(obj)
	s.Scale = from or 0.6
	TweenService:Create(s, TweenInfo.new(time or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Grow on hover, sink on press.
function FKit.press(button)
	local s = scaleOf(button)
	button.MouseEnter:Connect(function() TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1.05 }):Play() end)
	button.MouseLeave:Connect(function() TweenService:Create(s, TweenInfo.new(0.1), { Scale = 1 }):Play() end)
	button.MouseButton1Down:Connect(function() TweenService:Create(s, TweenInfo.new(0.05), { Scale = 0.93 }):Play() end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- Studs over a frame, like the "stud style" buttons: a raised square every
-- `cell` pixels, lit from the top left, as many as fit (they follow the
-- frame's size). Sits under the text; clipped to the frame.
function FKit.studs(parent, cell, strength, zindex)
	cell = cell or 16
	strength = strength or 1
	local holder = new("Frame", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = zindex or parent.ZIndex,
		Parent = parent,
	})
	-- one plain square per stud (no corners, no shadow frame): cheap to draw
	local made = 0
	local function fill()
		local size = holder.AbsoluteSize
		local cols = math.clamp(math.ceil(size.X / cell), 0, 20)
		local rows = math.clamp(math.ceil(size.Y / cell), 0, 12)
		if cols * rows == made then return end
		holder:ClearAllChildren()
		made = cols * rows
		local stud = math.floor(cell * 0.56)
		local off = math.floor((cell - stud) / 2)
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				new("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 - 0.2 * strength, BorderSizePixel = 0,
					Position = UDim2.fromOffset(c * cell + off, r * cell + off), Size = UDim2.fromOffset(stud, stud),
					ZIndex = holder.ZIndex, Parent = holder,
				})
			end
		end
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fill)
	task.defer(fill)
	return holder
end

-- A stud-style button: a gradient from a bright colour at the bottom to a
-- lighter one on top, studs, a thin light inner edge, a dark outer edge,
-- round corners and chunky white lettering. A TextButton with "Label".
function FKit.button(parent, text, palette, props)
	palette = palette or FKit.Palette.green
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.White,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do b[k] = v end
	FKit.corner(b, UDim.new(0.22, 0))
	FKit.gradient(b, { palette[1], palette[2] }, 90).Name = "Fill"
	FKit.stroke(b, 3.5, C.Ink, true).Name = "Border"
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = b.ZIndex,
		Parent = b,
	})
	FKit.corner(face, UDim.new(0.22, 0))
	if petSim then
		-- Pet Simulator buttons: a glossy top instead of studs
		local gloss = new("Frame", {
			Name = "Gloss", BackgroundColor3 = C.White, BackgroundTransparency = 0.55, BorderSizePixel = 0,
			Position = UDim2.new(0, 5, 0, 4), Size = UDim2.new(1, -10, 0.42, 0), ZIndex = b.ZIndex, Parent = face,
		})
		FKit.corner(gloss, UDim.new(0.3, 0))
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.1, 0.85), Parent = gloss })
	else
		FKit.studs(face, 16, 1, b.ZIndex)
	end
	-- the light inner edge
	local rim = new("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = b.ZIndex,
		Parent = b,
	})
	FKit.corner(rim, UDim.new(0.22, 0))
	FKit.stroke(rim, 2.5, palette[1]:Lerp(C.White, 0.35), true).Name = "Inner"
	local l = FKit.fit(b, text, 22, C.White, {
		Name = "Label",
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 1, -4),
		ZIndex = b.ZIndex + 1,
	})
	l.TextStroke.Thickness = 2.5
	FKit.press(b)
	return b, l
end

function FKit.recolor(button, palette)
	local g = button:FindFirstChild("Fill")
	if g then g.Color = ColorSequence.new(palette[1], palette[2]) end
	local rim = button:FindFirstChild("Rim")
	local inner = rim and rim:FindFirstChild("Inner")
	if inner then inner.Color = palette[1]:Lerp(C.White, 0.35) end
end

--------------------------------------------------------------------------------
-- Motion that costs next to nothing (TweenService runs it, no per-frame code)
--------------------------------------------------------------------------------

local BLOCK_COLORS = {
	Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 200, 50), Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(70, 170, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 150, 60),
}

-- Is a gui object really on screen (every parent visible)?
local function shown(obj)
	local node = obj
	while node do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") then return node.Enabled end
		node = node.Parent
	end
	return false
end
FKit.shown = shown

-- Little studded blocks that tumble down behind a frame's content while it
-- is on screen. A handful at a time, each one tween.
function FKit.fallingBlocks(frame, opts)
	opts = opts or {}
	local layer = new("Frame", {
		Name = "FallingBlocks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true, ZIndex = opts.ZIndex or frame.ZIndex, Parent = frame,
	})
	if opts.Corner then FKit.corner(layer, opts.Corner) end
	local every = opts.Every or 0.9
	task.spawn(function()
		while layer.Parent do
			if shown(layer) and #layer:GetChildren() < (opts.Max or 6) then
				local size = math.random(12, 24)
				local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
				local block = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, 0, -size),
					Size = UDim2.fromOffset(size, size), Rotation = math.random(-30, 30),
					BackgroundColor3 = color, BackgroundTransparency = opts.Transparency or 0.45, BorderSizePixel = 0,
					ZIndex = layer.ZIndex, Parent = layer,
				})
				FKit.corner(block, UDim.new(0.2, 0))
				new("Frame", { -- the stud on top
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.45, 0.45),
					BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0,
					ZIndex = layer.ZIndex, Parent = block,
				})
				local time = 2.6 + math.random() * 2.2
				local t = TweenService:Create(block, TweenInfo.new(time, Enum.EasingStyle.Linear), {
					Position = UDim2.new(block.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, 1, size),
					Rotation = block.Rotation + math.random(-160, 160),
				})
				t.Completed:Connect(function() block:Destroy() end)
				t:Play()
			end
			task.wait(every)
		end
	end)
	return layer
end

-- A light that sweeps across a button now and then.
function FKit.shine(button, period)
	local sweep = new("Frame", {
		Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = button.ZIndex + 1, Parent = button,
	})
	FKit.corner(sweep, UDim.new(0.22, 0))
	local g = new("UIGradient", {
		Rotation = 20, Offset = Vector2.new(-1.2, 0), Parent = sweep,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	TweenService:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, period or 2.2),
		{ Offset = Vector2.new(1.2, 0) }):Play()
	return sweep
end

-- A slow breathing scale, for things that want to be clicked.
function FKit.pulse(obj, amount, period)
	local s = new("UIScale", { Name = "Pulse", Parent = obj })
	TweenService:Create(s, TweenInfo.new(period or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or 0.05) }):Play()
	return s
end

-- A gentle wobble (tags like HOT and BEST).
function FKit.wobble(obj, degrees, period)
	obj.Rotation = -(degrees or 6)
	TweenService:Create(obj, TweenInfo.new(period or 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = degrees or 6 }):Play()
end

-- A navy panel with a lighter rim.
function FKit.panel(parent, props, radius)
	local f = new("Frame", { Name = "Panel", BackgroundColor3 = C.White, Parent = parent })
	for k, v in pairs(props or {}) do f[k] = v end
	FKit.corner(f, radius or 18)
	FKit.gradient(f, { C.NavyLight, C.Navy, C.NavyDark }, 90)
	FKit.stroke(f, 4, C.Ink, true)
	local rim = new("Frame", {
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1,
		Parent = f,
	})
	FKit.corner(rim, math.max(2, (radius or 18) - 3))
	FKit.stroke(rim, 2, C.White, true, 0.8)
	if not petSim then FKit.studs(f, 28, 0.4, f.ZIndex) end
	return f
end

-- A small rounded tag: "NEW!", "LOCKED 70", "x2".
function FKit.tag(parent, text, colors, props)
	local t = new("Frame", {
		Name = "Tag",
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.White,
		ZIndex = 8,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do t[k] = v end
	FKit.corner(t, 10)
	FKit.gradient(t, colors or { C.Gold, C.GoldDark }, 90)
	FKit.stroke(t, 3, C.Ink, true)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = t })
	local l = FKit.text(t, text, 16, C.White, {
		Name = "Label",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		RichText = true,
		ZIndex = t.ZIndex + 1,
	})
	return t, l
end

-- A progress bar: dark track, coloured fill, text on top.
function FKit.bar(parent, props, colors)
	local track = new("Frame", { Name = "Bar", BackgroundColor3 = C.Track, Parent = parent })
	for k, v in pairs(props or {}) do track[k] = v end
	FKit.corner(track, UDim.new(0.5, 0))
	FKit.stroke(track, 3.5, C.Ink, true)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.White, ZIndex = track.ZIndex, Parent = track })
	FKit.corner(fill, UDim.new(0.5, 0))
	local grad = FKit.gradient(fill, colors or { C.Green, C.GreenDark }, 90)
	local shine = new("Frame", {
		Name = "Shine",
		Position = UDim2.new(0, 5, 0, 3),
		Size = UDim2.new(1, -10, 0.32, 0),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.55,
		ZIndex = track.ZIndex,
		Parent = fill,
	})
	FKit.corner(shine, UDim.new(0.5, 0))
	local label = FKit.fit(track, "", 18, C.White, { Size = UDim2.new(1, -12, 1, -2), Position = UDim2.fromOffset(6, 1), ZIndex = track.ZIndex + 2 })
	local api = { Frame = track, Fill = fill, Gradient = grad, Label = label, Ratio = 0 }
	function api.Set(ratio, text, instant)
		ratio = math.clamp(ratio or 0, 0, 1)
		api.Ratio = ratio
		fill.Visible = ratio > 0.002
		local size = UDim2.fromScale(math.max(ratio, 0.04), 1)
		if instant then fill.Size = size else TweenService:Create(fill, TweenInfo.new(0.25), { Size = size }):Play() end
		if text then label.Text = text end
	end
	return api
end

-- Smaller on small screens (phones). `w` x `h` is the screen size a piece
-- needs to show at full size; on a smaller screen it shrinks (to half at
-- most) and follows the screen when it turns or resizes.
local fits = {}
local watching = false

local function viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function refit()
	local size = viewport()
	for s, info in pairs(fits) do
		if s.Parent then
			local k = math.clamp(math.min(size.X / info.W, size.Y / info.H), 0.5, 1)
			s.Scale = k
			if info.Screen then s.Parent.Size = UDim2.fromScale(1 / k, 1 / k) end
		else
			fits[s] = nil
		end
	end
end

local function watch()
	if watching then return end
	watching = true
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit) end
end

-- One piece (keeps its anchor point where it is).
function FKit.autoScale(obj, w, h)
	local s = new("UIScale", { Name = "Fit", Parent = obj })
	fits[s] = { W = w, H = h }
	watch()
	refit()
	return s
end

-- A full-screen frame whose children are laid out for a bigger screen and
-- then shrunk to fit, so a whole HUD scales together.
function FKit.screenScale(frame, w, h)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	local s = new("UIScale", { Name = "Fit", Parent = frame })
	fits[s] = { W = w, H = h, Screen = true }
	watch()
	refit()
	return s
end

-- Text that pops up and floats away ("+12 XP").
function FKit.float(parent, text, color, position, size)
	local l = FKit.text(parent, text, size or 28, color or C.Gold, {
		Name = "Float",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 40),
		ZIndex = 50,
	})
	local s = scaleOf(l)
	s.Scale = 0.4
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(l, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = l.Position - UDim2.fromOffset(0, 50) }):Play()
	task.delay(0.7, function()
		if not l.Parent then return end
		TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		TweenService:Create(l.TextStroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	end)
	task.delay(1.1, function() l:Destroy() end)
	return l
end

return FKit
