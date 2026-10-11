#!/usr/bin/env bash
# Run the real game engine headless and let it play itself (M7). Checks the parts the
# Lua tests can't: sound, the evening light, the snack table, saving to disk and
# continuing a saved campaign. Linux only (Xvfb + Mesa); not needed on Windows.
#
#   tools/tests/engine_check.sh [out_dir]
#   VARIANT=release PLAYTEST=1 tools/tests/engine_check.sh [out_dir]   # the testers' build settings
#   MODES=4 tools/tests/engine_check.sh [out_dir]                       # screenshots of the real-session pass
#
# Needs BOB (bob.jar), JAVA (Java 25 for Bob 1.13.2), Xvfb, and ImageMagick's `import`
# for the screenshots. Builds a Linux bundle with tools/tests/autotest1.ini, plays
# Session Zero and two sessions, quits, then runs again in "continue" mode and plays one
# more. Fails on any Lua error in the engine log. Screenshots land in out_dir.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/build/engine_check}"
VARIANT="${VARIANT:-debug}"
EXTRA=()
[ "${PLAYTEST:-0}" = "1" ] && EXTRA=(--settings tools/playtest/playtest.ini)
BOB="${BOB:-/home/claude/defold/bob.jar}"
JAVA="${JAVA:-/home/claude/defold/jdk/jdk-25.0.2+10/bin/java}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; [ -n "${XPID:-}" ] && kill $XPID 2>/dev/null' EXIT
mkdir -p "$OUT"

# A copy to build from, so the project's own build folder is left alone.
mkdir -p "$WORK/src"
for d in game main render input assets materials game.project tools; do cp -r "$ROOT/$d" "$WORK/src/"; done
(cd "$WORK/src" && "$JAVA" -jar "$BOB" --root . --variant "$VARIANT" --platform x86_64-linux --archive \
    "${EXTRA[@]}" --settings tools/tests/autotest1.ini --bundle-output "$WORK/bundle" build bundle > "$OUT/bob.log" 2>&1) \
    || { echo "bob failed, see $OUT/bob.log"; exit 1; }
GAME_DIR="$(dirname "$(find "$WORK/bundle" -name '*.x86_64' | head -1)")"
GAME="$(find "$WORK/bundle" -name '*.x86_64' | head -1)"

# Headless helpers: an empty libGLU (the engine links it but calls nothing in it) and a
# null sound card, so the sound system starts and every sound.play really runs.
mkdir -p "$WORK/lib" "$WORK/home/.local/share"
echo 'void bts_glu_stub(void) {}' > "$WORK/lib/glu.c"
gcc -shared -fPIC -Wl,-soname,libGLU.so.1 -o "$WORK/lib/libGLU.so.1" "$WORK/lib/glu.c"
printf 'pcm.!default { type null }\nctl.!default { type hw card 0 }\n' > "$WORK/home/.asoundrc"

DISPLAY_N="${XDISPLAY:-:97}"
Xvfb $DISPLAY_N -screen 0 1600x900x24 >/dev/null 2>&1 &
XPID=$!
sleep 1.5

autolog() { find "$WORK/home" -name autotest.log 2>/dev/null | head -1; }

run() {  # mode
    local mode=$1 log="$OUT/engine_$1.log"
    sed -i "s/^autotest = .*/autotest = $mode/" "$GAME_DIR/game.projectc"
    local al start=0
    al=$(autolog)
    [ -n "$al" ] && start=$(wc -l < "$al")
    (cd "$GAME_DIR" && HOME="$WORK/home" XDG_DATA_HOME="$WORK/home/.local/share" LD_LIBRARY_PATH="$WORK/lib" \
        DISPLAY=$DISPLAY_N timeout 900 "$GAME" > "$log" 2>&1) &
    local pid=$! seen=0
    while kill -0 $pid 2>/dev/null; do
        sleep 0.3
        al=$(autolog)
        [ -z "$al" ] && continue
        local shots
        shots=$(tail -n +$((start + 1)) "$al" | grep "AUTOTEST shot" || true)
        local n
        n=$(printf '%s' "$shots" | grep -c "AUTOTEST shot" || true)
        while [ "$n" -gt "$seen" ]; do
            seen=$((seen + 1))
            local name
            name=$(printf '%s\n' "$shots" | sed -n "${seen}p" | sed 's/.*AUTOTEST shot //')
            sleep 0.8
            import -display $DISPLAY_N -window root "$OUT/${mode}_$(printf %02d $seen)_$name.png" 2>/dev/null
        done
    done
    wait $pid
    local code=$?
    al=$(autolog)
    [ -n "$al" ] && tail -n +$((start + 1)) "$al" | grep -v " shot " | sed "s/^/  [$mode] /"
    local errs
    errs=$(find "$WORK/home" -name error_log.txt 2>/dev/null | head -1)
    # An engine buffer running out (text batches, particles, nodes) drops things off the screen silently.
    if grep -q "reached limit\|Increase the capacity\|Out of resources\|buffer full" "$log"; then
        echo "  [$mode] the engine ran out of room:"; grep "reached limit\|Increase the capacity\|Out of resources\|buffer full" "$log" | sort | uniq -c | head -5
        return 1
    fi
    if grep -q "ERROR:SCRIPT\|\[game\] ERROR" "$log" || [ -n "$errs" ] || ! tail -n +$((start + 1)) "$al" | grep -q "AUTOTEST done"; then
        echo "  [$mode] errors:"; grep -A6 "ERROR:SCRIPT\|\[game\] ERROR" "$log" | head -40
        [ -n "$errs" ] && head -20 "$errs"
        return 1
    fi
    [ $code -eq 0 ] || { echo "  [$mode] exit code $code"; return 1; }
    return 0
}

ok=0
# MODES="4": the real-session showcase (story board, notes, sheet, builder, game night shots).
for m in ${MODES:-1 2}; do
    run "$m" || ok=1
done
if [ "${MODES:-1 2}" != "6" ]; then   # (the board gallery plays no session: nothing to save)
SAVE=$(find "$WORK/home" -name campaign_save.txt | head -1)
[ -n "$SAVE" ] && echo "  save: $(head -c 40 "$SAVE" | tr '\n' ' ')... $(wc -c < "$SAVE") bytes" || { echo "  no save file written"; ok=1; }
LOGF=$(find "$WORK/home" -name playtest_log.jsonl | head -1)
[ -n "$LOGF" ] && echo "  playtest log: $(wc -l < "$LOGF") lines" || { echo "  no playtest log"; ok=1; }
fi
[ $ok -eq 0 ] && echo "ENGINE CHECK OK" || echo "ENGINE CHECK FAILED"
exit $ok
