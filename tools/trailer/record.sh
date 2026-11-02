#!/usr/bin/env bash
# Film the real game for a trailer: builds a Linux bundle, plays the whole museum prologue headless
# (autotest mode 8 at trailer pace: nights at their own speed, cards held a moment) on Xvfb, and
# records the screen with ffmpeg. Writes OUT/rec.mkv and OUT/marks.tsv (seconds into the recording,
# then each autotest log line), so tools/trailer/cut.py can find the moments.
#
#   tools/trailer/record.sh OUT_DIR
#
# Needs what tools/tests/engine_check.sh needs (BOB, JAVA, Xvfb), plus ffmpeg.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?out dir}"
BOB="${BOB:-/home/claude/defold/bob.jar}"
JAVA="${JAVA:-/home/claude/defold/jdk/jdk-25.0.2+10/bin/java}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; [ -n "${XPID:-}" ] && kill $XPID 2>/dev/null; [ -n "${FPID:-}" ] && kill -INT $FPID 2>/dev/null' EXIT
mkdir -p "$OUT"

mkdir -p "$WORK/src"
for d in game main render input assets materials game.project tools; do cp -r "$ROOT/$d" "$WORK/src/"; done
(cd "$WORK/src" && "$JAVA" -jar "$BOB" --root . --variant release --platform x86_64-linux --archive \
    --settings tools/tests/autotest1.ini --bundle-output "$WORK/bundle" build bundle > "$OUT/bob.log" 2>&1) \
    || { echo "bob failed, see $OUT/bob.log"; exit 1; }
GAME="$(find "$WORK/bundle" -name '*.x86_64' | head -1)"
GAME_DIR="$(dirname "$GAME")"
sed -i "s/^autotest = .*/autotest = 8\ntrailer = 1/" "$GAME_DIR/game.projectc"

mkdir -p "$WORK/lib" "$WORK/home/.local/share"
echo 'void bts_glu_stub(void) {}' > "$WORK/lib/glu.c"
gcc -shared -fPIC -Wl,-soname,libGLU.so.1 -o "$WORK/lib/libGLU.so.1" "$WORK/lib/glu.c"
printf 'pcm.!default { type null }\nctl.!default { type hw card 0 }\n' > "$WORK/home/.asoundrc"

D="${XDISPLAY:-:96}"
Xvfb $D -screen 0 1600x900x24 >/dev/null 2>&1 &
XPID=$!
sleep 1.5

ffmpeg -y -loglevel error -f x11grab -framerate 30 -video_size 1600x900 -draw_mouse 0 -i "$D" \
    -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p "$OUT/rec.mkv" &
FPID=$!
T0=$(date +%s.%N)

(cd "$GAME_DIR" && HOME="$WORK/home" XDG_DATA_HOME="$WORK/home/.local/share" LD_LIBRARY_PATH="$WORK/lib" \
    DISPLAY=$D timeout 6000 "$GAME" > "$OUT/engine.log" 2>&1) &
GPID=$!
: > "$OUT/marks.tsv"
seen=0
while kill -0 $GPID 2>/dev/null; do
    sleep 0.25
    al=$(find "$WORK/home" -name autotest.log 2>/dev/null | head -1)
    [ -z "$al" ] && continue
    n=$(wc -l < "$al")
    if [ "$n" -gt "$seen" ]; then
        now=$(date +%s.%N)
        t=$(awk "BEGIN{printf \"%.2f\", $now - $T0}")
        tail -n +$((seen + 1)) "$al" | head -n $((n - seen)) | sed "s/^/$t\t/" >> "$OUT/marks.tsv"
        seen=$n
    fi
done
kill -INT $FPID 2>/dev/null
wait $FPID 2>/dev/null
FPID=""
echo "recorded $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/rec.mkv") s"
tail -5 "$OUT/marks.tsv"
