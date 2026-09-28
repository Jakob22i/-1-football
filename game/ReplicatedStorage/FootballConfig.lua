-- Every tuning number of Football Stars in one place: the stats and their
-- XP curve, how OVR is worked out per position, the card tiers, every drill,
-- the gates, seasons, daily rewards, quests and the shop.
--
-- Shared by the server (which does all the maths) and the client (which
-- only shows it).

local Config = {}

Config.GameName = "FOOTBALL STARS"
Config.Tagline = "TRAIN TO 99"
Config.Version = "v24"

--------------------------------------------------------------------------------
-- Stats
--------------------------------------------------------------------------------

-- The six stats, in the order the card shows them.
Config.StatOrder = { "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }

Config.Stats = {
	PAC = { Name = "Pace", Drill = "Speed Course", Color = Color3.fromRGB(40, 220, 255), Icon = "\u{26A1}" },
	SHO = { Name = "Shooting", Drill = "Shooting Practice", Color = Color3.fromRGB(255, 72, 88), Icon = "\u{26BD}" },
	PAS = { Name = "Passing", Drill = "Passing Drill", Color = Color3.fromRGB(90, 230, 90), Icon = "\u{1F3AF}" },
	DRI = { Name = "Dribbling", Drill = "Dribbling Cones", Color = Color3.fromRGB(190, 110, 255), Icon = "\u{1F300}" },
	DEF = { Name = "Defending", Drill = "Tackle Zone", Color = Color3.fromRGB(70, 140, 255), Icon = "\u{1F6E1}" },
	PHY = { Name = "Physical", Drill = "Gym", Color = Color3.fromRGB(255, 160, 40), Icon = "\u{1F4AA}" },
}

Config.StartLevel = 60
Config.MaxLevel = 99

-- XP a stat needs to go from `level` to level + 1. Every +1 costs more than
-- the last: fast at first (the first few in a couple of minutes), then it
-- gets steeper after 65. With normal play (about 150 XP a minute once walking
-- and misses are counted) that is roughly:
--   OVR 60 -> 65   5 - 10 minutes
--   OVR 65 -> 75   1 - 2 hours
--   OVR 75 -> 85   several sessions
--   OVR 85 -> 99   days to weeks (seasons, passes and the academies help)
function Config.XPToNext(level)
	if level >= Config.MaxLevel then return math.huge end
	local steps = level - Config.StartLevel
	local cost = 45 * 1.13 ^ steps * 1.06 ^ math.max(0, level - 65)
	return math.floor(cost + 0.5)
end

-- XP from drills grows a little with the stat, so higher levels do not feel
-- like standing still: +3% per level above 60.
function Config.LevelBonus(level)
	return 1 + 0.03 * math.max(0, level - Config.StartLevel)
end

--------------------------------------------------------------------------------
-- Positions and OVR
--------------------------------------------------------------------------------

Config.PositionOrder = { "ST", "W", "CAM", "CM", "CB", "GK" }

-- How much each stat counts toward OVR in each position (each adds up to 1).
Config.Positions = {
	ST = { Name = "Striker", Weights = { PAC = 0.20, SHO = 0.30, PAS = 0.10, DRI = 0.20, DEF = 0.05, PHY = 0.15 } },
	W = { Name = "Winger", Weights = { PAC = 0.30, SHO = 0.15, PAS = 0.15, DRI = 0.25, DEF = 0.05, PHY = 0.10 } },
	CAM = { Name = "Attacking Mid", Weights = { PAC = 0.10, SHO = 0.20, PAS = 0.30, DRI = 0.25, DEF = 0.05, PHY = 0.10 } },
	CM = { Name = "Central Mid", Weights = { PAC = 0.10, SHO = 0.10, PAS = 0.30, DRI = 0.15, DEF = 0.15, PHY = 0.20 } },
	CB = { Name = "Centre Back", Weights = { PAC = 0.10, SHO = 0.05, PAS = 0.10, DRI = 0.05, DEF = 0.40, PHY = 0.30 } },
	GK = { Name = "Goalkeeper", Weights = { PAC = 0.05, SHO = 0.00, PAS = 0.15, DRI = 0.00, DEF = 0.45, PHY = 0.35 } },
}
Config.StartPosition = "ST"
Config.PositionsUnlockOVR = 70

-- OVR from the stats for a position. 99 needs every counted stat at 99.
function Config.OVR(stats, position)
	local weights = (Config.Positions[position] or Config.Positions.ST).Weights
	local total = 0
	for stat, weight in pairs(weights) do
		total += weight * (stats[stat] or Config.StartLevel)
	end
	return math.clamp(math.floor(total + 0.0001), Config.StartLevel, Config.MaxLevel)
end

--------------------------------------------------------------------------------
-- Card tiers
--------------------------------------------------------------------------------

Config.TierOrder = { "Bronze", "Silver", "Gold", "Special", "Elite", "WorldClass", "Legend" }

Config.Tiers = {
	Bronze = { Min = 60, Label = "BRONZE" },
	Silver = { Min = 65, Label = "SILVER" },
	Gold = { Min = 75, Label = "GOLD" },
	Special = { Min = 85, Label = "SPECIAL" },
	Elite = { Min = 90, Label = "ELITE" },
	WorldClass = { Min = 95, Label = "WORLD CLASS" },
	Legend = { Min = 99, Label = "LEGEND" },
}

function Config.TierFor(ovr)
	local found = "Bronze"
	for _, name in ipairs(Config.TierOrder) do
		if ovr >= Config.Tiers[name].Min then found = name end
	end
	return found
end

function Config.TierIndex(name)
	for i, tier in ipairs(Config.TierOrder) do
		if tier == name then return i end
	end
	return 1
end

--------------------------------------------------------------------------------
-- Seasons (rebirth)
--------------------------------------------------------------------------------

-- At 99 OVR you can start a New Season: the card goes back to 60, you keep
-- +25% XP for every season forever, and the card gets a season badge.
Config.Season = {
	NeedOVR = 99,
	BonusPer = 0.25,
	-- the border colour for each season (it cycles after the last one)
	Colors = {
		Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 220, 255), Color3.fromRGB(255, 90, 200),
		Color3.fromRGB(120, 255, 90), Color3.fromRGB(255, 170, 30), Color3.fromRGB(170, 90, 255),
		Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 230, 60),
	},
}

