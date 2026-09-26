-- Puts the Baseplate squares (Config.Texture) on every face of every part
-- the game builds, and on every part added later. Characters never get it:
-- anything inside a model with a Humanoid, and the crowd, the drill players
-- and the dummies (Config.Texture.SkipNames).
--
--   StudTexture.Watch(workspace.Map)   -- now and from now on

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))

local StudTexture = {}

-- The image the textures show. The server works it out once (Resolve) and
-- shares it in this attribute, so every client uses the same.
local ATTRIBUTE = "StudTextureImage"

local function image()
	return ReplicatedStorage:GetAttribute(ATTRIBUTE) or Config.Texture.Id
end

-- A Decal id put straight into a Texture stays blank: a Texture needs the
-- id of the image inside the Decal. InsertService opens the Decal and gives
-- that image (it works for Roblox's own assets and the game owner's). An
-- Image id cannot be opened that way and is used as it is.
function StudTexture.Resolve()
	local id = tonumber(tostring(Config.Texture.Id):match("%d+"))
	local resolved = Config.Texture.Id
	if id then
		local ok, model = pcall(function() return game:GetService("InsertService"):LoadAsset(id) end)
		if ok and model then
			local found = model:FindFirstChildWhichIsA("Decal", true) or model:FindFirstChildWhichIsA("Texture", true)
			if found and found.Texture ~= "" then resolved = found.Texture end
			model:Destroy()
		end
	end
	ReplicatedStorage:SetAttribute(ATTRIBUTE, resolved)
	print(("[Football] texture image: %s (from %s)"):format(resolved, tostring(Config.Texture.Id)))
	return resolved
end

-- On a client: says in Output whether the image really loaded.
function StudTexture.CheckLoaded()
	local probe = Instance.new("Texture")
	probe.Texture = image()
	task.spawn(function()
		local ok, err = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ probe }, function(content, status)
				if status == Enum.AssetFetchStatus.Success then
					print("[Football] texture image loaded: " .. content)
				else
					warn("[Football] texture image did NOT load (" .. tostring(status) .. "): " .. content
						.. " - put another Image or Decal id in Config.Texture.Id (FootballConfig)")
				end
			end)
		end)
		if not ok then warn("[Football] could not check the texture image:", err) end
	end)
end

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
		tex.Texture = image()
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
