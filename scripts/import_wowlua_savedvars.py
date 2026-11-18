"""Import a local WoW Forever SavedVariables snapshot into a private WoWLua profile."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
PROFILES = ROOT / "tests" / "profiles"
DEFAULT_SAVE = ROOT / "NTHEOTHER" / "SavedVariables" / "VendorItemCheck.lua"
LOCAL_PROFILE = PROFILES / "account-local.json"

# WoW writes Lua table literals. Load the snapshot with an empty environment,
# then encode only VendorItemCheckDB, preserving array indexes for item costs.
READ_SAVED_VARIABLES = r'''
local env = {}
assert(load(io.read("*a"), "SavedVariables", "t", env))()
assert(type(env.VendorItemCheckDB) == "table")

local function encode(value)
    local kind = type(value)
    if kind == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(byte)
            return string.format("\\u%04x", byte:byte())
        end) .. '"'
    elseif kind == "number" then
        assert(value == value and math.abs(value) < math.huge)
        return string.format("%.17g", value)
    elseif kind == "boolean" then
        return tostring(value)
    end

    assert(kind == "table" and getmetatable(value) == nil)
    local rows = {}
    local size = #value
    for key, item in pairs(value) do
        if size > 0 then
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= size)
            rows[key] = encode(item)
        else
            assert(type(key) == "string")
            rows[#rows + 1] = encode(key) .. ":" .. encode(item)
        end
    end
    if size > 0 then return "[" .. table.concat(rows, ",", 1, size) .. "]" end
    table.sort(rows)
    return "{" .. table.concat(rows, ",") .. "}"
end

io.write(encode(env.VendorItemCheckDB))
'''


def local_profile(db, character):
    observations = db.get("observations")
    characters = observations.get("characters", {}) if isinstance(observations, dict) else {}
    latest_offers = {}
    for guid, data in characters.items():
        offers = data.get("offers", {}) if isinstance(data, dict) else {}
        if not isinstance(offers, dict):
            continue
        dated = (offer for offer in offers.values()
                 if isinstance(offer, dict) and isinstance(offer.get("observedAt"), (int, float))
                 and offer["observedAt"] > 0)
        latest = max(dated, key=lambda offer: offer["observedAt"], default=None)
        if latest:
            latest_offers[guid] = latest

    if character is not None and character not in characters:
        raise ValueError("The selected character has no entry in the SavedVariables snapshot.")
    if latest_offers and character is None:
        character = max(latest_offers, key=lambda guid: (latest_offers[guid]["observedAt"], guid))
    as_of = max((offer["observedAt"] for offer in latest_offers.values()), default=0) or int(time.time())

    fixture = json.loads((PROFILES / "account-replay.json").read_text(encoding="utf-8"))
    player = {"name": "MerchantTester", "race": "Human", "class": "MAGE", "level": 60}
    if character:
        player["guid"] = character
    latest = latest_offers.get(character, {})
    if latest.get("playerFaction") == "Horde":
        player.update({"race": "Orc", "class": "WARRIOR"})
    profile = {
        "character": player,
        "items": fixture["items"],
        "screen": fixture["screen"],
        "savedVariables": {
            "VendorItemCheckDB": db,
            "VendorItemCheckLocalReplay": {"asOf": as_of},
        },
    }
    location = latest.get("location")
    if isinstance(location, dict) and all(key in location for key in ("mapId", "zone", "x", "y")):
        profile["position"] = {
            "mapID": location["mapId"], "zone": location["zone"],
            "x": location["x"] / 100, "y": location["y"] / 100,
        }
    return profile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("save", nargs="?", type=Path, default=os.environ.get("VIC_SAVED_VARIABLES") or DEFAULT_SAVE)
    parser.add_argument("--character", default=os.environ.get("VIC_REPLAY_CHARACTER"), help="Saved character GUID")
    args = parser.parse_args()
    source = args.save.expanduser()
    if not source.is_absolute():
        source = ROOT / source
    if not source.is_file():
        parser.error("SavedVariables file is missing. Set VIC_SAVED_VARIABLES to the path to VendorItemCheck.lua.")
    lua = shutil.which("lua")
    if not lua:
        parser.error("Install Lua 5.2 or newer and make lua available on PATH.")
    try:
        result = subprocess.run(
            [lua, "-E", "-e", READ_SAVED_VARIABLES], input=source.read_bytes(),
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True, timeout=15,
        )
        db = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        parser.error("Could not read VendorItemCheckDB from the SavedVariables file.")

    try:
        profile = local_profile(db, args.character)
    except (AttributeError, KeyError, TypeError, ValueError):
        parser.error("The snapshot data or selected character could not be used for replay.")

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=PROFILES, prefix=".account-local-", suffix=".tmp", delete=False,
        ) as temporary:
            temp_path = Path(temporary.name)
            json.dump(profile, temporary, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
            temporary.write("\n")
        temp_path.replace(LOCAL_PROFILE)
    finally:
        if temp_path:
            temp_path.unlink(missing_ok=True)
    print("Prepared the local WoWLua SavedVariables profile.")


if __name__ == "__main__":
    main()
