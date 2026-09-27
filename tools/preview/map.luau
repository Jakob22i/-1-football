-- The server's own folder, so script.Parent:WaitForChild finds the modules.
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")
-- Builds the map and exports every part (for render.py).
local MapBuilder = require("MapBuilder")
-- the preview cannot download clothes: colour the kit dummies like their kits
local KIT_COLORS = {
	[14293294743] = Color3.fromRGB(200, 30, 40), [11451507627] = Color3.fromRGB(40, 60, 230),
	[14320687825] = Color3.fromRGB(50, 170, 60), [11659670285] = Color3.fromRGB(60, 150, 230),
}
local PANTS_COLORS = { [9468319359] = Color3.fromRGB(25, 25, 30), [13842975371] = Color3.fromRGB(240, 240, 240) }
local makeRig = INST.CreateHumanoidModelFromDescription
INST.CreateHumanoidModelFromDescription = function(self, desc, ...)
	local rig = makeRig(self, desc, ...)
	local shirt = desc and KIT_COLORS[desc.Shirt]
	local pants = desc and PANTS_COLORS[desc.Pants]
	for _, p in ipairs(rig:GetChildren()) do
		if shirt and (p.Name:find("Torso") or p.Name:find("UpperArm")) then p.Color = shirt end
		if pants and (p.Name:find("UpperLeg") or p.Name:find("LowerLeg") or p.Name:find("Foot")) then p.Color = pants end
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
