--!nocheck
-- A small stand-in for the Roblox engine: enough of Instance, CFrame, Vector3,
-- Color3 and the services to run the game's builder code outside Roblox and
-- dump the parts it makes.

local sqrt, sin, cos, abs = math.sqrt, math.sin, math.cos, math.abs

--------------------------------------------------------------------------------
-- Vector3
--------------------------------------------------------------------------------
local V3 = {}
local V3mt = {}
local function v3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3mt) end
V3mt.__index = function(v, k)
	if k == "X" then return v.x elseif k == "Y" then return v.y elseif k == "Z" then return v.z end
	if k == "Magnitude" then return sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
	if k == "Unit" then
		local m = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(v.x / m, v.y / m, v.z / m)
	end
	return V3[k]
end
V3mt.__add = function(a, b) return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
V3mt.__sub = function(a, b) return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.x, a * b.y, a * b.z) end
	if type(b) == "number" then return v3(a.x * b, a.y * b, a.z * b) end
	return v3(a.x * b.x, a.y * b.y, a.z * b.z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.x / b, a.y / b, a.z / b) end
	return v3(a.x / b.x, a.y / b.y, a.z / b.z)
end
V3mt.__unm = function(a) return v3(-a.x, -a.y, -a.z) end
V3mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
V3mt.__tostring = function(v) return string.format("%g, %g, %g", v.x, v.y, v.z) end
function V3.Dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function V3.Cross(a, b) return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
function V3.Lerp(a, b, t) return v3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t) end
function V3.Abs(a) return v3(abs(a.x), abs(a.y), abs(a.z)) end
function V3.Max(a, b) return v3(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z)) end
function V3.Min(a, b) return v3(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)) end
function V3.FuzzyEq(a, b, e) e = e or 1e-5; return abs(a.x - b.x) < e and abs(a.y - b.y) < e and abs(a.z - b.z) < e end
Vector3 = {
	new = v3,
	zero = v3(0, 0, 0), one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1),
}
local function isV3(v) return type(v) == "table" and getmetatable(v) == V3mt end

local V2mt = {}
Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0, x = x or 0, y = y or 0 }, V2mt) end }
local function v2num(a) if type(a) == "number" then return Vector2.new(a, a) end return a end
V2mt.__add = function(a, b) a, b = v2num(a), v2num(b); return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) a, b = v2num(a), v2num(b); return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2mt.__mul = function(a, b) a, b = v2num(a), v2num(b); return Vector2.new(a.X * b.X, a.Y * b.Y) end
V2mt.__div = function(a, b) a, b = v2num(a), v2num(b); return Vector2.new(a.X / b.X, a.Y / b.Y) end
V2mt.__unm = function(a) return Vector2.new(-a.X, -a.Y) end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
V2mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y); return m > 0 and Vector2.new(v.X / m, v.Y / m) or Vector2.new() end
	if k == "Lerp" then return function(a, b, t) return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y end end
	return nil
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)

--------------------------------------------------------------------------------
-- CFrame: position + rotation matrix (rows)
--------------------------------------------------------------------------------
local CF = {}
local CFmt = {}
local function cf(px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ px, py, pz, r00 or 1, r01 or 0, r02 or 0, r10 or 0, r11 or 1, r12 or 0, r20 or 0, r21 or 0, r22 or 1 }, CFmt)
end
local function mulRot(a, b)
	-- a, b are rotation arrays at index 4..12 (rows)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do s = s + a[4 + i * 3 + k] * b[4 + k * 3 + j] end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function rotPoint(c, x, y, z)
	return c[4] * x + c[5] * y + c[6] * z, c[7] * x + c[8] * y + c[9] * z, c[10] * x + c[11] * y + c[12] * z
end
CFmt.__index = function(c, k)
	if k == "Position" or k == "p" then return v3(c[1], c[2], c[3]) end
	if k == "X" then return c[1] elseif k == "Y" then return c[2] elseif k == "Z" then return c[3] end
	if k == "LookVector" then return v3(-c[6], -c[9], -c[12]) end
	if k == "RightVector" then return v3(c[4], c[7], c[10]) end
	if k == "UpVector" then return v3(c[5], c[8], c[11]) end
	if k == "XVector" then return v3(c[4], c[7], c[10]) end
	if k == "YVector" then return v3(c[5], c[8], c[11]) end
	if k == "ZVector" then return v3(c[6], c[9], c[12]) end
	if k == "Rotation" then return cf(0, 0, 0, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]) end
	return CF[k]
end
CFmt.__mul = function(a, b)
	if isV3(b) then
		local x, y, z = rotPoint(a, b.x, b.y, b.z)
		return v3(x + a[1], y + a[2], z + a[3])
	end
	local r = mulRot(a, b)
	local x, y, z = rotPoint(a, b[1], b[2], b[3])
	return cf(x + a[1], y + a[2], z + a[3], table.unpack(r))
end
CFmt.__add = function(a, v) return cf(a[1] + v.x, a[2] + v.y, a[3] + v.z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]) end
CFmt.__sub = function(a, v) return cf(a[1] - v.x, a[2] - v.y, a[3] - v.z, a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12]) end
CFmt.__tostring = function(c) return string.format("CF(%g,%g,%g)", c[1], c[2], c[3]) end
function CF.Inverse(c)
	-- transpose rotation, -R^T p
	local r00, r01, r02 = c[4], c[7], c[10]
	local r10, r11, r12 = c[5], c[8], c[11]
	local r20, r21, r22 = c[6], c[9], c[12]
	local x = -(r00 * c[1] + r01 * c[2] + r02 * c[3])
	local y = -(r10 * c[1] + r11 * c[2] + r12 * c[3])
	local z = -(r20 * c[1] + r21 * c[2] + r22 * c[3])
	return cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
function CF.ToWorldSpace(a, b) return a * b end
function CF.ToObjectSpace(a, b) return CF.Inverse(a) * b end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.PointToObjectSpace(a, v) return CF.Inverse(a) * v end
function CF.VectorToWorldSpace(a, v) local x, y, z = rotPoint(a, v.x, v.y, v.z); return v3(x, y, z) end
function CF.VectorToObjectSpace(a, v) local i = CF.Inverse(a); local x, y, z = rotPoint(i, v.x, v.y, v.z); return v3(x, y, z) end
function CF.GetComponents(c) return table.unpack(c) end
CF.components = CF.GetComponents
function CF.Lerp(a, b, t)
	local src = t < 0.5 and a or b
	return cf(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t,
		src[4], src[5], src[6], src[7], src[8], src[9], src[10], src[11], src[12])
end
function CF.ToEulerAnglesXYZ(c)
	local ry = math.asin(math.clamp(c[6], -1, 1))
	local rx = math.atan2(-c[9], c[12])
	local rz = math.atan2(-c[5], c[4])
	return rx, ry, rz
