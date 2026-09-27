-- The server's own folder, so script.Parent:WaitForChild finds the modules.
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")
-- Builds the map and exports every part (for render.py).
local MapBuilder = require("MapBuilder")
-- the preview cannot download clothes: colour the kit dummies like their kits
local KIT_COLORS = {
	[12671727804] = Color3.fromRGB(205, 30, 40), [13037685109] = Color3.fromRGB(130, 195, 240),
	[122350971207999] = Color3.fromRGB(242, 242, 245), [91285212995098] = Color3.fromRGB(250, 208, 40),
}
local PANTS_COLORS = {
	[13957328362] = Color3.fromRGB(20, 110, 60), [15864727387] = Color3.fromRGB(25, 25, 30),
	[17126960776] = Color3.fromRGB(28, 36, 90), [14483484956] = Color3.fromRGB(30, 80, 200),
}
-- and a block of hair in the right colour
local HAIR_COLORS = {
	["135555885443323"] = Color3.fromRGB(28, 22, 20), ["103592509359330"] = Color3.fromRGB(70, 46, 30),
	["126200440326529"] = Color3.fromRGB(20, 16, 14), ["111937344447115"] = Color3.fromRGB(200, 160, 90),
}
local makeRig = INST.CreateHumanoidModelFromDescription
INST.CreateHumanoidModelFromDescription = function(self, desc, ...)
	local rig = makeRig(self, desc, ...)
	local shirt = desc and KIT_COLORS[desc.Shirt]
	local pants = desc and PANTS_COLORS[desc.Pants]
	for _, p in ipairs(rig:GetChildren()) do
		if shirt and (p.Name:find("Torso") or p.Name:find("UpperArm")) then p.Color = shirt end
		if pants and (p.Name:find("UpperLeg") or p.Name:find("LowerLeg") or p.Name:find("Foot")) then p.Color = pants end
	end
	local hair = desc and HAIR_COLORS[desc.HairAccessory]
	local head = rig:FindFirstChild("Head")
	if hair and head then
		local h = Instance.new("Part")
		h.Name = "Hair"
		h.Size = Vector3.new(head.Size.X * 1.08, head.Size.Y * 0.38, head.Size.Z * 1.08)
		h.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.4, 0.05)
		h.Color = hair
		h.Parent = rig
	end
	return rig
end
-- the drill characters (the passing dummies wait for these)
require("RigService").Init()
-- the template's Baseplate (the game paints it grass)
local base = Instance.new("Part")
base.Name = "Baseplate"
base.Anchored = true
base.Size = Vector3.new(2048, 16, 2048)
base.CFrame = CFrame.new(0, -8, 0)
base.Parent = workspace
local ok, records = pcall(MapBuilder.Build)
if not ok then print("BUILD ERROR", records) end
local n = 0
if ok then for _ in pairs(records) do n += 1 end end
print("STATIONS", n)
if RunScheduler then RunScheduler(3) end
if TEXTURE then
	local StudTexture = require("StudTexture")
	StudTexture.ApplyAll(workspace)
end
ExportParts(workspace, "map")