function Config.SeasonColor(season)
	if season <= 0 then return nil end
	local list = Config.Season.Colors
	return list[(season - 1) % #list + 1]
end

--------------------------------------------------------------------------------
-- Walking speed: Pace makes you faster everywhere
--------------------------------------------------------------------------------

-- The light (from the "lighting settings for new devs" video): soft, warm
-- and a little purple, with atmosphere, colour correction and sun rays.
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- The look of the whole game:
--   "PetSim": smooth, glossy-bright surfaces in saturated colours, soft
--             bright light with bloom and a blue haze, bold outlined text
--             (the Pet Simulator style)
--   "Studs":  Roblox studs on everything and the purple video lighting
Config.Look = "PetSim"

Config.LightingPresets = {}
Config.LightingPresets.Studs = {
	Lighting = {
		Ambient = rgb(130, 130, 130),
		Brightness = 3,
		ColorShift_Bottom = rgb(0, 0, 0),
		ColorShift_Top = rgb(221, 213, 68),
		EnvironmentDiffuseScale = 0.807,
		EnvironmentSpecularScale = 0.303,
		GlobalShadows = true,
		OutdoorAmbient = rgb(206, 83, 204),
		ClockTime = 14.278,
		GeographicLatitude = 17.165,
	},
	-- newer settings (skipped where Roblox does not have them)
	-- PrioritizeLightingQuality off: the same look, smoother on weak devices
	Newer = { LightingStyle = "Soft", PrioritizeLightingQuality = false },
	Atmosphere = { Density = 0.269, Offset = 0, Color = rgb(201, 162, 255), Decay = rgb(119, 97, 141), Glare = 0.1, Haze = 0.2 },
	ColorCorrection = { Brightness = 0.1, Contrast = 0.5, Saturation = 0.5, TintColor = rgb(221, 210, 255) },
	SunRays = { Intensity = 0.25, Spread = 0.2 },
}
-- Bright and clear: no haze (far things keep their colours), light bloom
-- only on the brightest spots, soft shadows that stay light enough to see in.
Config.LightingPresets.PetSim = {
	Lighting = {
		Ambient = rgb(140, 140, 150),
		Brightness = 2.4,
		ColorShift_Bottom = rgb(0, 0, 0),
		ColorShift_Top = rgb(255, 248, 232),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 0.5,
		GlobalShadows = true,
		OutdoorAmbient = rgb(160, 160, 172),
		ShadowSoftness = 0.25,
		ExposureCompensation = 0,
		ClockTime = 14,
		GeographicLatitude = 20,
	},
	Newer = { LightingStyle = "Soft", PrioritizeLightingQuality = false },
	Atmosphere = { Density = 0.18, Offset = 0, Color = rgb(214, 232, 255), Decay = rgb(150, 190, 240), Glare = 0, Haze = 0 },
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.28, TintColor = rgb(255, 252, 255) },
	SunRays = { Intensity = 0.02, Spread = 0.4 },
	Bloom = { Intensity = 0.25, Size = 16, Threshold = 2 },
}
Config.Lighting = Config.LightingPresets[Config.Look] or Config.LightingPresets.Studs