end
function CF.ToOrientation(c) return CF.ToEulerAnglesXYZ(c) end
local function rx(a) local c, s = cos(a), sin(a); return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c) end
local function ry(a) local c, s = cos(a), sin(a); return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c) end
local function rz(a) local c, s = cos(a), sin(a); return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1) end
local function lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	if look.Magnitude == 0 then return cf(at.x, at.y, at.z) end
	local right = V3.Cross(look, up)
	if right.Magnitude < 1e-6 then right = V3.Cross(look, v3(0, 0, 1)) end
	right = right.Unit
	local up2 = V3.Cross(right, look)
	return cf(at.x, at.y, at.z, right.x, up2.x, -look.x, right.y, up2.y, -look.y, right.z, up2.z, -look.z)
end
CFrame = {
	new = function(a, b, c, ...)
		if a == nil then return cf(0, 0, 0) end
		if isV3(a) then
			if isV3(b) then return lookAt(a, b) end
			return cf(a.x, a.y, a.z)
		end
		if select("#", ...) >= 9 then return cf(a, b, c, ...) end
		return cf(a, b, c)
	end,
	Angles = function(x, y, z) return rx(x or 0) * ry(y or 0) * rz(z or 0) end,
	fromEulerAnglesXYZ = function(x, y, z) return rx(x or 0) * ry(y or 0) * rz(z or 0) end,
	fromEulerAnglesYXZ = function(x, y, z) return ry(y or 0) * rx(x or 0) * rz(z or 0) end,
	fromOrientation = function(x, y, z) return ry(y or 0) * rx(x or 0) * rz(z or 0) end,
	lookAt = lookAt,
	fromAxisAngle = function(axis, a)
		local u = axis.Unit
		local c, s, t = cos(a), sin(a), 1 - cos(a)
		local x, y, z = u.x, u.y, u.z
		return cf(0, 0, 0, t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c)
	end,
	fromMatrix = function(p, r, u, b)
		b = b or V3.Cross(r, u)
		return cf(p.x, p.y, p.z, r.x, u.x, b.x, r.y, u.y, b.y, r.z, u.z, b.z)
	end,
}
CFrame.identity = cf(0, 0, 0)
local function isCF(c) return type(c) == "table" and getmetatable(c) == CFmt end

--------------------------------------------------------------------------------
-- Color3 and friends
--------------------------------------------------------------------------------
local C3 = {}
local C3mt = {}
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt) end
C3mt.__index = C3
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, mx
	local d = mx - mn
	if mx > 0 then s = d / mx end
	if d > 0 then
		if mx == r then h = (g - b) / d % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, s, v
end
function C3.ToHex(c) return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
		elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}
BrickColor = {
	new = function(name) return { Name = name, Color = c3(0.6, 0.6, 0.6) } end,
	random = function() return { Name = "random", Color = c3(0.6, 0.6, 0.6) } end,
}
local function passthrough(kind)
	return { new = function(...) return { __kind = kind, ... } end }
end
ColorSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) ~= C3mt then return { Keypoints = a, __kind = "ColorSequence" } end
	return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } }, __kind = "ColorSequence" }
end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberSequence = { new = function(a, b)
	if type(a) == "table" then return { Keypoints = a, __kind = "NumberSequence" } end
	return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } }, __kind = "NumberSequence" }
end }
NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local U2mt = {}
local function udim2(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo), Width = UDim.new(xs, xo), Height = UDim.new(ys, yo) }, U2mt)
end
U2mt.__add = function(a, b) return udim2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
U2mt.__sub = function(a, b) return udim2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UDim2 = {
	new = function(xs, xo, ys, yo)
		if type(xs) == "table" then return udim2(xs.Scale, xs.Offset, xo.Scale, xo.Offset) end
		return udim2(xs, xo, ys, yo)
	end,
	fromScale = function(x, y) return udim2(x, 0, y, 0) end,
	fromOffset = function(x, y) return udim2(0, x, 0, y) end,
}
Rect = passthrough("Rect")
PhysicalProperties = passthrough("PhysicalProperties")
TweenInfo = passthrough("TweenInfo")
Ray = passthrough("Ray")
Font = { new = function(...) return { ... } end, fromEnum = function(e) return e end, fromName = function(n) return n end }
RaycastParams = { new = function() return {} end }
OverlapParams = { new = function() return {} end }
Region3 = passthrough("Region3")
Random = { new = function(seed)
	local r = { s = seed or 1 }
	function r:NextNumber(a, b) a = a or 0; b = b or 1; return a + (b - a) * math.random() end
	function r:NextInteger(a, b) return math.random(a, b) end
	return r
end }

-- Enum: Enum.Material.Neon etc. are unique tables with a Name.
local enumCache = {}
Enum = setmetatable({}, { __index = function(_, group)
	local g = enumCache[group]
	if not g then
		g = setmetatable({}, { __index = function(t, name)
			local item = { Name = name, EnumType = group, Value = 0 }
			rawset(t, name, item)
			return item
		end })
		enumCache[group] = g
	end
	return g
end })

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end, Connected = true }
	end
	s.connect = s.Connect
	function s:Once(fn) return self:Connect(fn) end
	function s:Wait() return coroutine.yield() end
	function s:Fire(...) for _, h in ipairs(self.handlers) do h(...) end end
	return s
end

--------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------
local IS_A = {
	BasePart = { Part = true, WedgePart = true, MeshPart = true, SpawnLocation = true, CornerWedgePart = true, TrussPart = true, UnionOperation = true, Seat = true },
	PVInstance = { Model = true, Part = true, WedgePart = true, MeshPart = true, SpawnLocation = true, CornerWedgePart = true },
	GuiObject = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true, TextBox = true, CanvasGroup = true },
	GuiButton = { TextButton = true, ImageButton = true },
	LayerCollector = { ScreenGui = true, BillboardGui = true, SurfaceGui = true },
	GuiBase2d = { ScreenGui = true, BillboardGui = true, SurfaceGui = true, Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, ViewportFrame = true },
	Light = { PointLight = true, SpotLight = true, SurfaceLight = true },
	Clothing = { Shirt = true, Pants = true },
	ValueBase = { IntValue = true, NumberValue = true, StringValue = true, BoolValue = true, ObjectValue = true },
	JointInstance = { Weld = true, Motor6D = true, WeldConstraint = true },
	LuaSourceContainer = { Script = true, LocalScript = true, ModuleScript = true },
	BaseScript = { Script = true, LocalScript = true },
	HandleAdornment = { BoxHandleAdornment = true, CylinderHandleAdornment = true, SphereHandleAdornment = true, ConeHandleAdornment = true },
	Constraint = { Beam = true, RopeConstraint = true },
	FaceInstance = { Decal = true, Texture = true },
}

