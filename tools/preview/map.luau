-- The server's own folder, so script.Parent:WaitForChild finds the modules.
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")
-- Builds the map and exports every part (for render.py).
local MapBuilder = require("MapBuilder")
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
