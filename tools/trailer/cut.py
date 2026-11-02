"""Cut the trailer: python3 tools/trailer/cut.py PLAN.json OUT_DIR

PLAN.json: {"music": "music.wav", "length": 40.0, "shots": [...]} where each shot is
  {"src": "rec.mkv", "at": 123.4,            # seconds into the recording where it starts
   "len": 1.875,                             # seconds it lasts in the trailer
   "speed": "game" | "wall" | 2.0,           # game: one frame per frame the engine drew (real time);
                                             #   wall: as recorded; a number: that many times game speed
   "zoom": [1.0, 1.08], "focus": [0.5, 0.5],  # push in from/to, around this point (0..1 of the frame)
   "text": "titles/make_call.png", "text_in": 0.1, "text_out": 1.7,
   "flash": true}                            # a white flash on the cut (on the beat)
  or a still: {"image": "titles/end_bg.png", "len": 4.38, "layers": [{"png", "in", "out", "slam"}]}

Each shot becomes its own 1920x1080 30 fps file (same encoder settings), the files are joined with
the concat demuxer, and the music goes on last.
"""
import json
import os
import subprocess
import sys

FPS = 30
W, H = 1920, 1080
ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-r", str(FPS)]


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-3000:])
        raise SystemExit("ffmpeg failed: " + " ".join(cmd[:8]))


def footage(shot, out, base):
    n = round(shot["len"] * FPS)
    src = os.path.join(base, shot["src"])
    speed = shot.get("speed", "game")
    z0, z1 = shot.get("zoom", [1.0, 1.06])
    fx, fy = shot.get("focus", [0.5, 0.5])
    # Pull frames out at the game's own pace: the software renderer draws a few frames a second, each
    # one fixed step of game time (1/30 s), so one kept frame per drawn frame is real time. A still
    # stretch is kept at about the renderer's rate (max), so it doesn't vanish.
    rec_fps = shot.get("rec_fps", 15)
    dup = max(1, round(rec_fps / 3.9) - 1)
    if speed == "game":
        pick = f"mpdecimate=hi=64*4:lo=64*2:frac=0.05:max={dup},setpts=N/({FPS}*TB)"
    elif speed == "wall":
        pick = f"fps={FPS}"
    else:
        pick = f"mpdecimate=hi=64*4:lo=64*2:frac=0.05:max={dup},setpts=N/({FPS * float(speed)}*TB)"
    zexpr = f"{z0}+({z1}-{z0})*on/{max(1, n - 1)}"
    zoom = (f"scale=3200:1800:flags=lanczos,zoompan=z='{zexpr}':x='{fx}*iw-iw/zoom/2':y='{fy}*ih-ih/zoom/2'"
            f":d=1:s={W}x{H}:fps={FPS}")
    chain = f"[0:v]{pick},{zoom},trim=end_frame={n},setpts=PTS-STARTPTS"
    if shot.get("flash"):
        chain += ",fade=t=in:st=0:d=0.18:color=white"
    if shot.get("dip"):
        chain += f",fade=t=out:st={shot['len'] - 0.2}:d=0.2"
    chain += ",format=yuv420p[v0]"
    inputs = ["-ss", str(max(0.0, shot["at"])), "-i", src]
    graph = [chain]
    last = "v0"
    for i, t in enumerate(shot.get("texts", ([] if not shot.get("text") else
                                             [{"png": shot["text"], "in": shot.get("text_in", 0.1),
                                               "out": shot.get("text_out", shot["len"] - 0.15)}]))):
        inputs += ["-loop", "1", "-framerate", str(FPS), "-i", os.path.join(base, t["png"])]
        k = len([x for x in inputs if x == "-i"]) - 1
        graph.append(f"[{k}:v]format=rgba,fade=t=in:st={t['in']}:d=0.16:alpha=1,"
                     f"fade=t=out:st={t['out']}:d=0.18:alpha=1[t{i}]")
        graph.append(f"[{last}][t{i}]overlay=0:0:shortest=1:format=auto[o{i}]")
        last = f"o{i}"
    cmd = ["ffmpeg", "-y", "-loglevel", "error"] + inputs + ["-filter_complex", ";".join(graph), "-map", f"[{last}]",
                                                             "-frames:v", str(n), "-an"] + ENC + [out]
    run(cmd)