local DEFAULTS = {
	Part = function() return { Size = v3(4, 1.2, 2), CFrame = cf(0, 0, 0), Color = c3(0.64, 0.64, 0.64), Transparency = 0,
		Anchored = false, CanCollide = true, Material = Enum.Material.Plastic, Shape = Enum.PartType.Block, Reflectance = 0 } end,
}
DEFAULTS.WedgePart = DEFAULTS.Part
DEFAULTS.CornerWedgePart = DEFAULTS.Part
DEFAULTS.MeshPart = DEFAULTS.Part
DEFAULTS.SpawnLocation = DEFAULTS.Part
DEFAULTS.SpecialMesh = function() return { MeshType = Enum.MeshType.Head, Scale = v3(1, 1, 1), Offset = v3(0, 0, 0) } end
DEFAULTS.Attachment = function() return { CFrame = cf(0, 0, 0) } end
DEFAULTS.Humanoid = function() return { HipHeight = 2, Health = 100, MaxHealth = 100, WalkSpeed = 16, RigType = Enum.HumanoidRigType.R15 } end
DEFAULTS.BillboardGui = function() return { Size = udim2(0, 0, 0, 0), StudsOffset = v3(0, 0, 0), StudsOffsetWorldSpace = v3(0, 0, 0), MaxDistance = math.huge, Enabled = true } end
DEFAULTS.Frame = function() return { Size = udim2(0, 100, 0, 100), Position = udim2(0, 0, 0, 0), AnchorPoint = Vector2.new(0, 0),
	BackgroundColor3 = c3(1, 1, 1), BackgroundTransparency = 0, Visible = true, ZIndex = 1, LayoutOrder = 0, Rotation = 0, BorderSizePixel = 1 } end
DEFAULTS.TextLabel = function()
	local t = DEFAULTS.Frame()
	t.Text = "Label"; t.TextColor3 = c3(0, 0, 0); t.TextSize = 14; t.TextTransparency = 0; t.TextScaled = false
	t.TextXAlignment = Enum.TextXAlignment.Center; t.TextYAlignment = Enum.TextYAlignment.Center; t.Size = udim2(0, 200, 0, 50)
	return t
end
DEFAULTS.TextButton = function() local t = DEFAULTS.TextLabel(); t.Text = "Button"; return t end
DEFAULTS.TextBox = DEFAULTS.TextLabel
DEFAULTS.ImageLabel = function() local t = DEFAULTS.Frame(); t.Image = ""; t.ImageColor3 = c3(1, 1, 1); t.ImageTransparency = 0; return t end
DEFAULTS.ImageButton = DEFAULTS.ImageLabel
DEFAULTS.ScrollingFrame = function() local t = DEFAULTS.Frame(); t.CanvasSize = udim2(0, 0, 0, 0); t.ClipsDescendants = true; return t end
DEFAULTS.ViewportFrame = DEFAULTS.Frame
DEFAULTS.CanvasGroup = DEFAULTS.Frame
DEFAULTS.ScreenGui = function() return { Enabled = true, DisplayOrder = 0, IgnoreGuiInset = false } end
DEFAULTS.UIScale = function() return { Scale = 1 } end
DEFAULTS.UIStroke = function() return { Thickness = 1, Color = c3(0, 0, 0), Transparency = 0, Enabled = true } end
DEFAULTS.UICorner = function() return { CornerRadius = UDim.new(0, 8) } end
DEFAULTS.UIGradient = function() return { Color = ColorSequence.new(c3(1, 1, 1)), Rotation = 0, Offset = Vector2.new(0, 0), Enabled = true } end
DEFAULTS.UIListLayout = function() return { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 0),
	HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder } end
DEFAULTS.UIGridLayout = function() return { CellSize = udim2(0, 100, 0, 100), CellPadding = udim2(0, 5, 0, 5), FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder } end
DEFAULTS.UIPadding = function() return { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0) } end
DEFAULTS.UIAspectRatioConstraint = function() return { AspectRatio = 1 } end
DEFAULTS.PointLight = function() return { Brightness = 1, Range = 8, Color = c3(1, 1, 1), Enabled = true } end
DEFAULTS.SurfaceLight = DEFAULTS.PointLight
DEFAULTS.SpotLight = DEFAULTS.PointLight
DEFAULTS.ParticleEmitter = function() return { Rate = 5, Enabled = true } end
DEFAULTS.Sound = function() return { Volume = 0.5, Playing = false, SoundId = "" } end
DEFAULTS.Camera = function() return { CFrame = cf(0, 0, 0), FieldOfView = 70, ViewportSize = Vector2.new(1280, 720) } end
DEFAULTS.Model = function() return {} end

local SIGNAL_NAMES = {
	Activated = true, MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true, MouseEnter = true, MouseLeave = true,
	Touched = true, TouchEnded = true, Changed = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
	AncestryChanged = true, Destroying = true, Triggered = true, TriggerEnded = true, PromptShown = true, PromptHidden = true, Completed = true,
	Died = true, Running = true, StateChanged = true, HealthChanged = true, MoveToFinished = true, FocusLost = true, InputBegan = true,
	InputEnded = true, InputChanged = true, Heartbeat = true, RenderStepped = true, Stepped = true, PlayerAdded = true, PlayerRemoving = true,
	CharacterAdded = true, CharacterRemoving = true, OnClientEvent = true, OnServerEvent = true, Event = true, Played = true, Ended = true,
	Stopped = true, DidLoop = true, KeyframeReached = true, PromptGamePassPurchaseFinished = true, PromptProductPurchaseFinished = true,
	LocalToolEquipped = true, Equipped = true, Unequipped = true, TouchTap = true, JumpRequest = true, WindowFocused = true,
	PromptTriggered = true, PromptButtonHoldBegan = true, PromptButtonHoldEnded = true, TouchStarted = true, TouchMoved = true,
	OnClientInvoke = true, CharacterAppearanceLoaded = true, MouseWheelForward = true, MouseWheelBackward = true, SelectionGained = true, AttributeChanged = true,
}

local INST = {}
local Imt = {}
local allInstances = {}

local function isInstance(x) return type(x) == "table" and getmetatable(x) == Imt end

local function newInstance(className)
	local props = DEFAULTS[className] and DEFAULTS[className]() or {}
	local self = setmetatable({ __class = className, __props = props, __children = {}, __attrs = {}, __signals = {} }, Imt)
	props.Name = className
	props.ClassName = className
	table.insert(allInstances, self)
	return self
end

