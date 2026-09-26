-- Puts the Baseplate squares (Config.Texture) on every face of every part
-- the game builds, and on every part added later. Characters never get it:
-- anything inside a model with a Humanoid, and the crowd, the drill players
-- and the dummies (Config.Texture.SkipNames).
--
--   StudTexture.Watch(workspace.Map)   -- now and from now on

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))

local StudTexture = {}

local TAG = "StudTexture"
local FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Bottom }

-- Is this part (or something it is inside) a character?
local function isCharacter(part)
	local skip = Config.Texture.SkipNames
	local node = part
	while node and node ~= workspace and node ~= game do
		if skip[node.Name] then return true end
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return true end
		node = node.Parent
	end
	return false
end

-- The image in the part's colour, brightened (Color3 above 1 brightens a
-- texture), so the squares look like the part itself.
local function tint(color)
	local k = Config.Texture.Brightness
	return Color3.new(color.R * k, color.G * k, color.B * k)
end

local function wants(part)
	local cfg = Config.Texture
	if not part:IsA("BasePart") or part:IsA("Terrain") then return false end
	if part.Transparency > cfg.MaxTransparency then return false end
	if part.Material == Enum.Material.Neon or part.Material == Enum.Material.Glass or part.Material == Enum.Material.ForceField then
		return false
	end
	local size = part.Size
	if math.max(size.X, size.Y, size.Z) < cfg.MinSize then return false end
	if part:FindFirstChild(TAG) then return false end
	return not isCharacter(part)
end

function StudTexture.Apply(part)
	if not wants(part) then return end
	local cfg = Config.Texture
	local textures = {}
	for _, face in ipairs(FACES) do
		local tex = Instance.new("Texture")
		tex.Name = TAG
		tex.Face = face
		tex.Texture = cfg.Id
		tex.Color3 = tint(part.Color)
		tex.Transparency = cfg.Transparency
		tex.StudsPerTileU = cfg.StudsPerTile
		tex.StudsPerTileV = cfg.StudsPerTile
		tex.Parent = part
		table.insert(textures, tex)
	end
	-- a part that changes colour (a gate opening) takes its squares along
	part:GetPropertyChangedSignal("Color"):Connect(function()
		for _, tex in ipairs(textures) do tex.Color3 = tint(part.Color) end
	end)
end

function StudTexture.ApplyAll(root)
	if root:IsA("BasePart") then StudTexture.Apply(root) end
	for _, d in ipairs(root:GetDescendants()) do
		StudTexture.Apply(d)
	end
end

-- Textures `root` now, and every part put in it later. A part is checked a
-- moment after it arrives, so its name, size and parent are set by then.
function StudTexture.Watch(root)
	StudTexture.ApplyAll(root)
	return root.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(function()
				if d.Parent then StudTexture.Apply(d) end
			end)
		end
	end)
end

return StudTexture