-- The sky ("Obby Sky", or "Anime Sky"): the six image ids from the Sky's
-- properties (SkyboxBk, SkyboxDn, SkyboxFt, SkyboxLf, SkyboxRt, SkyboxUp).
-- Empty = the game leaves Lighting alone (a Sky you put there yourself stays).
Config.Sky = {
	-- "Obby Sky" by SaturunSnow in the Toolbox: loaded when the game starts
	-- if Lighting has no Sky yet (a Sky you put in Lighting yourself wins)
	AssetId = 127719608807122,
	Bk = "", Dn = "", Ft = "", Lf = "", Rt = "", Up = "",
	SunVisible = true,
}

-- The texture on everything except the characters: Roblox's own Studs
-- surface, a raised square on every stud, in each part's own colour
-- (StudTexture).
Config.Texture = {
	-- parts smaller than this (studs, biggest side) stay plain: a bolt or a
	-- seat is too small to show a square
	MinSize = 2,
	-- see-through parts (glass, nets, glows) stay plain
	MaxTransparency = 0.25,
	-- people, not things: the crowd, the drill players, the dummies
	SkipNames = { Fan = true, Figure = true, Dummy = true, Keeper = true, Football = true, KitDummy = true, StarPlayer = true },
}

-- The four star players round the lobby fountain (look-alikes with made-up
-- names: Ranaldo, Massi, Ballingham, Naymar Jr), dressed in real kits,
-- hair and beards from the Roblox catalogue. Each is a gamepass (Stars.Pass
-- in Config.Gamepasses): walk up and buy it, then wear the look whenever
-- you like, and get more XP in that player's best stat for good.
Config.Stars = {
	Ronaldo = {
		Name = "RANALDO", Number = 7, Stat = "SHO", Bonus = 0.1, Pass = "Star_Ronaldo",
		Shirt = 12671727804, Pants = 13957328362,    -- red and green, #7
		Hair = { 135555885443323 }, Skin = Color3.fromRGB(214, 160, 118),
	},
	Messi = {
		Name = "MASSI", Number = 10, Stat = "DRI", Bonus = 0.1, Pass = "Star_Messi",
		Shirt = 13037685109, Pants = 15864727387,    -- sky blue and white stripes, #10
		Hair = { 103592509359330 }, Face = { 119423740610031 }, Skin = Color3.fromRGB(234, 190, 152),
	},
	Bellingham = {
		Name = "BALLINGHAM", Number = 10, Stat = "PAS", Bonus = 0.1, Pass = "Star_Bellingham",
		Shirt = 122350971207999, Pants = 17126960776, -- white and navy, #10
		Hair = { 126200440326529 }, Skin = Color3.fromRGB(124, 82, 56),
	},
	Neymar = {
		Name = "NAYMAR JR", Number = 10, Stat = "PAC", Bonus = 0.1, Pass = "Star_Neymar",
		Shirt = 91285212995098, Pants = 14483484956,  -- yellow and blue, #10
		Hair = { 111937344447115 }, Skin = Color3.fromRGB(196, 140, 98),
	},
}
Config.StarOrder = { "Ronaldo", "Messi", "Bellingham", "Neymar" }

-- The people in the drills are real Roblox characters (PlayerFigure,
-- RigService): your friends' avatars and the other players' in the server,
-- otherwise default avatars in the team's colours.
Config.Figures = {
	FriendsPerPlayer = 8,                -- friends' avatars made for each player
	KitRigs = { Attacker = 3, Keeper = 2, Teammate = 3, Dummy = 5 }, -- default avatars per kit
	RunAnimation = "rbxassetid://913376220",  -- Roblox's own R15 run
	IdleAnimation = "rbxassetid://507766666", -- Roblox's own R15 idle
}

