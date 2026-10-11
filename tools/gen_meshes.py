"""Tiny mesh toolkit and a dependency-free glTF 2.0 (.glb) writer.

Units are centimetres, Y is up, same as Defold and glTF. UVs follow glTF:
(0, 0) is the top-left of the image.
"""
import json
import math
import struct
import numpy as np


def v3(*a):
    return np.array(a if len(a) == 3 else a[0], dtype=float)


class Mesh:
    def __init__(self):
        self.p, self.n, self.t = [], [], []

    # every triangle is stored unshared; winding is fixed to face its normal
    def tri(self, ps, ns, ts):
        a, b, c = (np.asarray(x, float) for x in ps)
        fn = np.cross(b - a, c - a)
        if np.dot(fn, np.mean(np.asarray(ns, float), axis=0)) < 0:
            ps, ns, ts = [ps[0], ps[2], ps[1]], [ns[0], ns[2], ns[1]], [ts[0], ts[2], ts[1]]
        for i in range(3):
            self.p.append(np.asarray(ps[i], float))
            n = np.asarray(ns[i], float)
            self.n.append(n / (np.linalg.norm(n) + 1e-12))
            self.t.append(np.asarray(ts[i], float))

    def quad(self, ps, ns, ts):
        self.tri([ps[0], ps[1], ps[2]], [ns[0], ns[1], ns[2]], [ts[0], ts[1], ts[2]])
        self.tri([ps[0], ps[2], ps[3]], [ns[0], ns[2], ns[3]], [ts[0], ts[2], ts[3]])

    def add(self, other):
        self.p += other.p
        self.n += other.n
        self.t += other.t
        return self

    def transformed(self, yaw=0.0, pitch=0.0, roll=0.0, offset=(0, 0, 0), scale=1.0):
        R = rot_matrix(yaw, pitch, roll)
        m = Mesh()
        m.p = [R @ (np.asarray(p) * scale) + np.asarray(offset, float) for p in self.p]
        m.n = [R @ n for n in self.n]
        m.t = list(self.t)
        return m

    def bounds(self):
        P = np.array(self.p)
        return P.min(0), P.max(0)


