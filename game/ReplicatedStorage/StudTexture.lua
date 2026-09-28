-- Puts Roblox's own Studs surface (a raised square on every stud) on every
-- face of every part the game builds, and on every part added later. It is
-- built into Roblox: no image, no id, no setting. Characters never get it:
-- anything inside a model with a Humanoid, and the crowd, the drill players
-- and the dummies (Config.Texture.SkipNames).
--
--   StudTexture.Watch(workspace.Map)   -- now and from now on

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))

local StudTexture = {}

local SURFACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

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

local function wants(part)
	local cfg = Config.Texture
	if not part:IsA("BasePart") or part:IsA("Terrain") then return false end
	if part.Transparency > cfg.MaxTransparency then return false end
	if part.Material == Enum.Material.Neon or part.Material == Enum.Material.Glass or part.Material == Enum.Material.ForceField then
		return false
	end
	local size = part.Size
	if math.max(size.X, size.Y, size.Z) < cfg.MinSize then return false end
	if part:GetAttribute("Studs") then return false end
	-- only plain parts have surfaces (not meshes or unions)
	if not (part:IsA("Part") or part:IsA("WedgePart") or part:IsA("CornerWedgePart") or part:IsA("TrussPart")) then return false end
	return not isCharacter(part)
end

-- The Pet Simulator look: smooth and a little brighter and more colourful.
local function petSim(part)
	part.Material = Enum.Material.SmoothPlastic
	for _, face in ipairs(SURFACES) do
		part[face] = Enum.SurfaceType.Smooth
	end
	local h, sat, v = part.Color:ToHSV()
	part.Color = Color3.fromHSV(h, math.min(1, sat * 1.22 + 0.05), math.min(1, v * 1.06 + 0.02))
end

function StudTexture.Apply(part)
	if not wants(part) then return end
	part:SetAttribute("Studs", true)
	if Config.Look == "PetSim" then
		petSim(part)
		return
	end
	-- Roblox only shows surfaces on Plastic (not SmoothPlastic, Grass, Wood ...)
	part.Material = Enum.Material.Plastic
	for _, face in ipairs(SURFACES) do
		part[face] = Enum.SurfaceType.Studs
	end
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