Config.Speed = {
	Base = 16,
	PerPace = 0.22,   -- +0.22 walk speed per Pace level above 60 (99 -> about 24.6)
	Dribble = 14,     -- with the ball at your feet (plus Dribbling)
	PerDribble = 0.2,
	JumpPower = 50,
}

function Config.WalkSpeed(pace)
	return Config.Speed.Base + Config.Speed.PerPace * math.max(0, pace - Config.StartLevel)
end

-- On the Speed Course you run by yourself, and much faster the more Pace
-- you have (60 -> 20, 80 -> 29, 99 -> about 37.5).
Config.Speed.Track = 20
Config.Speed.TrackPerPace = 0.45
function Config.TrackSpeed(pace)
	return Config.Speed.Track + Config.Speed.TrackPerPace * math.max(0, pace - Config.StartLevel)
end

function Config.DribbleSpeed(dribbling)
	return Config.Speed.Dribble + Config.Speed.PerDribble * math.max(0, dribbling - Config.StartLevel)
end

--------------------------------------------------------------------------------
-- Drills
--------------------------------------------------------------------------------
-- Base XP is for a stat at 60 in the lobby's stations; it grows with the
-- stat (Config.LevelBonus) and the station's multiplier (the academies).

Config.Drills = {
	Speed = {
		Stat = "PAC",
		Title = "SPEED COURSE",
		Line = "You run it by yourself: more Pace, faster laps!",
		Auto = true,        -- the course runs itself, lap after lap (AFK friendly)
		XPPerSecond = 5,    -- XP every second you run (x your track speed / 20)
		BaseXP = 80,        -- for a run at par time
		MaxFactor = 1.7,    -- the most a very fast run multiplies it by
		Countdown = 3,
		Timeout = 90,
		Slack = 1.12,       -- a run can not be faster than distance / (speed * slack)
	},
	Shooting = {
		Stat = "SHO",
		Title = "SHOOTING PRACTICE",
		Line = "Aim, hold to power up, release in the green. Hit the targets!",
		HitXP = 10,
		OnTargetXP = 2,     -- on target but not on a circle
		TopCornerBonus = 1.5,
		StreakForFire = 5,  -- hits in a row for ON FIRE
		FireSeconds = 10,
		FireMultiplier = 2,
		ShotCooldown = 1.2,
		FlightTime = 0.38,
		IdleEnd = 40,       -- no shot for this long ends the session
		-- target size (radius in studs) and movement from SHO 60 to 99
		RadiusEasy = 2.3, RadiusHard = 1.2,
		MoveEasy = 0, MoveHard = 5.5,
		SpeedEasy = 0.5, SpeedHard = 1.7,
		-- accuracy: how far a shot can drift (studs) from SHO 60 to 99
		SpreadEasy = 2.8, SpreadHard = 1.0,
		GreenFrom = 0.68, GreenTo = 0.86, -- the power sweet spot
		TopCornerChance = 0.35,
		TopCornerLife = 7,
	},
	Passing = {
		Stat = "PAS",
		Title = "PASSING DRILL",
		Line = "Pass to the target that lights up. Quick and accurate = more XP!",
		PassXP = 8,
		RingBonus = 1.4,
		MaxDistance = 62,       -- full power reaches this far
		PassCooldown = 0.55,
		TargetLife = 6,         -- a lit target waits this long
		NextDelay = 0.45,
		IdleEnd = 40,
		QuickTime = 1.4,        -- faster than this: x1.3
		SlowTime = 3,           -- slower than this: x0.75
		LateralEasy = 1.5, LateralHard = 0.45,  -- random side error at 30 studs
		LengthEasy = 3.6, LengthHard = 1.2,     -- random length error
		DummyWidth = 2.4, DummyDepth = 4.5,     -- how close counts, per target type
		RingWidth = 1.5, RingDepth = 3.2,
		RingChance = 0.3,
	},
	Dribbling = {
		Stat = "DRI",
		Title = "DRIBBLING CONES",
		Line = "Weave left and right round every cone. Don't touch them!",
		BaseXP = 55,
		MaxFactor = 1.7,
		PerfectBonus = 1.5,
		TouchPenalty = 1,     -- seconds per cone touched
		MissPenalty = 2,      -- seconds per cone passed on the wrong side
		ConeRadius = 1.3,     -- touching distance
		Countdown = 3,
		Timeout = 60,
		Slack = 1.15,
	},
	Defending = {
		Stat = "DEF",
		Title = "TACKLE ZONE",
		Line = "Stop the attackers before they reach your goal line!",
		StopXP = 9,
		WaveBonus = 4,        -- x the wave number, for clearing a wave without a goal
		Lives = 3,
		Reach = 5,            -- tackle distance (+ a bit with DEF)
		ReachPerLevel = 0.03,
		TackleCooldown = 0.55,
		SpeedStart = 8.5, SpeedPerWave = 0.9, SpeedMax = 23,
		ZigZag = 4,
		WaveGap = 3,
	},
	Gym = {
		Stat = "PHY",
		Title = "GYM",
		Line = "Click to lift! XP every few lifts. Resting? It lifts by itself.",
		LiftCooldown = 0.35,  -- the fastest you can lift by clicking
		LiftsPerXP = 3,       -- XP comes every this many lifts
		XPPerLift = 4,        -- so a set of 3 gives 12 XP (more with PHY and boosts)
		AutoEvery = 1.6,      -- when you do not click, a lift by itself this often (AFK)
	},
	Match = {
		Stat = "ALL",
		Title = "STADIUM MATCH",
		Line = "5-a-side. Score, pass and defend in the big moments!",
		NeedOVR = 75,
		WinXP = 70,           -- to every stat
		DrawXP = 35,
		LossXP = 18,
		MomentGap = 1.6,
	},
}