def still(shot, out, base):
    n = round(shot["len"] * FPS)
    inputs = ["-loop", "1", "-framerate", str(FPS), "-i", os.path.join(base, shot["image"])]
    z0, z1 = shot.get("zoom", [1.0, 1.03])
    graph = [f"[0:v]scale=3840:2160,zoompan=z='{z0}+({z1}-{z0})*on/{max(1, n - 1)}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2'"
             f":d=1:s={W}x{H}:fps={FPS},trim=end_frame={n},format=yuv420p"
             + (",fade=t=in:st=0:d=0.25:color=white" if shot.get("flash") else "") + "[v0]"]
    last = "v0"
    for i, l in enumerate(shot.get("layers", [])):
        inputs += ["-loop", "1", "-framerate", str(FPS), "-i", os.path.join(base, l["png"])]
        k = i + 1
        fade = f"fade=t=in:st={l['in']}:d={l.get('fade', 0.3)}:alpha=1"
        if l.get("slam"):
            # Slams in: from a little too big down to its size, in a quarter of a second.
            s0, t0 = 1.18, l["in"]
            scale = (f"scale=w='{W}*(1+({s0}-1)*max(0,1-(t-{t0})/0.25))':h=-1:eval=frame")
            graph.append(f"[{k}:v]format=rgba,{scale},fade=t=in:st={t0}:d=0.06:alpha=1[t{i}]")
            graph.append(f"[{last}][t{i}]overlay=x='(W-w)/2':y='(H-h)/2':shortest=1:eval=frame[o{i}]")
        else:
            graph.append(f"[{k}:v]format=rgba,{fade}[t{i}]")
            graph.append(f"[{last}][t{i}]overlay=0:0:shortest=1[o{i}]")
        last = f"o{i}"
    tail = shot.get("fade_out")
    if tail:
        graph.append(f"[{last}]fade=t=out:st={shot['len'] - tail}:d={tail}[end]")
        last = "end"
    cmd = ["ffmpeg", "-y", "-loglevel", "error"] + inputs + ["-filter_complex", ";".join(graph), "-map", f"[{last}]",
                                                             "-frames:v", str(n), "-an"] + ENC + [out]
    run(cmd)


def main():
    plan_path, out_dir = sys.argv[1], sys.argv[2]
    base = os.path.dirname(os.path.abspath(plan_path))
    plan = json.load(open(plan_path))
    os.makedirs(out_dir, exist_ok=True)
    only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 else None
    files = []
    for i, shot in enumerate(plan["shots"]):
        name = os.path.join(out_dir, f"s{i:02d}.mp4")
        files.append(name)
        if only and str(i) not in only:
            continue
        tmp = name[:-4] + ".tmp.mp4"
        if "image" in shot:
            still(shot, tmp, base)
        else:
            footage(shot, tmp, base)
        os.replace(tmp, name)
        print("shot", i, "done", flush=True)
    lst = os.path.join(out_dir, "list.txt")
    with open(lst, "w") as f:
        for name in files:
            f.write(f"file '{os.path.abspath(name)}'\n")
    joined = os.path.join(out_dir, "joined.mp4")
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined])
    final = os.path.join(out_dir, plan.get("out", "trailer.mp4"))
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", joined, "-i", os.path.join(base, plan["music"]), "-map", "0:v",
         "-map", "1:a", "-c:v", "copy", "-af", "volume=-1.5dB", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", final])
    print("wrote", final)


if __name__ == "__main__":
    main()
