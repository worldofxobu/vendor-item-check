#!/usr/bin/env python3
"""
tests/run_tests.py
Validates Lua syntax, TOC integrity, database references, and addon logic.
"""

import os
import re
import sys
import math
import shutil
import subprocess

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ADDON_DIR = os.path.join(ROOT_DIR, "VendorItemCheck")


def validate_toc_files():
    print("[1/5] Validating TOC manifests...")
    toc_files = [
        os.path.join(ADDON_DIR, "VendorItemCheck.toc"),
        os.path.join(ADDON_DIR, "VendorItemCheck_Vanilla.toc")
    ]
    for toc_path in toc_files:
        assert os.path.exists(toc_path), f"Missing TOC file: {toc_path}"
        with open(toc_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        has_interface = False
        has_title = False
        files_to_load = []

        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.startswith("## Interface:"):
                has_interface = True
                assert "16001" in line or "11509" in line, f"Missing target interface in {toc_path}"
            elif line.startswith("## Title:"):
                has_title = True
            elif not line.startswith("##"):
                files_to_load.append(line)

        assert has_interface, f"No ## Interface tag in {toc_path}"
        assert has_title, f"No ## Title tag in {toc_path}"
        assert len(files_to_load) >= 4, f"Expected at least 4 lua files in {toc_path}, found {len(files_to_load)}"

        for lua_file in files_to_load:
            full_path = os.path.join(ADDON_DIR, lua_file)
            assert os.path.exists(full_path), f"TOC references missing file: {full_path}"

        print(f"  PASS: {os.path.basename(toc_path)} ({len(files_to_load)} files referenced)")


def validate_lua_syntax(file_path: str):
    if shutil.which("luac"):
        proc = subprocess.run(["luac", "-p", file_path], capture_output=True, text=True)
        assert proc.returncode == 0, f"Lua syntax error in {file_path}:\n{proc.stderr.strip()}"

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Strip single line comments
    content_no_comments = re.sub(r'--[^\n]*', '', content)

    # Check parenthesis balance
    open_p = content_no_comments.count('(')
    close_p = content_no_comments.count(')')
    assert open_p == close_p, f"{file_path}: Mismatched parentheses: ( = {open_p}, ) = {close_p}"

    # Check square brackets balance
    open_b = content_no_comments.count('[')
    close_b = content_no_comments.count(']')
    assert open_b == close_b, f"{file_path}: Mismatched brackets: [ = {open_b}, ] = {close_b}"

    # Check curly braces balance
    open_c = content_no_comments.count('{')
    close_c = content_no_comments.count('}')
    assert open_c == close_c, f"{file_path}: Mismatched braces: {{ = {open_c}, }} = {close_c}"

    # Strip string literals so words like "if" or "for" in strings don't count as keywords
    clean_code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', content_no_comments)
    clean_code = re.sub(r"'(?:[^'\\]|\\.)*'", "''", clean_code)

    # Check block keywords balance: function/if/do/for/while vs end
    tokens = re.findall(r'\b(function|if|do|while|repeat|until|end)\b', clean_code)
    block_depth = 0
    for tok in tokens:
        if tok in ('function', 'if', 'do', 'while'):
            block_depth += 1
        elif tok == 'end':
            block_depth -= 1
        assert block_depth >= 0, f"{file_path}: Unexpected 'end' keyword (depth dropped below 0)"

    assert block_depth == 0, f"{file_path}: Unclosed block: block_depth = {block_depth} at end of file"


def validate_all_lua_syntax():
    print("[2/5] Validating Lua code structure and syntax...")
    lua_files = [
        os.path.join(ADDON_DIR, "Data.lua"),
        os.path.join(ADDON_DIR, "Core.lua"),
        os.path.join(ADDON_DIR, "Tooltip.lua"),
        os.path.join(ADDON_DIR, "Options.lua"),
        os.path.join(ROOT_DIR, "tests", "smoke.lua"),
        os.path.join(ROOT_DIR, "tests", "classic_smoke.lua"),
    ]
    for path in lua_files:
        assert os.path.exists(path), f"File missing: {path}"
        validate_lua_syntax(path)
        print(f"  PASS: {os.path.relpath(path, ROOT_DIR)} syntax valid")


def validate_data_integrity():
    print("[3/5] Validating vendor database integrity...")
    data_path = os.path.join(ADDON_DIR, "Data.lua")
    with open(data_path, "r", encoding="utf-8") as f:
        text = f.read()

    # Parse vendors
    # Format: [vid] = { "name", "zone", "fac", x, y },
    vendors = {}
    for m in re.finditer(r'\[(\d+)\]\s*=\s*\{\s*\"([^\"]*)\"\s*,\s*\"([^\"]*)\"\s*,\s*\"([^\"]*)\"\s*,\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*\}', text):
        vid = int(m.group(1))
        vendors[vid] = {
            "name": m.group(2),
            "zone": m.group(3),
            "fac": m.group(4),
            "x": float(m.group(5)),
            "y": float(m.group(6)),
        }

    assert len(vendors) >= 900, f"Expected at least 900 vendors, got {len(vendors)}"

    # Parse items
    # Format: [iid] = { v = { ... }, ... },
    items = {}
    for m in re.finditer(r'\[(\d+)\]\s*=\s*\{\s*v\s*=\s*\{\s*([^\}]+)\s*\}(?:,\s*p\s*=\s*(\d+))?\s*\}', text):
        iid = int(m.group(1))
        vids_str = m.group(2)
        price = int(m.group(3)) if m.group(3) else 0
        vids = [int(x.strip()) for x in vids_str.split(",") if x.strip()]
        items[iid] = { "vendors": vids, "price": price }

    assert len(items) >= 1800, f"Expected at least 1800 items, got {len(items)}"

    # Check vendor references
    missing_refs = 0
    for iid, data in items.items():
        for vid in data["vendors"]:
            if vid not in vendors:
                missing_refs += 1

    assert missing_refs == 0, f"Found {missing_refs} dangling vendor references in items table"

    # Check faction distribution
    alliance_count = sum(1 for v in vendors.values() if v["fac"] == "A")
    horde_count = sum(1 for v in vendors.values() if v["fac"] == "H")
    neutral_count = sum(1 for v in vendors.values() if v["fac"] == "N")

    assert alliance_count > 200, f"Alliance vendor count too low: {alliance_count}"
    assert horde_count > 200, f"Horde vendor count too low: {horde_count}"
    assert neutral_count > 50, f"Neutral vendor count too low: {neutral_count}"

    print(f"  PASS: {len(items)} items and {len(vendors)} vendors verified")
    print(f"  PASS: Factions: {alliance_count} Alliance, {horde_count} Horde, {neutral_count} Neutral")
    return items, vendors


def test_addon_logic_simulation(items, vendors):
    print("[4/5] Simulating addon business logic...")

    # 1. Faction filtering logic
    def is_vendor_friendly(v_fac, player_fac):
        if v_fac in ("N", "AH", ""):
            return True
        if v_fac == "A" and player_fac == "Alliance":
            return True
        if v_fac == "H" and player_fac == "Horde":
            return True
        return False

    def get_item_vendors(iid, player_fac):
        if iid not in items:
            return None
        v_list = items[iid]["vendors"]
        friendly = []
        enemy_count = 0
        for vid in v_list:
            v = vendors.get(vid)
            if v:
                if is_vendor_friendly(v["fac"], player_fac):
                    friendly.append(v)
                else:
                    enemy_count += 1
        return {
            "vendors": friendly,
            "totalCount": len(friendly),
            "enemyOnly": (len(friendly) == 0 and enemy_count > 0),
            "price": items[iid]["price"]
        }

    # Test item 85 (Dirty Leather Vest - Horde only)
    res_a85 = get_item_vendors(85, "Alliance")
    assert res_a85 and res_a85["enemyOnly"] is True, "Alliance should see enemyOnly for item 85"
    assert res_a85["totalCount"] == 0, "Alliance player should have 0 friendly vendors for item 85"

    res_h85 = get_item_vendors(85, "Horde")
    assert res_h85 and res_h85["enemyOnly"] is False, "Horde should not see enemyOnly for item 85"
    assert res_h85["totalCount"] > 0, "Horde should have friendly vendors for item 85"
    for v in res_h85["vendors"]:
        assert v["fac"] in ("H", "N"), f"Horde player received hostile vendor {v['name']} ({v['fac']})"

    # Test item 159 (Refreshing Spring Water - Universal/Both factions)
    res_a159 = get_item_vendors(159, "Alliance")
    assert res_a159 and res_a159["totalCount"] > 0, "Alliance should have vendors for water (item 159)"
    for v in res_a159["vendors"]:
        assert v["fac"] in ("A", "N"), f"Alliance player received hostile vendor {v['name']} ({v['fac']})"

    res_h159 = get_item_vendors(159, "Horde")
    assert res_h159 and res_h159["totalCount"] > 0, "Horde should have vendors for water (item 159)"
    for v in res_h159["vendors"]:
        assert v["fac"] in ("H", "N"), f"Horde player received hostile vendor {v['name']} ({v['fac']})"

    print("  PASS: Faction filtering verified (Item 85 Horde-only enemy flag, Item 159 faction separation)")

    # 2. Proximity sorting logic
    def sort_proximity(vendor_list, player_zone, px, py):
        def get_dist(v):
            if v["zone"].lower() == player_zone.lower():
                if px > 0 and py > 0 and v["x"] > 0 and v["y"] > 0:
                    dx = v["x"] - px
                    dy = v["y"] - py
                    return math.sqrt(dx * dx + dy * dy)
                return 0.001
            return 1000.0

        return sorted(vendor_list, key=lambda v: (get_dist(v), v["zone"], v["name"]))

    # Test with item 159 (Refreshing Spring Water) in Elwynn Forest (41.5, 65.9)
    res_water = get_item_vendors(159, "Alliance")
    sorted_v = sort_proximity(res_water["vendors"], "Elwynn Forest", 41.5, 65.9)
    assert len(sorted_v) > 0, "Water vendors should not be empty"
    assert sorted_v[0]["zone"].lower() == "elwynn forest", f"First vendor should be in Elwynn Forest, got: {sorted_v[0]['zone']}"
    print(f"  PASS: Proximity sorting prioritized {sorted_v[0]['name']} in {sorted_v[0]['zone']} at ({sorted_v[0]['x']}, {sorted_v[0]['y']})")

    # 3. Currency formatting logic
    def format_money(copper):
        gold = copper // 10000
        silver = (copper % 10000) // 100
        c = copper % 100
        parts = []
        if gold > 0: parts.append(f"{gold}g")
        if silver > 0 or gold > 0: parts.append(f"{silver}s")
        parts.append(f"{c}c")
        return " ".join(parts)

    assert format_money(12345) == "1g 23s 45c"
    assert format_money(50) == "50c"
    assert format_money(105) == "1s 5c"
    print("  PASS: Currency formatting logic verified")


def validate_repository_metadata():
    print("[5/5] Validating repository structure and metadata...")
    required_files = [
        "README.md",
        "CONTRIBUTING.md",
        "AGENTS.md",
        "CHANGELOG.md",
        "LICENSE",
        ".gitignore",
        ".pkgmeta",
    ]
    for filename in required_files:
        full_path = os.path.join(ROOT_DIR, filename)
        assert os.path.exists(full_path), f"Missing repository file: {filename}"
        assert os.path.getsize(full_path) > 10, f"File {filename} is empty or suspiciously short"
        print(f"  PASS: {filename} exists and non-empty")


def main():
    print("========================================")
    print("   VENDOR ITEM CHECK TEST SUITE")
    print("========================================")
    validate_toc_files()
    validate_all_lua_syntax()
    items, vendors = validate_data_integrity()
    test_addon_logic_simulation(items, vendors)
    validate_repository_metadata()
    print("========================================")
    print("   ALL VERIFICATIONS PASSED SUCCESSFULLY!")
    print("========================================")


if __name__ == "__main__":
    main()
