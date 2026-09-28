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

   It puts the 24 scripts in their services, removes the template
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
| Speed Boots (+20% walk speed outside drills) | gamepass | 79 |
| 2x XP Hour | product | 79 |
| +3 Stat Points (three lowest stats, up to 84) | product | 39 |
| Training Pack (a level of XP for every stat, up to 90) | product | 49 |
| Mega Pack (three levels of XP for every stat, up to 90) | product | 149 |
| Ronaldo, Messi, Bellingham, Neymar Jr (the star players by the fountain: wear the look, +10% XP in one stat) | gamepass each | 99 |

LEGEND cards and seasons can never be bought.

## The screen

- your card bottom right (with your avatar), tap it for **My Card**
- menu buttons on the left: My Card, Daily, Quests, Positions, Season,
  Style, Shop, with badges when something is ready
- chips top left: your XP multiplier, the 2x boost timer, the streak
- while training: the XP bar bottom centre, +XP pops, the drill controls and a
  big EXIT button top right (or **X** on a keyboard) that stops the drill and
  puts you back on its start pad

Every card (the corner card, My Card, the upgrade moment and the small card
over each player's head) shows that player's own Roblox avatar, head and
shoulders. A Studio test player with no avatar picture gets a copy of their
character instead.

Everything scales down on small screens. Rough preview pictures (drawn
without Studio, so flat colours and emoji as words) are in `images/`.

## The look

- **The texture**: every part the game builds has Roblox's own Studs
  surface on every face (a raised square on every stud, in the part's own
  colour). Roblox only shows surfaces on Plastic, so those parts are Plastic. It is built into Roblox, so it needs no image. Characters never
  get it: players, the crowd, the drill players and the dummies. Neither do
  glass, glows, nets and parts under 2 studs (`Config.Texture`).
- **The drill players** (the attackers you tackle, the keeper, your
  teammates in the stadium and the passing dummies) are real Roblox
  characters playing Roblox's own run and idle animations: your Roblox
  friends' avatars and the other players' in the server, otherwise default
  avatars in the team's colours. A glowing ring under their feet shows the
  side: red attackers, green keeper, blue teammates, yellow dummies
  (`PlayerFigure.lua`, `RigService.lua`, `Config.Figures`).
- **Light and sky**: bright, clear daylight with no haze, light bloom and soft
  shadows (`Config.Lighting`). The sky is "Obby Sky" from
  the Toolbox, loaded at start when Lighting has no Sky (`Config.Sky`).
- **Buttons** are stud style: a bright-to-light gradient, studs, a light
  inner edge, a dark outer edge and round corners (`FKit.button`,
  `FKit.studs`); panels get faint studs too.
- **Icons** on the buttons and windows are drawn, not emoji: the same
  things (card, gift, trophy, cart, bolt, ball ...) in fresh colours with a
  dark outline round each one (`Icons.lua`). With DevJoob's "Simulator Icon
  Pack" from the Toolbox in ReplicatedStorage, the icons use its pictures
  instead and Output lists its image ids to bake into `Icons.Images`.
  `assets/Icons_Sheet.png` holds 21 icons (check, cross, Robux coin, plus,
  refresh, basket, swap arrows, gift, colour wheel, gems, hand ...): upload it
  once and put its id in `Icons.Sprite.Image`; then the close and EXIT
  buttons, prices, Season, Shop, Position, Daily, Style, VIP and Auto-Train
  use those pictures.
- **Map**: small and walled in by blocky mountains (grass, rock, snow). The
  three academies sit side by side east of the plaza, the stadium west.
  Buildings have bases, corner pillars, windows, roof rims and canopies.
- **Lobby**: the plaza is a striped pitch with a giant football over a golden
  fountain, two small goals on the centre circle, corner flags, lamp posts
  and benches, and ad boards in front of the stands.
- **Star players**: Ronaldo, Messi, Bellingham and Neymar Jr stand round the
  fountain in real catalogue kits, hair and beard (`Config.Stars`), with a
  soft golden glow and sparkles drifting up. Their prompt is a rainbow
  button (tap it on a phone). Each is a
  gamepass: press E to buy, then E to wear the look on your own avatar (kept
  when you respawn and rejoin) or take it off. Owning one gives +10% XP in
  that player's best stat. Set each pass id in `Config.Gamepasses`
  (`Star_Ronaldo` ...); with id 0 they are free in Studio (`StarService.lua`).
- **Detail**: buildings have window frames, cornices, back windows, roof
  units and a front step; trees have leaf clumps and roots; paths have a
  darker edge; bushes and flower patches fill the grass.
- **Readable signs**: sign text sits on a plain background (the studs never
  show through the letters) and small signs fade out far away.
- **Trees**: blocky trees and pines, kept clear of every stand, pitch and path.
- **Smooth**: about a third fewer parts than before (start pads, plaza
  circles and passing hoops are a few big parts, a smaller crowd), no shadows
  from the floodlights, and flat pieces on top of each other are lifted a
  hair so they never flicker.
- **Moving UI**: little studded blocks tumble down behind every window and the
  XP packs, price buttons get a sweeping shine, pack icons breathe and the
  HOT / BEST VALUE tags wobble. All tweens, no per-frame code.

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
                            PlayerFigure    the characters in the drills
                            StudTexture     the Baseplate squares on everything
                            FootballSounds  the sound sprite and fallbacks
game/ServerScriptService    Main            remotes, map, services, players
                            DataService     saving (retries, autosave 60 s)
                            StatService     XP, stats, OVR, tiers, seasons
                            TrainingService the six drills, server-checked
                            MatchService    the stadium match
                            RewardService   daily, quests, cosmetics
                            ShopService     gamepasses and products
                            StarService     the star players: buy, wear, XP bonus
                            RigService      the real Roblox characters for the drills
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
