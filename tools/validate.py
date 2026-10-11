"""Static checks for the Defold project, run before handing a build over.

    python3 tools/validate.py

Checks:
  * every Lua file parses (with texlua or luac if one is installed) and avoids
    Lua 5.3-only syntax that LuaJIT rejects (// integer division, bitwise ops, goto)
  * block/brace balance in Lua and in Defold resource files
  * every quoted /path.ext in a resource file exists
  * require() targets exist
  * scripts only address game objects that are in main.collection
  * every sprite animation the game plays by name is in sprites.atlas:
    sprite defaults, minis for classes, monsters and NPCs, and every player pose
  * every factory prototype exists and every component the table spawns is declared
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = []


def rel(p):
    return os.path.relpath(p, ROOT)


def strip_lua(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", " ", src, flags=re.S)
    src = re.sub(r"\[(=*)\[.*?\]\1\]", '""', src, flags=re.S)
    src = re.sub(r"--[^\n]*", " ", src)
    src = re.sub(r'"(\\.|[^"\\\n])*"', '""', src)
    src = re.sub(r"'(\\.|[^'\\\n])*'", "''", src)
    return src


def check_balance(path, src):
    s = strip_lua(src)
    s = re.sub(r"\b(for|while)\b(.*?)\bdo\b", r"\1\2", s, flags=re.S)
    toks = re.findall(r"[A-Za-z_][A-Za-z0-9_]*|[(){}\[\]]", s)
    stack, pairs = [], {")": "(", "}": "{", "]": "["}
    for t in toks:
        if t in ("function", "if", "do", "repeat", "for", "while"):
            stack.append(t)
        elif t == "end":
            if not stack or stack[-1] in "({[":
                errors.append(f"{rel(path)}: unexpected 'end'")
                return
            stack.pop()
        elif t == "until":
            if not stack or stack[-1] != "repeat":
                errors.append(f"{rel(path)}: bad until")
                return
            stack.pop()
        elif t in "({[":
            stack.append(t)
        elif t in ")}]":
            if not stack or stack[-1] != pairs[t]:
                errors.append(f"{rel(path)}: unbalanced {t}")
                return
            stack.pop()
    if stack:
        errors.append(f"{rel(path)}: unclosed {stack[-5:]}")


def check_luajit_syntax(path, src):
    s = strip_lua(src)
    for pat, what in ((r"//", "integer division //"), (r"(?<![<>=~])~(?!=)", "bitwise ~"), (r"<<|>>", "bit shift"),
                      (r"\bgoto\b", "goto"), (r"&", "bitwise &")):
        if re.search(pat, s):
            errors.append(f"{rel(path)}: {what} is not LuaJIT-safe")


LUA_PARSER = shutil.which("luac") or shutil.which("texlua")


def parse_lua(path):
    if not LUA_PARSER:
        return
    if LUA_PARSER.endswith("luac"):
        cmd = [LUA_PARSER, "-p", path]
    else:
        code = f'local f, e = loadfile([[{path}]]); if not f then io.stderr:write(e) os.exit(1) end'
        fd, script = tempfile.mkstemp(suffix=".lua")
        with os.fdopen(fd, "w") as f:
            f.write(code)
        cmd = [LUA_PARSER, script]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if not LUA_PARSER.endswith("luac"):
        os.remove(script)
    if r.returncode != 0:
        errors.append(f"{rel(path)}: does not parse: {(r.stderr or r.stdout).strip()}")


RESOURCE_EXT = (".go", ".collection", ".model", ".sprite", ".material", ".atlas", ".gui", ".font", ".collisionobject",
                ".factory", ".render", ".input_binding", ".convexshape")
SKIP_DIRS = ("/tools", "/build", "/.internal", "/.git")

lua_files, resource_files = [], []
for dp, dn, fn in os.walk(ROOT):
    if any(s in dp.replace(ROOT, "") for s in SKIP_DIRS):
        continue
    for f in fn:
        p = os.path.join(dp, f)
        if f.endswith((".script", ".gui_script", ".render_script", ".lua")):
            lua_files.append(p)
        elif f.endswith(RESOURCE_EXT):
            resource_files.append(p)

for p in lua_files:
    src = open(p, encoding="utf-8").read()
    if LUA_PARSER:
        parse_lua(p)
    else:
        check_balance(p, src)
    check_luajit_syntax(p, src)
    for mod in re.findall(r'require\s*\(?\s*"([^"]+)"', src):
        if not os.path.exists(os.path.join(ROOT, mod.replace(".", "/") + ".lua")):
            errors.append(f"{rel(p)}: require of missing module {mod}")

for p in resource_files:
    s = open(p, encoding="utf-8").read()
    if s.count("{") != s.count("}"):
        errors.append(f"{rel(p)}: brace mismatch")
    for ref in re.findall(r'"(/[^"]+\.[a-z_]+)"', s):
        if ref.startswith("/builtins/"):
            continue
        if not os.path.exists(os.path.join(ROOT, ref.lstrip("/"))):
            errors.append(f"{rel(p)}: missing {ref}")

gp = open(os.path.join(ROOT, "game.project")).read()
for ref in re.findall(r"= (/\S+)c\n", gp):
    if not os.path.exists(os.path.join(ROOT, ref.lstrip("/"))):
        errors.append(f"game.project: missing {ref}")

# Game objects addressed from scripts must exist in the bootstrap collection.
col = open(os.path.join(ROOT, "main/main.collection")).read()
ids = set(re.findall(r'id: "([^"]+)"', col))
for p in lua_files:
    if not p.endswith((".script", ".gui_script")):
        continue
    s = open(p).read()
    for ref in re.findall(r'"/([a-z_]+)(?:#[a-z_]+)?"', s):
        if ref.endswith("_"):
            continue    # a prefix joined with a name at runtime, like "/terrain_" .. name
        if ref not in ids:
            errors.append(f"{rel(p)}: refers to /{ref} which is not in main.collection")

# Atlas animations.
atlas = open(os.path.join(ROOT, "assets/sprites/sprites.atlas")).read()
anims = set(re.findall(r'/assets/sprites/([A-Za-z0-9_]+)\.png', atlas))
for p in resource_files:
    if p.endswith(".sprite"):
        s = open(p).read()
        m = re.search(r'default_animation: "([^"]+)"', s)
        if m and "sprites.atlas" in s and m.group(1) not in anims:
            errors.append(f"{rel(p)}: default animation {m.group(1)} is not in sprites.atlas")


def lua_table_strings(path, name):
    src = open(os.path.join(ROOT, path)).read()
    m = re.search(name + r"\s*=\s*\{(.*?)\n\}", src, flags=re.S)
    if not m:
        errors.append(f"{path}: can't find {name}")
        return set()
    body = m.group(1)
    return set(re.findall(r'"([a-z0-9_]+)"', body)) | set(re.findall(r'\b([a-z0-9_]+) = true', body))


played = set()
nv = "game/ui/night_view.lua"
played |= lua_table_strings(nv, "local CLASS_SPRITE")
played |= lua_table_strings(nv, "local CAST_SPRITE")
played |= lua_table_strings(nv, "local MONSTER_SPRITES")
played |= {"goblin_spear", "goblin_club", "bandit", "npc_stranger"}
played |= set(re.findall(r'sprite = "([a-z0-9_]+)"', open(os.path.join(ROOT, "main/table/table.script")).read()))
scene_src = open(os.path.join(ROOT, "main/scene_data.lua")).read()
heads = re.findall(r"^\s+([a-z]+) = vmath\.vector3", scene_src.split("heads = {")[1].split("}")[0], flags=re.M)
poses_src = open(os.path.join(ROOT, "tools/gen_sprites.py")).read()
poses = re.findall(r'"([a-z]+)"', re.search(r"POSES = \[(.*?)\]", poses_src).group(1))
for who in heads:
    played.add(who)
    for pose in poses:
        if pose != "neutral":
            played.add(f"{who}_{pose}")
# Poses the night model asks for must be poses we drew.
night_src = open(os.path.join(ROOT, "game/model/night.lua")).read() + open(os.path.join(ROOT, "game/model/fight.lua")).read()
asked = set(re.findall(r'(?:pose|poses\[[^\]]+\])\s*=\s*"([a-z]+)"', night_src)) | set(re.findall(r'\] = "([a-z]+)"', night_src))
asked |= set(re.findall(r'pose = "([a-z]+)"', open(os.path.join(ROOT, nv)).read()))
for pose in asked:
    if pose not in poses:
        errors.append(f"pose {pose!r} is used by the night but not drawn (tools/gen_sprites.py POSES)")
for a in sorted(played):
    if a not in anims:
        errors.append(f"sprite animation {a} is played by name but not in sprites.atlas")

# Factories and what the table spawns.
for p in resource_files:
    if p.endswith(".factory"):
        m = re.search(r'prototype: "([^"]+)"', open(p).read())
        if not m or not os.path.exists(os.path.join(ROOT, m.group(1).lstrip("/"))):
            errors.append(f"{rel(p)}: bad prototype")
table_go = open(os.path.join(ROOT, "main/table/table.go")).read()
table_src = open(os.path.join(ROOT, "main/table/table.script")).read()
for comp in set(re.findall(r'factory\.create\("#([a-z_]+)"', table_src)):
    if f'id: "{comp}"' not in table_go:
        errors.append(f"main/table/table.script: spawns from #{comp}, which table.go doesn't have")
mini_go = open(os.path.join(ROOT, "main/minis/mini.go")).read()
for comp in ("sprite", "mini"):
    if f'id: "{comp}"' not in mini_go:
        errors.append(f"main/minis/mini.go: missing component {comp}")
base_go = open(os.path.join(ROOT, "main/minis/mini_base.go")).read()
for side in ("party", "foe", "npc"):
    if f'id: "{side}"' not in base_go:
        errors.append(f"main/minis/mini_base.go: missing component {side}")

# The board: placed in the collection, and a factory for every kind in the prop kit.
if 'id: "board"' not in col:
    errors.append("the board (main/board/board.go) is not placed in main.collection")
board_go = open(os.path.join(ROOT, "main/board/board.go")).read()
props_lua = open(os.path.join(ROOT, "game/data/props.lua")).read()
for name in re.findall(r"^    ([a-z_]+) = \{ fw", props_lua, flags=re.M):
    if f'id: "{name}"' not in board_go:
        errors.append(f"prop kind {name} has no factory on main/board/board.go")
    if not os.path.exists(os.path.join(ROOT, f"main/board/props/{name}.go")):
        errors.append(f"prop kind {name} has no prototype main/board/props/{name}.go")

# Dialogue data (M5): the JSON parses and ships inside the game.
import json
ddir = os.path.join(ROOT, "game", "data", "dialogue")
for name in ("triggers.json", "voices.json", "lines.json"):
    try:
        with open(os.path.join(ddir, name), encoding="utf-8") as f:
            json.load(f)
    except Exception as e:  # noqa: BLE001
        errors.append(f"game/data/dialogue/{name}: {e}")
m = re.search(r"custom_resources\s*=\s*(.*)", gp)
if not m or "/game/data/dialogue" not in m.group(1):
    errors.append("game.project: custom_resources must include /game/data/dialogue or the game ships without its lines")

print(f"checked {len(lua_files)} Lua files and {len(resource_files)} resources"
      + ("" if LUA_PARSER else " (no luac or texlua found: Lua only checked for balance)"))
print("\n".join(errors) if errors else "all checks passed")
sys.exit(1 if errors else 0)