-- Where the drills are and how much better the XP is. Academy stations sit
-- behind gates that open at an OVR; the VIP lounge needs the VIP pass.
Config.Areas = {
	Lobby = { Title = "TRAINING GROUND", Mult = 1, Difficulty = 0 },
	VIP = { Title = "VIP TRAINING", Mult = 1.25, Difficulty = 0, VIP = true },
	Pro = { Title = "PRO ACADEMY", Mult = 1.25, Difficulty = 0.15, NeedOVR = 70, Color = Color3.fromRGB(60, 200, 255) },
	Elite = { Title = "ELITE ACADEMY", Mult = 1.6, Difficulty = 0.3, NeedOVR = 80, Color = Color3.fromRGB(200, 90, 255) },
	Legend = { Title = "LEGEND ACADEMY", Mult = 2, Difficulty = 0.45, NeedOVR = 90, Color = Color3.fromRGB(255, 200, 40) },
	Stadium = { Title = "STADIUM", Mult = 1, Difficulty = 0, NeedOVR = 75, Color = Color3.fromRGB(255, 90, 90) },
}

--------------------------------------------------------------------------------
-- Streaks, boosts and AFK
--------------------------------------------------------------------------------

-- Train on days in a row: +5% XP per day, up to +35%.
Config.TrainingStreak = { PerDay = 0.05, MaxDays = 8 }

function Config.StreakMultiplier(days)
	return 1 + Config.TrainingStreak.PerDay * math.clamp((days or 0) - 1, 0, Config.TrainingStreak.MaxDays - 1)
end

Config.Boost = { Multiplier = 2 }

-- Auto-Train pass: XP while standing in the lobby.
Config.AutoTrain = { Every = 15, XP = 14, Radius = 60 }

--------------------------------------------------------------------------------
-- Daily login reward
--------------------------------------------------------------------------------

Config.Daily = {
	Cooldown = 20 * 3600,
	Reset = 48 * 3600,
	Days = {
		{ Kind = "Boost", Minutes = 15, Name = "2x XP", Line = "15 minutes" },
		{ Kind = "XPAll", Amount = 60, Name = "XP PACK", Line = "every stat" },
		{ Kind = "Cosmetic", Item = "Border_Neon", Name = "NEON BORDER", Line = "for your card" },
		{ Kind = "Boost", Minutes = 30, Name = "2x XP", Line = "30 minutes" },
		{ Kind = "Cosmetic", Item = "Background_Sunset", Name = "SUNSET", Line = "card background" },
		{ Kind = "XPAll", Amount = 150, Name = "BIG XP PACK", Line = "every stat" },
		{ Kind = "Big", Minutes = 60, Amount = 250, Item = "Celebration_Fireworks", Name = "MEGA REWARD", Line = "fireworks + 1h 2x XP + XP" },
	},
}

--------------------------------------------------------------------------------
-- Quests: goals that never run out (a bigger one follows each)
--------------------------------------------------------------------------------

