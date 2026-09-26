-- The server's own folder, so script.Parent:WaitForChild finds the modules.
script = newInstance("Script")
script.Parent = game:GetService("ServerScriptService")
-- Builds the map and exports every part (for render.py).
local MapBuilder = require("MapBuilder")
local ok, records = pcall(MapBuilder.Build)
if not ok then print("BUILD ERROR", records) end
local n = 0
if ok then for _ in pairs(records) do n += 1 end end
print("STATIONS", n)
ExportParts(workspace, "map")