Imt.__index = function(self, k)
	local props = rawget(self, "__props")
	local v = props[k]
	if v ~= nil then return v end
	if k == "Position" and props.CFrame then return props.CFrame.Position end
	if k == "Orientation" then return v3(0, 0, 0) end
	if k == "AssemblyLinearVelocity" or k == "Velocity" then return v3(0, 0, 0) end
	if k == "AbsoluteSize" then return Vector2.new(100, 100) end
	if k == "AbsolutePosition" then return Vector2.new(0, 0) end
	if k == "WorldPivot" then return INST.GetPivot(self) end
	if INST[k] then return INST[k] end
	if SIGNAL_NAMES[k] then
		local sigs = rawget(self, "__signals")
		sigs[k] = sigs[k] or signal()
		return sigs[k]
	end
	-- a child with that name
	for _, c in ipairs(rawget(self, "__children")) do
		if c.__props.Name == k then return c end
	end
	return nil
end

Imt.__newindex = function(self, k, v)
	local props = rawget(self, "__props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "__children")
			for i, c in ipairs(list) do if c == self then table.remove(list, i) break end end
		end
		props.Parent = v
		if v then table.insert(rawget(v, "__children"), self) end
		return
	end
	if k == "Position" and props.CFrame then
		local c = props.CFrame
		props.CFrame = cf(v.x, v.y, v.z, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		return
	end
	if k == "Orientation" and isV3(v) then
		local p = props.CFrame and props.CFrame.Position or v3(0, 0, 0)
		props.CFrame = CFrame.new(p) * CFrame.fromOrientation(math.rad(v.x), math.rad(v.y), math.rad(v.z))
		return
	end
	if k == "PrimaryPart" or k == "Name" or k == "CFrame" then props[k] = v; return end
	props[k] = v
end
Imt.__tostring = function(self) return self.__props.Name end

function INST.IsA(self, name)
	local cls = rawget(self, "__class")
	if cls == name or name == "Instance" then return true end
	local set = IS_A[name]
	return set ~= nil and set[cls] == true
end
function INST.GetChildren(self)
	local t = {}
	for i, c in ipairs(rawget(self, "__children")) do t[i] = c end
	return t
end
function INST.GetDescendants(self)
	local out = {}
	local function walk(n)
		for _, c in ipairs(rawget(n, "__children")) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function INST.FindFirstChild(self, name, recursive)
	for _, c in ipairs(rawget(self, "__children")) do
		if c.__props.Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(rawget(self, "__children")) do
			local f = INST.FindFirstChild(c, name, true)
			if f then return f end
		end
	end
	return nil
end
function INST.WaitForChild(self, name)
	local c = INST.FindFirstChild(self, name)
	if not c then
		c = newInstance("Folder")
		c.Name = name
		c.Parent = self
	end
	return c
end
function INST.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(rawget(self, "__children")) do if rawget(c, "__class") == cls then return c end end
	return nil
end
function INST.FindFirstChildWhichIsA(self, cls, recursive)
	for _, c in ipairs(rawget(self, "__children")) do if INST.IsA(c, cls) then return c end end
	if recursive then
		for _, c in ipairs(rawget(self, "__children")) do
			local f = INST.FindFirstChildWhichIsA(c, cls, true)
			if f then return f end
		end
	end
	return nil
end
function INST.FindFirstAncestor(self, name)
	local p = self.__props.Parent
	while p do
		if p.__props.Name == name then return p end
		p = p.__props.Parent
	end
	return nil
end
function INST.FindFirstAncestorOfClass(self, cls)
	local p = self.__props.Parent
	while p do
		if rawget(p, "__class") == cls then return p end
		p = p.__props.Parent
	end
	return nil
end
function INST.FindFirstAncestorWhichIsA(self, cls)
	local p = self.__props.Parent
	while p do
		if INST.IsA(p, cls) then return p end
		p = p.__props.Parent
	end
	return nil
end
function INST.IsDescendantOf(self, other)
	local p = self.__props.Parent
	while p do
		if p == other then return true end
		p = p.__props.Parent
	end
	return false
end
function INST.Destroy(self)
	self.Parent = nil
	rawget(self, "__props").__destroyed = true
end
function INST.ClearAllChildren(self)
	for _, c in ipairs(INST.GetChildren(self)) do INST.Destroy(c) end
end
local function cloneTree(self, map)
	local copy = newInstance(rawget(self, "__class"))
	map[self] = copy
	for k, v in pairs(rawget(self, "__props")) do
		if k ~= "Parent" then rawget(copy, "__props")[k] = v end
	end
	for k, v in pairs(rawget(self, "__attrs")) do rawget(copy, "__attrs")[k] = v end
	for _, c in ipairs(rawget(self, "__children")) do
		local cc = cloneTree(c, map)
		cc.Parent = copy
	end
	return copy
end
-- Like Roblox, references inside the copy (PrimaryPart, weld parts,
-- adornees) point at the copied instances, not the originals.
function INST.Clone(self)
	local map = {}
	local copy = cloneTree(self, map)
	for _, c in pairs(map) do
		local props = rawget(c, "__props")
		for k, v in pairs(props) do
			if k ~= "Parent" and map[v] then props[k] = map[v] end
		end
	end
	return copy
end
function INST.SetAttribute(self, k, v) rawget(self, "__attrs")[k] = v end
function INST.GetAttribute(self, k) return rawget(self, "__attrs")[k] end
function INST.GetAttributes(self) return rawget(self, "__attrs") end
function INST.GetAttributeChangedSignal(self, k) return signal() end
function INST.GetPropertyChangedSignal(self, k) return signal() end
function INST.GetFullName(self)
	local names = {}
	local n = self
	while n do table.insert(names, 1, n.__props.Name); n = n.__props.Parent end
	return table.concat(names, ".")
end
function INST.Play() end
function INST.Stop() end
function INST.Pause() end
function INST.Emit() end
function INST.Clear() end
function INST.FireServer() end
function INST.FireClient() end
function INST.FireAllClients() end
function INST.InvokeServer() return false end
function INST.SetPrimaryPartCFrame(self, c) INST.PivotTo(self, c) end
function INST.GetPrimaryPartCFrame(self) return INST.GetPivot(self) end
function INST.LoadAnimation(self)
	local track = newInstance("AnimationTrack")
	return track
end
function INST.GetPlayingAnimationTracks() return {} end
function INST.ChangeState() end
function INST.GetState() return Enum.HumanoidStateType.Running end
function INST.SetStateEnabled() end
function INST.MoveTo() end
function INST.TakeDamage() end
function INST.ApplyDescription() end
function INST.GetAppliedDescription(self) return newInstance("HumanoidDescription") end
function INST.BreakJoints() end
function INST.SetNetworkOwner() end
function INST.ApplyImpulse() end
function INST.GetMass() return 1 end
function INST.GetConnectedParts() return {} end
function INST.GetTouchingParts() return {} end
function INST.TweenSize() end
function INST.TweenPosition() end

local function partsOf(model)
	local list = {}
	if INST.IsA(model, "BasePart") then table.insert(list, model) end
	for _, d in ipairs(INST.GetDescendants(model)) do
		if INST.IsA(d, "BasePart") then table.insert(list, d) end
	end
	return list
end
function INST.GetBoundingBox(self)
	local mn, mx = v3(math.huge, math.huge, math.huge), v3(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(partsOf(self)) do
		local c = p.__props.CFrame
		local s = p.__props.Size * 0.5
		for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			local w = c * v3(sx * s.x, sy * s.y, sz * s.z)
			mn = V3.Min(mn, w); mx = V3.Max(mx, w)
		end end end
	end
	if mn.x == math.huge then return cf(0, 0, 0), v3(0, 0, 0) end
	return CFrame.new((mn + mx) * 0.5), mx - mn
end
function INST.GetExtentsSize(self)
	local _, size = INST.GetBoundingBox(self)
	return size
end
function INST.GetPivot(self)
	local props = rawget(self, "__props")
	if INST.IsA(self, "BasePart") then return props.CFrame end
	if props.__pivot then return props.__pivot end
	if props.PrimaryPart then return props.PrimaryPart.__props.CFrame end
	local c = INST.GetBoundingBox(self)
	return c
end
function INST.PivotTo(self, target)
	local current = INST.GetPivot(self)
	local delta = target * CF.Inverse(current)
	for _, p in ipairs(partsOf(self)) do
		p.__props.CFrame = delta * p.__props.CFrame
	end
	local props = rawget(self, "__props")
	if not INST.IsA(self, "BasePart") and props.__pivot then props.__pivot = target end
end
function INST.ScaleTo(self, s)
	local props = rawget(self, "__props")
	local old = props.__scale or 1
	local k = s / old
	local pivot = INST.GetPivot(self)
	for _, p in ipairs(partsOf(self)) do
		local local_ = CF.Inverse(pivot) * p.__props.CFrame
		local pos = local_.Position * k
		p.__props.CFrame = pivot * cf(pos.x, pos.y, pos.z, local_[4], local_[5], local_[6], local_[7], local_[8], local_[9], local_[10], local_[11], local_[12])
		p.__props.Size = p.__props.Size * k
	end
	for _, d in ipairs(INST.GetDescendants(self)) do
		if rawget(d, "__class") == "SpecialMesh" then d.__props.Scale = d.__props.Scale end
	end
	props.__scale = s
end
function INST.GetScale(self) return rawget(self, "__props").__scale or 1 end

Instance = { new = function(className, parent)
	local i = newInstance(className)
	if parent then i.Parent = parent end
	return i
end }

--------------------------------------------------------------------------------
-- The data model
--------------------------------------------------------------------------------
game = newInstance("DataModel")
game.Name = "Game"
local services = {}
function INST.GetService(self, name)
	if not services[name] then
		local s = newInstance(name)
		s.Name = name
		s.Parent = game
		services[name] = s
	end
	return services[name]
end
INST.FindService = INST.GetService
workspace = INST.GetService(game, "Workspace")
workspace.Name = "Workspace"
local camera = newInstance("Camera")
camera.Parent = workspace
workspace.CurrentCamera = camera
workspace.Gravity = 196.2
function INST.GetServerTimeNow() return 1000 end
function INST.Raycast() return nil end
function INST.GetPartBoundsInBox() return {} end
function INST.GetPartBoundsInRadius() return {} end
function INST.GetPartsInPart() return {} end
function INST.IsServer() return true end
function INST.IsClient() return false end
function INST.IsStudio() return true end
function INST.GetPlayers() return {} end
-- Tweens jump straight to where they end, so pictures show the final state.
function INST.Create(self, obj, info, goal)
	local t = newInstance("Tween")
	rawset(t, "__tweenTarget", obj)
	rawset(t, "__tweenGoal", goal)
	return t
end
function INST.Play(self)
	local obj, goal = rawget(self, "__tweenTarget"), rawget(self, "__tweenGoal")
	if obj and goal then
		for k, v in pairs(goal) do obj[k] = v end
	end
end
function INST.AddItem() end
function INST.JSONEncode(self, v)
	local function enc(x)
		local t = type(x)
		if t == "table" then
			if #x > 0 or next(x) == nil then
				local parts = {}
				for _, e in ipairs(x) do table.insert(parts, enc(e)) end
				return "[" .. table.concat(parts, ",") .. "]"
			end
			local parts = {}
			for k, e in pairs(x) do table.insert(parts, string.format("%q", tostring(k)) .. ":" .. enc(e)) end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif t == "string" then return string.format("%q", x)
		elseif t == "number" or t == "boolean" then return tostring(x)
		end
		return "null"
	end
	return enc(v)
end
-- A small JSON reader (enough for what the games store in attributes).
function INST.JSONDecode(self, s)
	local i = 1
	local function ws() i = string.find(s, "[^ \t\r\n]", i) or #s + 1 end
	local value
	local function str()
		local out = {}
		i += 1
		while true do
			local c = string.sub(s, i, i)
			if c == "" then error("JSONDecode: open string") end
			if c == '"' then i += 1; break end
			if c == "\\" then
				local n = string.sub(s, i + 1, i + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
				if n == "u" then
					table.insert(out, utf8.char(tonumber(string.sub(s, i + 2, i + 5), 16)))
					i += 6
				else
					table.insert(out, map[n] or n)
					i += 2
				end
			else
				table.insert(out, c)
				i += 1
			end
		end
		return table.concat(out)
	end
	function value()
		ws()
		local c = string.sub(s, i, i)
		if c == "{" then
			local t = {}
			i += 1
			ws()
			if string.sub(s, i, i) == "}" then i += 1; return t end
			while true do
				ws()
				local k = str()
				ws()
				i += 1 -- :
				t[k] = value()
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "}" then return t end
			end
		elseif c == "[" then
			local t = {}
			i += 1
			ws()
			if string.sub(s, i, i) == "]" then i += 1; return t end
			while true do
				table.insert(t, value())
				ws()
				local d = string.sub(s, i, i)
				i += 1
				if d == "]" then return t end
			end
		elseif c == '"' then
			return str()
		elseif string.sub(s, i, i + 3) == "true" then i += 4; return true
		elseif string.sub(s, i, i + 4) == "false" then i += 5; return false
		elseif string.sub(s, i, i + 3) == "null" then i += 4; return nil
		end
		local num = string.match(s, "^-?[%d%.eE+-]+", i)
		if not num then error("JSONDecode: bad value at " .. i) end
		i += #num
		return tonumber(num)
	end
	return value()
end
function INST.GenerateGUID() return "guid" end
function INST.GetProductInfo() return { PriceInRobux = 99 } end
function INST.UserOwnsGamePassAsync() return false end
function INST.GetDataStore(self)
	local ds = newInstance("DataStore")
	return ds
end
function INST.GetOrderedDataStore(self) return newInstance("OrderedDataStore") end
function INST.GetAsync() return nil end
function INST.SetAsync() end
function INST.UpdateAsync() end
function INST.GetSortedAsync() return { GetCurrentPage = function() return {} end } end
function INST.RegisterCollisionGroup() end
function INST.CollisionGroupSetCollidable() end
function INST.CreatePath() return newInstance("Path") end
function INST.GetUserThumbnailAsync() return "" end

-- A default blocky R15 body.
local R15_PARTS = {
	{ "HumanoidRootPart", v3(2, 2, 1), v3(0, 3, 0), true },
	{ "LowerTorso", v3(2, 0.4, 1), v3(0, 2.2, 0) },
	{ "UpperTorso", v3(2, 1.6, 1), v3(0, 3.2, 0) },
	{ "Head", v3(1.2, 1.2, 1.2), v3(0, 4.6, 0) },
	{ "LeftUpperArm", v3(1, 1.2, 1), v3(-1.5, 3.4, 0) },
	{ "LeftLowerArm", v3(1, 0.95, 1), v3(-1.5, 2.45, 0) },
	{ "LeftHand", v3(1, 0.3, 1), v3(-1.5, 1.85, 0) },
	{ "RightUpperArm", v3(1, 1.2, 1), v3(1.5, 3.4, 0) },
	{ "RightLowerArm", v3(1, 0.95, 1), v3(1.5, 2.45, 0) },
	{ "RightHand", v3(1, 0.3, 1), v3(1.5, 1.85, 0) },
	{ "LeftUpperLeg", v3(1, 1.0, 1), v3(-0.5, 1.5, 0) },
	{ "LeftLowerLeg", v3(1, 0.9, 1), v3(-0.5, 0.65, 0) },
	{ "LeftFoot", v3(1, 0.3, 1), v3(-0.5, 0.15, 0) },
	{ "RightUpperLeg", v3(1, 1.0, 1), v3(0.5, 1.5, 0) },
	{ "RightLowerLeg", v3(1, 0.9, 1), v3(0.5, 0.65, 0) },
	{ "RightFoot", v3(1, 0.3, 1), v3(0.5, 0.15, 0) },
}
function MockRig(description)
	local model = newInstance("Model")
	model.Name = "Rig"
	local humanoid = newInstance("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	local colors = newInstance("BodyColors")
	local skin = description and description.HeadColor or c3(0.92, 0.78, 0.65)
	colors.HeadColor3 = skin
	colors.TorsoColor3 = description and description.TorsoColor or c3(0.3, 0.4, 0.8)
	colors.LeftArmColor3 = description and description.LeftArmColor or skin
	colors.RightArmColor3 = description and description.RightArmColor or skin
	colors.LeftLegColor3 = description and description.LeftLegColor or c3(0.2, 0.3, 0.2)
	colors.RightLegColor3 = description and description.RightLegColor or c3(0.2, 0.3, 0.2)
	colors.Parent = model
	-- Body scales from the description (roughly how Roblox applies them).
	local W = description and description.WidthScale or 1
	local H = description and description.HeightScale or 1
	local D = description and description.DepthScale or 1
	local HS = description and description.HeadScale or 1
	humanoid.HipHeight = 2 * H
	for _, def in ipairs(R15_PARTS) do
		local p = newInstance("MeshPart")
		p.Name = def[1]
		local size, pos = def[2], def[3]
		if def[1] == "Head" then
			p.Size = v3(size.x * HS, size.y * HS, size.z * HS)
			p.CFrame = CFrame.new(pos.x, 4 * H + 0.6 * HS, pos.z)
		else
			p.Size = v3(size.x * W, size.y * H, size.z * D)
			p.CFrame = CFrame.new(pos.x * W, pos.y * H, pos.z * D)
		end
		p.Transparency = def[4] and 1 or 0
		local n = def[1]
		if n == "Head" then p.Color = colors.HeadColor3
		elseif n:find("Torso") then p.Color = colors.TorsoColor3
		elseif n:find("Arm") or n:find("Hand") then p.Color = n:find("Left") and colors.LeftArmColor3 or colors.RightArmColor3
		elseif n:find("Leg") or n:find("Foot") then p.Color = n:find("Left") and colors.LeftLegColor3 or colors.RightLegColor3 end
		p.Parent = model
		if n == "HumanoidRootPart" then model.PrimaryPart = p end
		if n == "Head" then
			local face = newInstance("Decal")
			face.Name = "face"
			face.Parent = p
		end
	end
	local animator = newInstance("Animator")
	animator.Parent = humanoid
	return model
end
function INST.CreateHumanoidModelFromDescription(self, desc) return MockRig(desc) end
-- A made-up avatar for a user id (a shirt and trousers from the id).
function INST.GetHumanoidDescriptionFromUserId(self, userId)
	local d = newInstance("HumanoidDescription")
	local k = (userId * 7919) % 360 / 360
	d.TorsoColor = Color3.fromHSV(k, 0.7, 0.85)
	d.LeftLegColor = Color3.fromHSV((k + 0.5) % 1, 0.5, 0.35)
	d.RightLegColor = d.LeftLegColor
	return d
end
-- FRIENDS="11,12,13" gives the player friends.
function INST.GetFriendsAsync(self, userId)
	local page = {}
	for id in tostring(FRIENDS or ""):gmatch("%d+") do table.insert(page, { Id = tonumber(id), Username = "Friend" .. id }) end
	return { IsFinished = true, GetCurrentPage = function() return page end, AdvanceToNextPageAsync = function() end }
end
function INST.AdjustSpeed() end

-- task.wait parks the running thread; nothing moves on by itself, but a
-- driver can call RunScheduler(n) to let every waiting thread (and every
-- task.delay) run n more steps, for example to catch an animation halfway.
local waiting = {}
task = {
	spawn = function(fn, ...)
		if type(fn) ~= "function" then return end
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then print("TASKERR\t" .. tostring(err)) end
		return co
	end,
	defer = function(fn, ...) return task.spawn(fn, ...) end,
	delay = function(_, fn, ...)
		if type(fn) ~= "function" then return end
		local args = table.pack(...)
		table.insert(waiting, coroutine.create(function() fn(table.unpack(args, 1, args.n)) end))
	end,
	wait = function()
		if coroutine.isyieldable() then
			table.insert(waiting, coroutine.running())
			coroutine.yield()
		end
		return 0
	end,
	cancel = function() end,
}
function RunScheduler(steps)
	for _ = 1, steps or 1 do
		local list = waiting
		waiting = {}
		for _, co in ipairs(list) do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then print("TASKERR\t" .. tostring(err)) end
			end
		end
	end
end
wait = task.wait
delay = task.delay
spawn = task.spawn
tick = os.clock
time = os.clock
elapsedTime = os.clock
warn = function(...) print("WARN", ...) end
typeof = function(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt == V3mt then return "Vector3" elseif mt == CFmt then return "CFrame" elseif mt == C3mt then return "Color3"
		elseif mt == Imt then return "Instance" elseif mt == U2mt then return "UDim2" end
		if v.Scale ~= nil and v.Offset ~= nil then return "UDim" end
		if v.EnumType then return "EnumItem" end
	end
	return t
end
settings = function() return { Rendering = {} } end
UserSettings = function() return { GetService = function() return {} end } end
shared = {}

--------------------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------------------
MODULES = MODULES or {}
local loaded = {}
local realRequire = require
require = function(target)
	local name = isInstance(target) and target.__props.Name or tostring(target)
	if loaded[name] ~= nil then return loaded[name] end
	local fn = MODULES[name]
	if not fn then error("mock require: no module " .. name) end
	loaded[name] = fn()
	return loaded[name]
end

--------------------------------------------------------------------------------
-- Export parts
--------------------------------------------------------------------------------
local function num(x) return string.format("%.4f", x) end
local function color(c) return num(c.R) .. "," .. num(c.G) .. "," .. num(c.B) end

-- Top, Bottom, Front, Back, Left, Right surfaces: S studs, I inlet, - other
local function surfaces(props)
	local out = {}
	for _, k in ipairs({ "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }) do
		local v = props[k]
		local n = v and (v.Name or tostring(v)) or ""
		table.insert(out, n == "Studs" and "S" or (n == "Inlet" and "I" or "-"))
	end
	return table.concat(out)
end

function ExportParts(root, tag)
	local list = partsOf(root)
	for _, p in ipairs(list) do
		local props = p.__props
		if not props.__destroyed then
			local c = props.CFrame
			local s = props.Size
			local shape = "Block"
			local cls = rawget(p, "__class")
			if cls == "WedgePart" then shape = "Wedge"
			elseif cls == "CornerWedgePart" then shape = "CornerWedge"
			elseif props.Shape then shape = props.Shape.Name or "Block" end
			local mesh = INST.FindFirstChildOfClass(p, "SpecialMesh")
			local meshType, meshScale = "", v3(1, 1, 1)
			if mesh then
				meshType = mesh.__props.MeshType and mesh.__props.MeshType.Name or ""
				meshScale = mesh.__props.Scale or v3(1, 1, 1)
			end
			if cls == "MeshPart" and props.Name == "Head" then meshType = "Head" end
			local mat = props.Material and props.Material.Name or "Plastic"
			local lights = 0
			local surf = surfaces(props)
			local studScale = (rawget(p, "__attrs") or {}).StudScale or 1
			local faceIndex = { Top = 1, Bottom = 2, Front = 3, Back = 4, Left = 5, Right = 6 }
			for _, ch in ipairs(rawget(p, "__children")) do
				if INST.IsA(ch, "Light") then lights = math.max(lights, (ch.__props.Brightness or 1) * (ch.__props.Range or 8)) end
				-- the Baseplate squares (StudTexture): drawn as a Studs face with the tile
				if rawget(ch, "__class") == "Texture" and ch.__props.Name == "StudTexture" and not ch.__props.__destroyed then
					local i = faceIndex[ch.__props.Face and ch.__props.Face.Name or "Front"]
					if i then surf = surf:sub(1, i - 1) .. "S" .. surf:sub(i + 1) end
					studScale = (ch.__props.StudsPerTileU or 4) / 4
				end
			end
			print(table.concat({ "P", tag or "", props.Name,
				num(c[1]), num(c[2]), num(c[3]), num(c[4]), num(c[5]), num(c[6]), num(c[7]), num(c[8]), num(c[9]), num(c[10]), num(c[11]), num(c[12]),
				num(s.x), num(s.y), num(s.z), color(props.Color or c3(0.6, 0.6, 0.6)), num(props.Transparency or 0), mat, shape, meshType,
				num(meshScale.x) .. "," .. num(meshScale.y) .. "," .. num(meshScale.z), num(lights), num(props.Reflectance or 0), surf,
				num(studScale) }, "\t"))
		end
	end
	-- Billboard signs: adornee position + first title text
	for _, d in ipairs(INST.GetDescendants(root)) do
		if rawget(d, "__class") == "BillboardGui" then
			local props = d.__props
			local ad = props.Adornee or props.Parent
			if ad and ad.__props and ad.__props.CFrame then
				local pos = ad.__props.CFrame.Position + (props.StudsOffsetWorldSpace or v3(0, 0, 0)) + (props.StudsOffset or v3(0, 0, 0))
				local texts = {}
				local bg = nil
				for _, t in ipairs(INST.GetDescendants(d)) do
					if (rawget(t, "__class") == "TextLabel" or rawget(t, "__class") == "TextButton") and t.__props.Text and t.__props.Text ~= "" then
						table.insert(texts, (t.__props.Text:gsub("\t", " "):gsub("\n", " ")))
					end
					if not bg and rawget(t, "__class") == "Frame" and (t.__props.BackgroundTransparency or 0) < 0.9 then
						bg = t.__props.BackgroundColor3
					end
				end
				local size = props.Size
				print(table.concat({ "B", tag or "", props.Name, num(pos.x), num(pos.y), num(pos.z),
					num(size.X.Scale), num(size.Y.Scale), num(size.X.Offset), num(size.Y.Offset),
					num(props.MaxDistance == math.huge and 99999 or props.MaxDistance or 99999),
					bg and color(bg) or "1,1,1", table.concat(texts, " | ") }, "\t"))
			end
		end
	end
	-- SurfaceGuis: the part they are on, then what they show as g<n> lines
	-- (read by render.py, which paints them onto that face).
	local count = 0
	for _, d in ipairs(INST.GetDescendants(root)) do
		if rawget(d, "__class") == "SurfaceGui" then
			local props = d.__props
			local ad = props.Adornee or props.Parent
			if ad and ad.__props and ad.__props.CFrame and ad.__props.Size then
				count += 1
				local c, s = ad.__props.CFrame, ad.__props.Size
				print(table.concat({ "S", tag or "", tostring(count),
					num(c[1]), num(c[2]), num(c[3]), num(c[4]), num(c[5]), num(c[6]), num(c[7]), num(c[8]), num(c[9]), num(c[10]), num(c[11]), num(c[12]),
					num(s.x), num(s.y), num(s.z), (props.Face and props.Face.Name) or "Front", num(props.PixelsPerStud or 50) }, "\t"))
				ExportGui(d, "g" .. count)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Export the GUI tree
--------------------------------------------------------------------------------
local GUI_CLASSES = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true,
	ViewportFrame = true, TextBox = true, CanvasGroup = true, ScreenGui = true }
function ExportGui(root, lineTag)
	local ids = {}
	local nextId = 0
	local function udim2(u) if not u then return "0,0,0,0" end return table.concat({ num(u.X.Scale), num(u.X.Offset), num(u.Y.Scale), num(u.Y.Offset) }, ",") end
	local function col(c) return c and color(c) or "" end
	local function walk(node, parentId)
		for _, child in ipairs(rawget(node, "__children")) do
			local cls = rawget(child, "__class")
			local pr = child.__props
			if GUI_CLASSES[cls] then
				nextId += 1
				local id = nextId
				local mods = {}
				for _, m in ipairs(rawget(child, "__children")) do
					local mc = rawget(m, "__class")
					local mp = m.__props
					if mc == "UICorner" then table.insert(mods, "corner=" .. num(mp.CornerRadius.Scale) .. "," .. num(mp.CornerRadius.Offset))
					elseif mc == "UIStroke" then
						local g = INST.FindFirstChildOfClass(m, "UIGradient")
						table.insert(mods, "stroke=" .. num(mp.Thickness or 1) .. "," .. col(mp.Color) .. "," .. num(mp.Transparency or 0) .. "," .. ((mp.ApplyStrokeMode and mp.ApplyStrokeMode.Name) or "Contextual"))
					elseif mc == "UIGradient" then
						local kp = mp.Color and mp.Color.Keypoints or {}
						local stops = {}
						for _, k in ipairs(kp) do table.insert(stops, num(k.Time) .. ":" .. col(k.Value)) end
						if #stops == 0 then stops = { "0:1,1,1", "1:1,1,1" } end
						local tstops = {}
						local tr = mp.Transparency
						if type(tr) == "table" then
							for _, k in ipairs(tr.Keypoints or {}) do
								table.insert(tstops, num(k.Time) .. ":" .. num(k.Value))
							end
						end
						table.insert(mods, "grad=" .. table.concat(stops, "|") .. "/" .. num(mp.Rotation or 0) .. "/" .. table.concat(tstops, "|"))
					elseif mc == "UIAspectRatioConstraint" then
						table.insert(mods, "aspect=" .. num(mp.AspectRatio or 1))
					elseif mc == "UIScale" then table.insert(mods, "scale=" .. num(mp.Scale or 1))
					elseif mc == "UIListLayout" then
						table.insert(mods, "list=" .. (mp.FillDirection and mp.FillDirection.Name or "Vertical") .. "," .. num(mp.Padding and mp.Padding.Offset or 0) .. "," ..
							(mp.HorizontalAlignment and mp.HorizontalAlignment.Name or "Left") .. "," .. (mp.VerticalAlignment and mp.VerticalAlignment.Name or "Top"))
					elseif mc == "UIGridLayout" then
						table.insert(mods, "grid=" .. udim2(mp.CellSize) .. "," .. udim2(mp.CellPadding) .. "," .. (mp.HorizontalAlignment and mp.HorizontalAlignment.Name or "Left"))
					elseif mc == "UIPadding" then
						table.insert(mods, "pad=" .. num(mp.PaddingLeft.Offset) .. "," .. num(mp.PaddingRight.Offset) .. "," .. num(mp.PaddingTop.Offset) .. "," .. num(mp.PaddingBottom.Offset))
					end
				end
				if (cls == "ImageLabel" or cls == "ImageButton") and pr.Image and pr.Image ~= "" then
					local off = pr.ImageRectOffset or Vector2.new(0, 0)
					local sz = pr.ImageRectSize or Vector2.new(0, 0)
					local tile = pr.TileSize
					table.insert(mods, "img=" .. tostring(pr.Image) .. "|" .. num(off.X) .. "," .. num(off.Y) .. "," .. num(sz.X) .. "," .. num(sz.Y) .. "|" ..
						col(pr.ImageColor3 or Color3.new(1, 1, 1)) .. "|" .. num(pr.ImageTransparency or 0) .. "|" ..
						((pr.ScaleType and pr.ScaleType.Name) or "Stretch") .. "|" .. (tile and (num(tile.X.Offset) .. "," .. num(tile.Y.Offset)) or "0,0"))
				end
				local text = pr.Text and tostring(pr.Text):gsub("[\t\n]", " ") or ""
				print(table.concat({ lineTag or "G", id, parentId, cls, pr.Name or "", tostring(pr.Visible ~= false and pr.Enabled ~= false),
					udim2(pr.Position), udim2(pr.Size), pr.AnchorPoint and (num(pr.AnchorPoint.X) .. "," .. num(pr.AnchorPoint.Y)) or "0,0",
					col(pr.BackgroundColor3), num(pr.BackgroundTransparency or 0), text, num(pr.TextSize or 14), tostring(pr.TextScaled == true),
					col(pr.TextColor3), num(pr.TextTransparency or 0), num(pr.ZIndex or 1), num(pr.LayoutOrder or 0), num(pr.Rotation or 0),
					(pr.AutomaticSize and pr.AutomaticSize.Name) or "None", tostring(pr.IgnoreGuiInset == true), num(pr.DisplayOrder or 0),
					(pr.TextXAlignment and pr.TextXAlignment.Name) or "Center", table.concat(mods, ";"), tostring(pr.ClipsDescendants == true),
					(pr.Font and pr.Font.Name) or "" }, "\t"))
				if cls == "ViewportFrame" then
					-- what the viewport shows: its camera, then its parts tagged vp<id>
					local cam = pr.CurrentCamera
					local cf = cam and cam.__props.CFrame
					if cf then
						print(table.concat({ "VP", id, num(cf[1]), num(cf[2]), num(cf[3]), num(-cf[6]), num(-cf[9]), num(-cf[12]),
							num(cam.__props.FieldOfView or 70) }, "\t"))
						ExportParts(child, "vp" .. id)
					end
				else
					walk(child, id)
				end
			else
				walk(child, parentId)
			end
		end
	end
	walk(root, 0)
end
function INST.BindToRenderStep() end
function INST.UnbindFromRenderStep() end
function INST.GetMouse(self) local m = newInstance("Mouse"); m.Hit = cf(0, 0, 0); return m end
function INST.IsKeyDown() return false end
function INST.GetFocusedTextBox() return nil end
function INST.PreloadAsync() end
function INST.SetCore() end
function INST.GetCore() return nil end
function INST.SetCoreGuiEnabled() end
function INST.PromptGamePassPurchase() end
function INST.PromptProductPurchase() end
function INST.GetTextSize() return Vector2.new(100, 20) end
function INST.GetLastInputType() return Enum.UserInputType.MouseButton1 end
function INST.GetGuiObjectsAtPosition() return {} end
function INST.ViewportPointToRay() return { Origin = v3(0, 0, 0), Direction = v3(0, 0, -1) } end
function INST.ScreenPointToRay() return { Origin = v3(0, 0, 0), Direction = v3(0, 0, -1) } end
function INST.WorldToViewportPoint() return v3(0, 0, 0), false end
function INST.WorldToScreenPoint() return v3(0, 0, 0), false end
function INST.GetChildrenCount(self) return #rawget(self, "__children") end