Config.Quests = {
	{ Id = "Goals", Counter = "Goals", Stat = "SHO", Text = "Score %s goals in Shooting Practice", Goals = { 10, 25, 50, 100, 250, 500, 1000 } },
	{ Id = "Corners", Counter = "TopCorners", Stat = "SHO", Text = "Hit %s top corner targets", Goals = { 3, 10, 25, 60, 150 } },
	{ Id = "Passes", Counter = "Passes", Stat = "PAS", Text = "Make %s accurate passes", Goals = { 15, 40, 100, 250, 600 } },
	{ Id = "Perfect", Counter = "PerfectRuns", Stat = "DRI", Text = "Do %s PERFECT RUNS in the cones", Goals = { 1, 3, 10, 25, 60 } },
	{ Id = "SpeedTime", Counter = "SpeedBest", Stat = "PAC", Lower = true, Text = "Finish the Speed Course under %ss", Goals = { 26, 24, 22, 20, 19, 18, 17, 16 } },
	{ Id = "Tackles", Counter = "Tackles", Stat = "DEF", Text = "Stop %s attackers", Goals = { 10, 30, 75, 200, 500 } },
	{ Id = "Reps", Counter = "PerfectReps", Stat = "PHY", Text = "Do %s sets of lifts in the gym", Goals = { 10, 30, 75, 200, 500 } },
	{ Id = "OVR", Counter = "BestOVR", Stat = "ALL", Text = "Reach %s OVR", Goals = { 65, 70, 75, 80, 85, 90, 95, 99 } },
	{ Id = "Matches", Counter = "MatchesWon", Stat = "ALL", Text = "Win %s Stadium Matches", Goals = { 1, 3, 10, 25, 60 } },
}

function Config.GetQuest(id)
	for _, quest in ipairs(Config.Quests) do
		if quest.Id == id then return quest end
	end
	return nil
end

-- A quest reward: XP worth about 1.5 levels of the stat (for "ALL", half a
-- level of every stat).
Config.QuestReward = { Levels = 1.5, AllLevels = 0.5 }

--------------------------------------------------------------------------------
-- Card cosmetics
--------------------------------------------------------------------------------

Config.Cosmetics = {
	Border_Classic = { Kind = "Border", Name = "Classic", Default = true },
	Border_Neon = { Kind = "Border", Name = "Neon", Colors = { Color3.fromRGB(0, 255, 230), Color3.fromRGB(0, 140, 255) } },
	Border_Fire = { Kind = "Border", Name = "Fire", Pack = true, Colors = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 60, 20) } },
	Border_Ice = { Kind = "Border", Name = "Ice", Pack = true, Colors = { Color3.fromRGB(230, 255, 255), Color3.fromRGB(90, 190, 255) } },
	Border_Galaxy = { Kind = "Border", Name = "Galaxy", Pack = true, Colors = { Color3.fromRGB(255, 90, 230), Color3.fromRGB(90, 60, 255) } },
	Background_Stadium = { Kind = "Background", Name = "Stadium", Default = true, Colors = { Color3.fromRGB(40, 80, 160), Color3.fromRGB(10, 20, 60) } },
	Background_Pitch = { Kind = "Background", Name = "Pitch", Default = true, Colors = { Color3.fromRGB(90, 210, 110), Color3.fromRGB(20, 110, 50) } },
	Background_Sunset = { Kind = "Background", Name = "Sunset", Colors = { Color3.fromRGB(255, 190, 90), Color3.fromRGB(230, 60, 120) } },
	Background_City = { Kind = "Background", Name = "City Lights", Pack = true, Colors = { Color3.fromRGB(120, 90, 255), Color3.fromRGB(20, 10, 60) } },
	Background_Space = { Kind = "Background", Name = "Space", Pack = true, Colors = { Color3.fromRGB(60, 30, 120), Color3.fromRGB(0, 0, 20) } },
	Celebration_Confetti = { Kind = "Celebration", Name = "Confetti", Default = true },
	Celebration_Fireworks = { Kind = "Celebration", Name = "Fireworks" },
	Celebration_Lightning = { Kind = "Celebration", Name = "Lightning", Pack = true },
	Celebration_Hearts = { Kind = "Celebration", Name = "Hearts", Pack = true },
}
Config.CosmeticKinds = { "Border", "Background", "Celebration" }

--------------------------------------------------------------------------------
-- Shop (fair: LEGEND and seasons can never be bought)
--------------------------------------------------------------------------------