def rot_matrix(yaw=0.0, pitch=0.0, roll=0.0):
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cr, sr = math.cos(roll), math.sin(roll)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    Rz = np.array([[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


# ------------------------------------------------------------------ UV mappers

def swatch(uv):
    return lambda p, n: uv


def triplanar(tile, offset=(0.0, 0.0)):
    """Planar UVs picked by the dominant normal axis; `tile` cm per texture repeat."""
    def f(p, n):
        ax = np.argmax(np.abs(n))
        if ax == 1:
            u, v = p[0], p[2]
        elif ax == 0:
            u, v = p[2], -p[1]
        else:
            u, v = p[0], -p[1]
        return (u / tile + offset[0], v / tile + offset[1])
    return f


def rect_uv(x0, z0, w, h):
    """Map an XZ rectangle exactly onto the 0..1 texture (for mats, rugs, sheets)."""
    return lambda p, n: ((p[0] - x0) / w, (p[2] - z0) / h)


# ------------------------------------------------------------------ primitives

def plane_xz(cx, y, cz, sx, sz, uvf, up=True):
    m = Mesh()
    ps = [(cx - sx / 2, y, cz - sz / 2), (cx + sx / 2, y, cz - sz / 2),
          (cx + sx / 2, y, cz + sz / 2), (cx - sx / 2, y, cz + sz / 2)]
    n = (0, 1, 0) if up else (0, -1, 0)
    m.quad(ps, [n] * 4, [uvf(np.array(p), np.array(n)) for p in ps])
    return m


def quad_uv(corners, normal, uvs):
    m = Mesh()
    m.quad(corners, [normal] * 4, uvs)
    return m


def box(c, size, uvf, skip=()):
    m = Mesh()
    cx, cy, cz = c
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    faces = {
        "+x": ((1, 0, 0), [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)]),
        "-x": ((-1, 0, 0), [(-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz), (-hx, -hy, -hz)]),
        "+y": ((0, 1, 0), [(-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz)]),
        "-y": ((0, -1, 0), [(-hx, -hy, hz), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz)]),
        "+z": ((0, 0, 1), [(hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz), (-hx, -hy, hz)]),
        "-z": ((0, 0, -1), [(-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz)]),
    }
    for key, (n, corners) in faces.items():
        if key in skip:
            continue
        ps = [np.array((cx + x, cy + y, cz + z)) for (x, y, z) in corners]
        m.quad(ps, [n] * 4, [uvf(p, np.array(n, float)) for p in ps])
    return m


def cylinder(c, r_bot, r_top, h, seg, uvf, caps=(True, True), smooth=True, inside=False, u_rep=1.0):
    """Vertical frustum from c (base centre) up by h. uvf=None gives cylindrical UVs."""
    m = Mesh()
    cx, cy, cz = c
    slope = (r_bot - r_top) / max(h, 1e-6)
    sgn = -1.0 if inside else 1.0
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        pts, nrm, uvs = [], [], []
        for (a, r, y, vv) in [(a0, r_bot, cy, 1.0), (a1, r_bot, cy, 1.0), (a1, r_top, cy + h, 0.0),
                              (a0, r_top, cy + h, 0.0)]:
            p = np.array((cx + math.cos(a) * r, y, cz + math.sin(a) * r))
            if smooth:
                n = np.array((math.cos(a), slope, math.sin(a))) * sgn
            else:
                am = (a0 + a1) / 2
                n = np.array((math.cos(am), slope, math.sin(am))) * sgn
            pts.append(p)
            nrm.append(n)
            uvs.append(uvf(p, n) if uvf else (a / (2 * math.pi) * u_rep, vv))
        m.quad(pts, nrm, uvs)
    for (on, y, r, n) in [(caps[0], cy, r_bot, (0, -1, 0)), (caps[1], cy + h, r_top, (0, 1, 0))]:
        if not on or r <= 0:
            continue
        ctr = np.array((cx, y, cz))
        for i in range(seg):
            a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
            p0 = np.array((cx + math.cos(a0) * r, y, cz + math.sin(a0) * r))
            p1 = np.array((cx + math.cos(a1) * r, y, cz + math.sin(a1) * r))
            nn = np.array(n, float)
            uv = (lambda p: uvf(p, nn)) if uvf else (lambda p: (0.5 + (p[0] - cx) / (2 * r), 0.5 + (p[2] - cz) / (2 * r)))
            m.tri([ctr, p0, p1], [nn] * 3, [uv(ctr), uv(p0), uv(p1)])
    return m


def sphere(c, r, seg, rings, uvf, squash=1.0):
    m = Mesh()
    c = np.array(c, float)
    for j in range(rings):
        t0, t1 = math.pi * j / rings, math.pi * (j + 1) / rings
        for i in range(seg):
            a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
            quad = []
            for (t, a) in [(t0, a0), (t1, a0), (t1, a1), (t0, a1)]:
                n = np.array((math.sin(t) * math.cos(a), math.cos(t), math.sin(t) * math.sin(a)))
                quad.append((c + n * r * np.array((1, squash, 1)), n))
            ps = [q[0] for q in quad]
            ns = [q[1] for q in quad]
            uvs = [uvf(p, n) for p, n in quad]
            if j == 0:
                m.tri([ps[0], ps[1], ps[2]], [ns[0], ns[1], ns[2]], [uvs[0], uvs[1], uvs[2]])
            elif j == rings - 1:
                m.tri([ps[0], ps[1], ps[3]], [ns[0], ns[1], ns[3]], [uvs[0], uvs[1], uvs[3]])
            else:
                m.quad(ps, ns, uvs)
    return m


def icosahedron():
    phi = (1 + 5 ** 0.5) / 2
    V = [(-1, phi, 0), (1, phi, 0), (-1, -phi, 0), (1, -phi, 0), (0, -1, phi), (0, 1, phi),
         (0, -1, -phi), (0, 1, -phi), (phi, 0, -1), (phi, 0, 1), (-phi, 0, -1), (-phi, 0, 1)]
    V = [np.array(v, float) / np.linalg.norm(v) for v in V]
    F = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
         (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
         (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    return V, F


def rock(c, r, seed, uvf, squash=0.7):
    """Low-poly faceted rock: a jittered, subdivided icosahedron with flat normals."""
    rng = np.random.default_rng(seed)
    V, F = icosahedron()
    # one subdivision
    cache, verts = {}, list(V)

    def mid(i, j):
        k = (min(i, j), max(i, j))
        if k not in cache:
            p = verts[i] + verts[j]
            verts.append(p / np.linalg.norm(p))
            cache[k] = len(verts) - 1
        return cache[k]
    F2 = []
    for (a, b, cc) in F:
        ab, bc, ca = mid(a, b), mid(b, cc), mid(cc, a)
        F2 += [(a, ab, ca), (b, bc, ab), (cc, ca, bc), (ab, bc, ca)]
    scale = rng.uniform(0.78, 1.18, len(verts))
    P = [np.asarray(c, float) + v * r * s * np.array((1, squash, 1)) for v, s in zip(verts, scale)]
    m = Mesh()
    for (a, b, cc) in F2:
        pa, pb, pc = P[a], P[b], P[cc]
        n = np.cross(pb - pa, pc - pa)
        if np.dot(n, (pa + pb + pc) / 3 - np.asarray(c, float)) < 0:
            n = -n
        m.tri([pa, pb, pc], [n] * 3, [uvf(pa, n), uvf(pb, n), uvf(pc, n)])
    # flatten the bottom so rocks sit on the table
    return m


def flatten_below(mesh, y):
    m = Mesh()
    m.p = [np.array((p[0], max(p[1], y), p[2])) for p in mesh.p]
    m.n, m.t = list(mesh.n), list(mesh.t)
    return m


# ------------------------------------------------------------------ glb writer

def write_glb(filename, mesh, name="mesh", material="default"):
    P = np.asarray(mesh.p, np.float32)
    N = np.asarray(mesh.n, np.float32)
    T = np.asarray(mesh.t, np.float32)
    I = np.arange(len(P), dtype=np.uint32)
    blob = bytearray()
    views, accessors = [], []

    def add(arr, target, ctype, typ, minmax=False):
        off = len(blob)
        data = arr.tobytes()
        blob.extend(data)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            acc["min"] = [float(x) for x in arr.min(0)]
            acc["max"] = [float(x) for x in arr.max(0)]
        accessors.append(acc)
        return len(accessors) - 1

    pos = add(P, 34962, 5126, "VEC3", True)
    nor = add(N, 34962, 5126, "VEC3")
    tex = add(T, 34962, 5126, "VEC2")
    ind = add(I, 34963, 5125, "SCALAR")
    gltf = {
        "asset": {"version": "2.0", "generator": "behind-the-screen tools/generate.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": pos, "NORMAL": nor, "TEXCOORD_0": tex},
            "indices": ind, "material": 0, "mode": 4}]}],
        "materials": [{"name": material, "pbrMetallicRoughness": {
            "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0}}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(filename, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00"))
        f.write(bytes(blob))
