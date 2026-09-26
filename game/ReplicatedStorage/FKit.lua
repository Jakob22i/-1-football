-- Small building blocks for the screen: frames, round corners, outlines,
-- gradients, chunky lettering and candy buttons. One look everywhere: bright
-- colours, thick navy outlines, white lettering, readable at a glance.

local TweenService = game:GetService("TweenService")

local FKit = {}

FKit.Font = Enum.Font.FredokaOne
FKit.Body = Enum.Font.GothamBold

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
		Thickness = math.clamp(size / 8, 1.5, 5),
		Color = C.Ink,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = l,
	})
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

-- A candy button: a glossy face on a darker lip. A TextButton with "Label".
function FKit.button(parent, text, palette, props)
	palette = palette or FKit.Palette.green
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = palette[3],
		Parent = parent,
	})
	for k, v in pairs(props or {}) do b[k] = v end
	FKit.corner(b, 14)
	FKit.stroke(b, 3.5, C.Ink, true).Name = "Border"
	local face = new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -6),
		BackgroundColor3 = C.White,
		ZIndex = b.ZIndex,
		Parent = b,
	})
	FKit.corner(face, 14)
	FKit.gradient(face, { palette[1], palette[2] }, 90)
	local shine = new("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 6, 0, 3),
		Size = UDim2.new(1, -12, 0.38, 0),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.6,
		ZIndex = b.ZIndex,
		Parent = face,
	})
	FKit.corner(shine, 8)
	local l = FKit.fit(b, text, 22, C.White, {
		Name = "Label",
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 1, -8),
		ZIndex = b.ZIndex + 1,
	})
	l.TextStroke.Thickness = 2.5
	FKit.press(b)
	return b, l
end

function FKit.recolor(button, palette)
	button.BackgroundColor3 = palette[3]
	local face = button:FindFirstChild("Face")
	local g = face and face:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(palette[1], palette[2]) end
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