-- Ids start at 0: "coming soon" in a live game, free in Studio so you can
-- test. Price is only what the button says; set the real price on the pass
-- or product itself.
Config.Gamepasses = {
	DoubleXP = { Id = 0, Price = 199, Name = "2x Training XP", Line = "Every drill gives double XP. Forever.", Short = "2x XP in every drill" },
	VIP = { Id = 0, Price = 249, Name = "VIP Training", Line = "The VIP lounge: better XP and a gold name.", Short = "VIP lounge + gold name" },
	AutoTrain = { Id = 0, Price = 149, Name = "Auto-Train", Line = "Earn XP while you stand in the lobby.", Short = "XP while you stand still" },
	Cosmetics = { Id = 0, Price = 99, Name = "Card Style Pack", Line = "Fire, Ice and Galaxy borders, 2 backgrounds, 2 celebrations.", Short = "New borders & effects" },
	SpeedBoots = { Id = 0, Price = 79, Name = "Speed Boots", Line = "Run 20% faster round the map (not in drills).", Short = "Run 20% faster", WalkBonus = 0.2 },
	-- the star players by the fountain (Config.Stars)
	Star_Ronaldo = { Id = 0, Price = 99, Name = "Ranaldo", Line = "Wear Ranaldo's look. +10% Shooting XP.", Short = "Ranaldo look + SHO XP" },
	Star_Messi = { Id = 0, Price = 99, Name = "Massi", Line = "Wear Massi's look. +10% Dribbling XP.", Short = "Massi look + DRI XP" },
	Star_Bellingham = { Id = 0, Price = 99, Name = "Ballingham", Line = "Wear Ballingham's look. +10% Passing XP.", Short = "Ballingham look + PAS XP" },
	Star_Neymar = { Id = 0, Price = 99, Name = "Naymar Jr", Line = "Wear Naymar's look. +10% Pace XP.", Short = "Naymar look + PAC XP" },
}
Config.PassOrder = { "DoubleXP", "VIP", "AutoTrain", "SpeedBoots", "Cosmetics" }

Config.Products = {
	Boost15 = { ProductId = 0, Price = 29, Name = "2x XP Boost", Line = "15 minutes. They add up.", Minutes = 15 },
	StatPoint = { ProductId = 0, Price = 15, Name = "+1 Stat Point", Line = "+1 to a stat of your choice (up to 84).", MaxLevel = 84 },
	Boost60 = { ProductId = 0, Price = 79, Name = "2x XP Hour", Line = "A full hour of 2x XP.", Short = "1 hour of 2x XP", Minutes = 60, Tag = "HOT" },
	StatPoint3 = { ProductId = 0, Price = 39, Name = "+3 Stat Points", Line = "+1 to your three lowest stats (up to 84).", Short = "+1 to 3 stats", Points = 3, MaxLevel = 84 },
	TrainingPack = { ProductId = 0, Price = 49, Name = "Training Pack", Line = "A level's worth of XP for every stat (up to 90).", Short = "XP for every stat", Levels = 1, MaxLevel = 90 },
	MegaPack = { ProductId = 0, Price = 149, Name = "Mega Pack", Line = "Three levels' worth of XP for every stat (up to 90).", Short = "3x XP for every stat", Levels = 3, MaxLevel = 90, Tag = "BEST VALUE" },
}
Config.ProductOrder = { "Boost15", "StatPoint", "Boost60", "StatPoint3", "TrainingPack", "MegaPack" }
-- the XP packs row in the shop
Config.PackOrder = { "Boost60", "StatPoint3", "TrainingPack", "MegaPack" }

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function Config.Short(n)
	n = tonumber(n) or 0
	local a = math.abs(n)
	if a >= 1e9 then return (string.format("%.1fB", n / 1e9):gsub("%.0B", "B")) end
	if a >= 1e6 then return (string.format("%.1fM", n / 1e6):gsub("%.0M", "M")) end
	if a >= 1e4 then return (string.format("%.1fK", n / 1e3):gsub("%.0K", "K")) end
	return tostring(math.floor(n + 0.5))
end

function Config.Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- 0 at a stat of 60, 1 at 99: how hard a drill gets.
function Config.Progress(level)
	return math.clamp((level - Config.StartLevel) / (Config.MaxLevel - Config.StartLevel), 0, 1)
end

function Config.Lerp(a, b, t)
	return a + (b - a) * t
end

return Config
