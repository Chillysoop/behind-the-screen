"""Quick look at the boards without the engine: renders each board (game/data/boards.lua, the
prop kit in tools/gen_props.py) from the table camera with a tiny painter's-algorithm renderer.
Flat-shaded, no textures beyond the palette: good enough to check a layout reads.

  python3 tools/preview_boards.py OUT_DIR [board ...]

Needs texlua (or lua) on the path to read the boards.
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import gen_props as gp  # noqa: E402

ROOT = gp.ROOT
X0, Z0, SQ = -56.0, -34.5, 5.0
W, H = 20, 13

DUMP = r'''
package.path = "./?.lua;" .. package.path
local board = require "game.model.board"
local boards = require "game.data.boards"
local ids = {}
for id in pairs(boards) do ids[#ids + 1] = id end
table.sort(ids)
local out = {}
for _, id in ipairs(ids) do
  local c = board.compile(id)
  local ps = {}
  for _, p in ipairs(c.pieces) do
    local w, h = board.size(p.kind, p.r)
    ps[#ps + 1] = string.format('{"kind":"%s","x":%d,"y":%d,"r":%d,"w":%d,"h":%d,"fid":"%s"}', p.kind, p.x, p.y, p.r, w, h, p.fid)
  end
  out[#out + 1] = string.format('"%s":{"title":"%s","party":[%d,%d],"foes":[%d,%d],"npc":[%d,%d],"pieces":[%s]}', id,
    (string.gsub(c.title, '"', "'")), c.party[1], c.party[2], c.foes[1], c.foes[2], c.npc[1], c.npc[2], table.concat(ps, ","))
end
print("{" .. table.concat(out, ",") .. "}")
'''


def load_boards():
    import tempfile
    lua = "texlua" if subprocess.call(["which", "texlua"], stdout=subprocess.DEVNULL) == 0 else "lua"
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as tf:
        tf.write(DUMP)
        name = tf.name
    try:
        res = subprocess.run([lua, name], capture_output=True, text=True, cwd=ROOT)
    finally:
        os.unlink(name)
    if res.returncode != 0:
        raise SystemExit("board dump failed: " + res.stderr + res.stdout)
    return json.loads(res.stdout)


UV_TO_KEY = {}
for k in gp._KEYS:
    u, v = gp.uv(k)
    UV_TO_KEY[(round(u, 4), round(v, 4))] = k


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


STONE_RGB = hexrgb("#8f8a82")
WOOD_RGB = hexrgb("#9a7550")

_mesh_cache = {}


def kind_tris(kind):
    if kind in _mesh_cache:
        return _mesh_cache[kind]
    P = gp.Parts()
    gp.KINDS[kind]["fn"](P, gp.rng_for(kind))
    tris = []
    for part, mesh in (("stone", P.stone), ("paint", P.paint), ("wood", P.wood)):
        for i in range(0, len(mesh.p), 3):
            a, b, c = mesh.p[i], mesh.p[i + 1], mesh.p[i + 2]
            if part == "paint":
                t = mesh.t[i]
                key = UV_TO_KEY.get((round(float(t[0]), 4), round(float(t[1]), 4)))
                col = hexrgb(gp.PALETTE[key]) if key else np.array((255, 0, 255), float)
            elif part == "stone":
                col = STONE_RGB
            else:
                col = WOOD_RGB
            tris.append((np.array(a), np.array(b), np.array(c), col))
    _mesh_cache[kind] = tris
    return tris


def look_at(eye, target):
    f = target - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, np.array((0, 1.0, 0)))
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def render(b, out_path, size=(1200, 760)):
    eye = np.array((-4.0, 84.85, 110.0))
    target = np.array((-4.0, -0.15, -6.0))
    r, u, f = look_at(eye, target)
    fov = math.radians(46)
    sw_, sh_ = size
    focal = (sh_ / 2) / math.tan(fov / 2)
    light = np.array((-0.4, 1.0, 0.5))
    light /= np.linalg.norm(light)

    def project(p):
        d = p - eye
        z = np.dot(d, f)
        return (sw_ / 2 + focal * np.dot(d, r) / z, sh_ / 2 - focal * np.dot(d, u) / z), z

    tris = []
    # the battle mat with its grid
    mat_col = hexrgb("#d8cfb8")
    for gy in range(H):
        for gx in range(W):
            x0, z0 = X0 + gx * SQ, Z0 + gy * SQ
            q = [np.array((x0, 0, z0)), np.array((x0 + SQ, 0, z0)), np.array((x0 + SQ, 0, z0 + SQ)), np.array((x0, 0, z0 + SQ))]
            c = mat_col * (0.97 if (gx + gy) % 2 else 1.0)
            tris.append((q[0], q[1], q[2], c, True))
            tris.append((q[0], q[2], q[3], c, True))
    for pc in b["pieces"]:
        cx = pc["x"] + (pc["w"] - 1) / 2
        cy = pc["y"] + (pc["h"] - 1) / 2
        wx, wz = X0 + SQ * (cx - 0.5), Z0 + SQ * (cy - 0.5)
        th = -pc["r"] * math.pi / 2
        R = gp.gm.rot_matrix(yaw=th)
        for (a, bb, c, col) in kind_tris(pc["kind"]):
            flat = max(a[1], bb[1], c[1]) < 0.3
            tris.append((R @ a + (wx, 0, wz), R @ bb + (wx, 0, wz), R @ c + (wx, 0, wz), col, flat))
    # minis: party (gold), foes (red), npc (blue) as little columns
    for key, col in (("party", "#c9a24c"), ("foes", "#8a3a32"), ("npc", "#5a7a8a")):
        gx, gy = b[key]
        m = gp.gm.cylinder((X0 + SQ * (gx - 0.5), 0, Z0 + SQ * (gy - 0.5)), 1.6, 1.4, 8.0, 8, gp.gm.swatch((0, 0)))
        for i in range(0, len(m.p), 3):
            tris.append((m.p[i], m.p[i + 1], m.p[i + 2], hexrgb(col), False))
    drawn = []
    for (a, bb, c, col, flat) in tris:
        (pa, za), (pb, zb), (pcc, zc) = project(a), project(bb), project(c)
        if min(za, zb, zc) <= 1:
            continue
        n = np.cross(bb - a, c - a)
        nl = np.linalg.norm(n)
        if nl < 1e-9:
            continue
        n /= nl
        # face the camera
        if np.dot(n, eye - a) < 0:
            n = -n
        shade = 0.55 + 0.45 * max(0.0, float(np.dot(n, light)))
        rgb = tuple(int(min(255, v * shade)) for v in col)
        if flat:
            depth = 2000 - max(a[1], bb[1], c[1]) * 1000 + (za + zb + zc) / 3 * 0.001
        else:
            depth = (za + zb + zc) / 3
        drawn.append((depth, [pa, pb, pcc], rgb))
    drawn.sort(key=lambda d: -d[0])
    img = Image.new("RGB", size, (40, 32, 28))
    dr = ImageDraw.Draw(img)
    for _, pts, rgb in drawn:
        dr.polygon([tuple(map(float, p)) for p in pts], fill=rgb)
    dr.text((12, 10), b["title"], fill=(240, 230, 210))
    img.save(out_path)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    boards = load_boards()
    names = sys.argv[2:] or sorted(boards)
    for n in names:
        render(boards[n], os.path.join(out, n + ".png"))
        print("wrote", n)


if __name__ == "__main__":
    main()
