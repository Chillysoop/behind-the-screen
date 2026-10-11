#!/usr/bin/env bash
# Real clicks on game night (the fix pass, A1). Builds the testers' release build with
# tools/tests/ui_play/ui_play.ini, runs it under Xvfb with software rendering (about 1 to 2
# frames a second), lets autotest mode 5 drive every screen but the cards, and clicks every
# card with real X input through drive.py. Linux only; needs BOB, JAVA, Xvfb, gcc, python3.
#
#   tools/tests/ui_play/run.sh [out_dir]            # default 200 cards
#   CARDS=50 HOLD=0.1 tools/tests/ui_play/run.sh    # fewer cards, button held 0.1 s
#   BUNDLE=dir tools/tests/ui_play/run.sh           # reuse a bundle built by an earlier run
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HERE="$ROOT/tools/tests/ui_play"
OUT="${1:-$ROOT/build/ui_play}"
BOB="${BOB:-/home/claude/defold/bob.jar}"
JAVA="${JAVA:-/home/claude/defold/jdk/jdk-25.0.2+10/bin/java}"
# A free X display (another run, or anything else, may hold :93).
if [ -n "${XDISPLAY:-}" ]; then DISPLAY_N="$XDISPLAY"; else
    for n in $(seq 93 120); do [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ] || { DISPLAY_N=":$n"; break; }; done
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; [ -n "${GPID:-}" ] && kill $GPID 2>/dev/null; [ -n "${XPID:-}" ] && kill $XPID 2>/dev/null' EXIT
mkdir -p "$OUT"

if [ -z "${BUNDLE:-}" ]; then
    mkdir -p "$WORK/src"
    for d in game main render input assets materials game.project tools; do cp -r "$ROOT/$d" "$WORK/src/"; done
    (cd "$WORK/src" && "$JAVA" -jar "$BOB" --root . --variant release --platform x86_64-linux --archive \
        --settings tools/playtest/playtest.ini --settings tools/tests/ui_play/ui_play.ini \
        --bundle-output "$OUT/bundle" build bundle > "$OUT/bob.log" 2>&1) || { echo "bob failed, see $OUT/bob.log"; exit 1; }
    BUNDLE="$OUT/bundle"
fi
GAME="$(find "$BUNDLE" -name '*.x86_64' | head -1)"
GAME_DIR="$(dirname "$GAME")"
[ -n "${WEEKS:-}" ] && sed -i "s/^autotest_weeks = .*/autotest_weeks = $WEEKS/" "$GAME_DIR/game.projectc"

mkdir -p "$WORK/lib" "$WORK/home/.local/share"
echo 'void bts_glu_stub(void) {}' > "$WORK/lib/glu.c"
gcc -shared -fPIC -Wl,-soname,libGLU.so.1 -o "$WORK/lib/libGLU.so.1" "$WORK/lib/glu.c"
printf 'pcm.!default { type null }\nctl.!default { type hw card 0 }\n' > "$WORK/home/.asoundrc"
Xvfb $DISPLAY_N -screen 0 1600x900x24 >/dev/null 2>&1 &
XPID=$!
sleep 1.5
kill -0 $XPID 2>/dev/null || { echo "Xvfb didn't start on $DISPLAY_N"; exit 1; }
(cd "$GAME_DIR" && HOME="$WORK/home" XDG_DATA_HOME="$WORK/home/.local/share" LD_LIBRARY_PATH="$WORK/lib" \
    DISPLAY=$DISPLAY_N "$GAME" > "$OUT/engine.log" 2>&1) &
GPID=$!
DISPLAY=$DISPLAY_N python3 -u "$HERE/drive.py" --home "$WORK/home" --cards "${CARDS:-200}" --hold "${HOLD:-0.1}" \
    --shots "$OUT/shots" ${STRICT:+--strict} | tee "$OUT/drive.log"
code=${PIPESTATUS[0]}
cp "$(find "$WORK/home" -name input_trace.log | head -1)" "$OUT/" 2>/dev/null
cp "$(find "$WORK/home" -name autotest.log | head -1)" "$OUT/" 2>/dev/null
ERR="$(find "$WORK/home" -name error_log.txt | head -1)"
[ -n "$ERR" ] && { echo "game errors:"; head -30 "$ERR"; code=1; }
grep -q "ERROR:SCRIPT" "$OUT/engine.log" && { echo "script errors in engine.log"; grep -A5 "ERROR:SCRIPT" "$OUT/engine.log" | head -30; code=1; }
[ $code -eq 0 ] && echo "UI PLAY OK" || echo "UI PLAY FAILED"
exit $code
