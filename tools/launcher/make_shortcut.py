"""Make the launcher icon and a Windows desktop shortcut (.lnk) for play.ps1.

    python3 tools/launcher/make_shortcut.py [windows_project_path] [out.lnk]

The icon is drawn here (a warm gold d20). The shortcut is written by hand in the
MS-SHLLINK format, so it can be made on any OS. On Windows itself,
`play.ps1 -InstallShortcut` does the same job natively.
"""
import math
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ICON = os.path.join(HERE, "behind_the_screen.ico")

BG = (27, 20, 17)
RIM = (67, 52, 42)
GOLD = [(250, 214, 132), (232, 176, 74), (196, 136, 48), (150, 98, 34)]
INK = (43, 32, 24)


def draw_icon(size=256):
    s = 4  # supersample
    W = size * s
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = W * 0.04
    d.rounded_rectangle([pad, pad, W - pad, W - pad], radius=W * 0.2, fill=BG, outline=RIM, width=int(W * 0.02))
    cx, cy, R = W / 2, W / 2 + W * 0.01, W * 0.36
    hexv = [(cx + R * math.cos(math.radians(a)), cy - R * math.sin(math.radians(a))) for a in (90, 30, -30, -90, -150, 150)]
    top, ur, lr, bot, ll, ul = hexv
    T = (cx, cy - R * 0.46)
    L = (cx - R * 0.62, cy + R * 0.36)
    Rr = (cx + R * 0.62, cy + R * 0.36)
    faces = [
        ([top, ur, T], GOLD[1]), ([top, T, ul], GOLD[1]),
        ([ur, Rr, T], GOLD[2]), ([ul, T, L], GOLD[2]),
        ([ur, lr, Rr], GOLD[3]), ([ul, L, ll], GOLD[3]),
        ([lr, bot, Rr], GOLD[2]), ([ll, L, bot], GOLD[2]),
        ([L, Rr, bot], GOLD[3]),
        ([T, Rr, L], GOLD[0]),
    ]
    for pts, col in faces:
        d.polygon(pts, fill=col)
    edge = int(W * 0.012)
    for a, b in [(top, T), (ur, T), (ul, T), (ur, Rr), (ul, L), (lr, Rr), (ll, L), (bot, L), (bot, Rr), (T, L), (T, Rr), (L, Rr)]:
        d.line([a, b], fill=INK, width=edge)
    d.polygon(hexv, outline=INK, width=int(W * 0.018))
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Lora-Bold.ttf"), int(W * 0.17))
    tx, ty = cx, cy + R * 0.12
    d.text((tx, ty), "20", font=font, fill=INK, anchor="mm")
    return img.resize((size, size), Image.LANCZOS)


def write_ico():
    big = draw_icon(256)
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    big.save(ICON, format="ICO", sizes=sizes)
    return ICON


def make_lnk(target, arguments, working_dir, icon, description):
    """A minimal shell link: LinkInfo (local path) + string data, no ID list."""
    flags = 0x02 | 0x04 | 0x10 | 0x20 | 0x40 | 0x80  # LinkInfo, Name, WorkingDir, Args, Icon, Unicode
    clsid = bytes.fromhex("0114020000000000c000000000000046")
    header = struct.pack("<I16sIIQQQIiIHHII", 0x4C, clsid, flags, 0x20, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)
    assert len(header) == 76
    volume_id = struct.pack("<IIII", 17, 3, 0, 0x10) + b"\x00"
    base = target.encode("mbcs" if os.name == "nt" else "latin-1") + b"\x00"
    suffix = b"\x00"
    head_size = 0x1C
    vol_off = head_size
    base_off = vol_off + len(volume_id)
    suffix_off = base_off + len(base)
    total = suffix_off + len(suffix)
    link_info = struct.pack("<IIIIIII", total, head_size, 0x1, vol_off, base_off, 0, suffix_off) + volume_id + base + suffix

    def string(s):
        return struct.pack("<H", len(s)) + s.encode("utf-16-le")

    strings = string(description) + string(working_dir) + string(arguments) + string(icon)
    return header + link_info + strings + struct.pack("<I", 0)


def main():
    project = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\conne\Documents\behind-the-screen"
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "Behind the Screen - Play.lnk")
    write_ico()
    launcher = project + r"\tools\launcher\play.ps1"
    data = make_lnk(
        target=r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
        arguments='-NoProfile -ExecutionPolicy Bypass -File "' + launcher + '"',
        working_dir=project,
        icon=project + r"\tools\launcher\behind_the_screen.ico",
        description="Build and play the latest version of Behind the Screen",
    )
    with open(out, "wb") as f:
        f.write(data)
    print("wrote", ICON, "and", out, len(data), "bytes")


if __name__ == "__main__":
    main()
