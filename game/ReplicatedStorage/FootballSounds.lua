-- Every sound in the game. All the effects live in one audio file (an
-- "audio sprite"): upload audio/Football_SFX.ogg, paste its id into
-- Sounds.Sprite below, and each effect plays its own slice of the file.
-- Until then the game uses Roblox's built-in sounds, so nothing breaks.

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- >>> PASTE THE AUDIO ID HERE <<< ("123" or "rbxassetid://123")
Sounds.Sprite = ""

local function asset(id)
	id = tostring(id or ""):gsub("%s", "")
	if id == "" then return "" end
	if id:match("^%d+$") then return "rbxassetid://" .. id end
	return id
end

-- Where each clip sits in the sprite: { start, length } in seconds. Made by
-- tools/audio/football_sfx.py.
Sounds.Regions = {
	beep = { 0.1, 0.2 }, buy = { 0.6, 1.138 }, cheer = { 2.038, 3.339 }, chime = { 5.677, 1.919 },
	clank = { 7.896, 0.45 }, click = { 8.646, 0.06 }, close = { 9.006, 0.22 }, cone = { 9.526, 0.25 },
	ding = { 10.076, 0.76 }, error = { 11.136, 0.31 }, fire = { 11.746, 1.598 }, go = { 13.645, 0.5 },
	groan = { 14.445, 1.939 }, kick = { 16.684, 0.3 }, legend = { 17.284, 3.815 }, miss = { 21.399, 0.4 },
	net = { 22.099, 0.923 }, open = { 23.321, 0.25 }, perfect = { 23.871, 1.202 }, pop = { 25.373, 0.08 },
	tackle = { 25.753, 0.4 }, tick = { 26.453, 0.05 }, tier = { 26.803, 2.417 }, whistle = { 29.52, 0.85 },
	whoosh = { 30.67, 0.4 },
}

local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUD = "rbxasset://sounds/action_get_up.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local WHOOSH = "rbxasset://sounds/action_swim.mp3"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local WIND = "rbxasset://sounds/action_falling.mp3"

-- name = { clip, volume, fallback id, fallback pitch }
Sounds.Defs = {
	Kick = { "kick", 0.8, THUD, 1.5 },
	Net = { "net", 0.7, SPLASH, 1.4 },
	Whistle = { "whistle", 0.6, PING, 2.2 },
	Cheer = { "cheer", 0.55, WIND, 0.7 },
	Groan = { "groan", 0.5, WIND, 0.5 },
	Chime = { "chime", 0.7, PING, 1.3 },
	Pop = { "pop", 0.6, PING, 1.7 },
	Ding = { "ding", 0.6, PING, 1.5 },
	Perfect = { "perfect", 0.7, PING, 1.9 },
	Clank = { "clank", 0.6, STEP, 0.8 },
	Beep = { "beep", 0.5, PING, 1.0 },
	Go = { "go", 0.7, PING, 1.6 },
	Cone = { "cone", 0.6, STEP, 1.8 },
	Tackle = { "tackle", 0.75, THUD, 1.0 },
	Miss = { "miss", 0.5, WHOOSH, 1.0 },
	Fire = { "fire", 0.7, WIND, 1.4 },
	Tier = { "tier", 0.8, PING, 1.2 },
	Legend = { "legend", 0.9, PING, 0.9 },
	Click = { "click", 0.45, PING, 1.3 },
	Open = { "open", 0.45, WHOOSH, 1.6 },
	Close = { "close", 0.4, WHOOSH, 1.2 },
	Error = { "error", 0.5, PING, 0.55 },
	Buy = { "buy", 0.7, PING, 1.45 },
	Tick = { "tick", 0.35, PING, 2.4 },
	Whoosh = { "whoosh", 0.45, WHOOSH, 1.3 },
}

Sounds.Enabled = true
Sounds.Volume = 1

local folder
local function home()
	if folder and folder.Parent then return folder end
	folder = Instance.new("Folder")
	folder.Name = "FootballSounds"
	folder.Parent = SoundService
	return folder
end

-- Plays a sound for this player only (client).
function Sounds.Play(name, volume, pitch)
	if not Sounds.Enabled then return end
	local def = Sounds.Defs[name]
	if not def then return end
	local s = Instance.new("Sound")
	local sprite = asset(Sounds.Sprite)
	local region = Sounds.Regions[def[1]]
	if sprite ~= "" and region then
		s.SoundId = sprite
		pcall(function()
			s.PlaybackRegionsEnabled = true
			s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
		end)
		s.PlaybackSpeed = pitch or 1
		s.Volume = def[2] * (volume or 1) * Sounds.Volume
		s.Parent = home()
		s:Play()
		task.delay(region[2] / (pitch or 1) + 0.3, function() s:Destroy() end)
	else
		s.SoundId = def[3]
		s.PlaybackSpeed = (pitch or 1) * def[4]
		s.Volume = def[2] * (volume or 1) * Sounds.Volume * 0.8
		s.Parent = home()
		s:Play()
		task.delay(3, function() s:Destroy() end)
	end
end

return Sounds
