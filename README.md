# Football Stars

A Roblox football training game: **train your stats in six drills, watch your
player card go +1, climb from a 60 Bronze card to a 99 LEGEND, then start a
New Season and do it again with more XP.**

Everything is built from code when the server starts (the stadium plaza, the
training stations, the academies, the stadium). The place file only needs an
empty baseplate.

---

## Getting it into Studio

1. Build the place from the empty `Football_Stars.rbxlx` you saved out of
   Studio (or use the `Football Stars.rbxlx` that came with this change):

   ```sh
   python3 tools/build_place.py "Football_Stars.rbxlx" "Football Stars.rbxlx"
   ```

   It puts the 21 scripts in their services, removes the template
   SpawnLocation (the map has its own), and checks every script byte for byte.
2. Open `Football Stars.rbxlx` in Studio and press **Play**.
3. **Game Settings → Security → Enable Studio Access to API Services**, so
   saving and the global leaderboards work. Without it the game still runs,
   and says so ("Saving is off").
4. **Sounds**: upload `audio/Football_SFX.ogg` (Create → Audio), then
   paste its id in `ReplicatedStorage/FootballSounds.lua` (`Sounds.Sprite`).
   Until then the game uses Roblox's built-in sounds.
5. **Gamepasses and products**: create them on the Creator Dashboard and put
   their ids in `ReplicatedStorage/FootballConfig.lua` (`Config.Gamepasses`,
   `Config.Products`). With id `0` they are free in Studio (for testing) and
   "coming soon" in a live game.

## How to play

Walk to a station and press **E** (or tap the prompt) to start a drill.
Everything shows its controls on screen. On a phone, tap to aim and use the
big round button.

| Drill | Stat | What you do |
| --- | --- | --- |
| Speed Course | PAC | Sprint round the track through every gate; beat your best time |
| Shooting Practice | SHO | Aim at the targets in the goal, hold to power up, let go in the green. Top corners pay 1.5x, 5 goals in a row = ON FIRE (2x XP for 10 s) |
| Passing Drill | PAS | Pass to the dummy or ring that lights up; quick and accurate = more XP |
| Dribbling Cones | DRI | Weave round the cones with the ball; touching one costs time, a clean run is a PERFECT RUN |
| Tackle Zone | DEF | Tackle the attackers (F / click / TACKLE) before they reach your line; every wave is faster |
| Gym | PHY | Press when the marker is in the green (gold = perfect) |
| Stadium Match | all | Unlocks at 75 OVR: a 5-a-side match of big moments (pass, shoot, defend) |

Targets get smaller and faster as the stat grows, so higher levels stay a
challenge. All of it is decided on the server; the client only draws it.

## How it works

- **Stats** start at 60 and go to 99. Every +1 costs more XP than the last.
  Rough pace: 60 → 65 in 5-10 minutes, 65 → 75 in 1-2 hours, 75 → 85 over
  several sessions, 85 → 99 over days to weeks.
- **OVR** is a weighted mix of the six stats that depends on your position
  (a striker counts SHO most, a centre back DEF and PHY). The Position Board
  opens at 70 OVR: ST, W, CAM, CM, CB, GK.
- **Card tiers**: Bronze 60, Silver 65 (shine), Gold 75 (shimmer), Special 85
  (neon edge), Elite 90 (glow and sparks), World Class 95 (moving colours and
  lightning), LEGEND 99 (its own card, an aura round the player, and the whole
  server is told). The card design is our own.
- **The upgrade moment**: when OVR goes up the screen dims, your card flies to
  the middle, the number rolls up with a chime and a cheer, confetti bursts,
  and on a new tier the card flips over ("GOLD UNLOCKED!") before it flies
  back.
- **New Season** at 99: the stats go back to 60, and you keep +25% XP for
  every season forever, a season badge (S1, S2 ...) with its own colour on
  your card and the leaderboard, and your quests, styles and passes.
- **Areas**: the academies behind OVR gates (PRO 70, ELITE 80, LEGEND 90)
  have every drill with harder targets and better XP; the VIP lounge needs the
  VIP pass.
- **Hooks**: a 7-day daily reward (day 7 is the big one), a training streak
  (+5% XP per day in a row), quests that never run out, three leaderboards
  (Highest OVR, Most Seasons, Fastest Speed Course) and a small card over
  every player's head.

## Shop (fair)

| Item | Kind | Price |
| --- | --- | --- |
| 2x Training XP | gamepass | 199 |
| VIP Training | gamepass | 249 |
| Auto-Train (XP while standing in the lobby) | gamepass | 149 |
| Card Style Pack (borders, backgrounds, celebrations) | gamepass | 99 |
| 2x XP Boost, 15 min | product | 29 |
| +1 Stat Point (up to 84) | product | 15 |

LEGEND cards and seasons can never be bought.

## The screen

- your card bottom right (with your avatar), tap it for **My Card**
- menu buttons on the left: My Card, Daily, Quests, Positions, Season,
  Style, Shop, with badges when something is ready
- chips top left: your XP multiplier, the 2x boost timer, the streak
- while training: the XP bar bottom centre, +XP pops, the drill controls and a
  LEAVE button top right

Everything scales down on small screens. Rough preview pictures (drawn
without Studio, so flat colours and emoji as words) are in `images/`.

## Things you will want to change

All the numbers are in `game/ReplicatedStorage/FootballConfig.lua`: the XP
curve (`XPToNext`), position weights, tier thresholds, every drill's XP and
difficulty, the academies, daily rewards, quests, cosmetics and shop prices.

## The code

```
game/ReplicatedStorage      FootballConfig  all the numbers
                            FKit            the UI kit (buttons, panels, bars)
                            CardView        the player card
                            DrillMath       maths shared by server and client
                            FootballSounds  the sound sprite and fallbacks
game/ServerScriptService    Main            remotes, map, services, players
                            DataService     saving (retries, autosave 60 s)
                            StatService     XP, stats, OVR, tiers, seasons
                            TrainingService the six drills, server-checked
                            MatchService    the stadium match
                            RewardService   daily, quests, cosmetics
                            ShopService     gamepasses and products
                            LeaderboardService, MapBuilder, StationBuilder, MapKit
game/StarterPlayerScripts   ClientMain      starts the client
                            CardUI, UpgradeFX, TrainingClient, MenusUI
```

### Previews without Studio

The stand-in engine in `tools/preview` runs the real scripts and draws them
(needs Python 3 with numpy and pillow, and the Luau command line runner
`luau` from https://github.com/luau-lang/luau/releases; set `LUAU=/path/to/luau`
if it is not on your PATH):

```sh
cd tools/preview
python3 bundle.py server.luau /tmp/server.tsv SECONDS=30     # plays every drill, prints XP and stats
python3 bundle.py map.luau /tmp/map.tsv                      # the map
python3 render.py /tmp/map.tsv /tmp/top.png --top=0,0,700 --size 900x900
python3 bundle.py ui.luau /tmp/ui.tsv 'OPEN="Card"'          # the screen with a window open
python3 gui_render.py /tmp/ui.tsv /tmp/ui.png --size 1280x720
```

`ui.luau` also takes `UPGRADE="74,75" STEPS=9` (the upgrade moment),
`DRILL="Lobby_Shooting"`, `VIEW_W=844 VIEW_H=390 TOUCH=true` (a phone) and
more; see the top of the file.

### Sounds

`tools/audio/football_sfx.py` makes all 25 sounds from sine waves and noise
(needs numpy, scipy and ffmpeg) and packs them into `audio/Football_SFX.ogg`;
it also writes the regions that go in `FootballSounds.lua`.
