#!/usr/bin/env python3
"""Bundles the stand-in Roblox engine (mock.luau), the game's modules and a
driver into one Luau file, runs it and writes what it prints to a .tsv file.

usage: bundle.py driver.luau out.tsv [NAME=value ...]
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "..", "..", "game")
MOCK = os.path.join(HERE, "mock.luau")
LUAU = os.environ.get("LUAU", "luau")

MODULES = [
    "ReplicatedStorage/FootballConfig.lua",
    "ReplicatedStorage/StudTexture.lua",
    "ReplicatedStorage/PlayerFigure.lua",
    "ReplicatedStorage/FKit.lua",
    "ReplicatedStorage/CardView.lua",
    "ReplicatedStorage/FootballSounds.lua",
    "ServerScriptService/MapKit.lua",
    "ServerScriptService/RigService.lua",
    "ServerScriptService/StationBuilder.lua",
    "ServerScriptService/MapBuilder.lua",
    "ServerScriptService/DataService.lua",
    "ServerScriptService/StatService.lua",
    "ReplicatedStorage/DrillMath.lua",
    "ServerScriptService/TrainingService.lua",
    "ServerScriptService/MatchService.lua",
    "ServerScriptService/RewardService.lua",
    "ServerScriptService/ShopService.lua",
    "ServerScriptService/LeaderboardService.lua",
    "ServerScriptService/Main.server.lua",
    "StarterPlayerScripts/CardUI.lua",
    "StarterPlayerScripts/UpgradeFX.lua",
    "StarterPlayerScripts/TrainingClient.lua",
    "StarterPlayerScripts/MenusUI.lua",
    "StarterPlayerScripts/ClientMain.client.lua",
]


def main():
    driver, out = sys.argv[1], sys.argv[2]
    pre = "\n".join(sys.argv[3:])
    parts = [pre + "\n" + open(MOCK).read(), "\nMODULES = MODULES or {}\n"]
    for rel in MODULES:
        path = os.path.join(GAME, rel)
        if not os.path.exists(path):
            continue
        name = os.path.basename(rel).split(".")[0]
        parts.append("MODULES[%r] = function()\n%s\nend\n" % (name, open(path).read()))
    parts.append(open(driver).read())
    bundle = os.path.join(os.path.dirname(os.path.abspath(out)), "bundle_run.luau")
    open(bundle, "w").write("\n".join(parts))
    res = subprocess.run([LUAU, bundle], capture_output=True, text=True)
    with open(out, "w") as f:
        f.write(res.stdout)
    errors = [l for l in (res.stdout + res.stderr).splitlines() if "ERROR" in l or "error" in l.lower()]
    for l in errors[:20]:
        print(l)
    print("lines:", len(res.stdout.splitlines()))


if __name__ == "__main__":
    main()
