#!/usr/bin/env bash
# The store and website set from a capture.sh folder (October 20): Steam's main, header, small and
# vertical capsules (the fight from the DM's seat, the title over the screen), the website preview
# and hero (the room), and the title alone on a transparent ground.
#
#   tools/keyart/make_all.sh capture_dir out_dir
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
IN="$1"; OUT="$2"; mkdir -p "$OUT"
F2=$(ls "$IN"/*keyart_fight_z2*.png | head -1)
F1=$(ls "$IN"/*keyart_fight_z1*.png | head -1)
TAG="A cozy game about running the table for your friends"
C="python3 $HERE/compose.py"
$C "$F2" "$OUT/steam_main_capsule_1232x706.png" 1232 706 --focus 0.5,0.5 --logo center --valign bottom --shade bottom --shade-reach 0.42 --shade-strength 0.8 --logo-scale 0.27 --margin 0.045 --vig 0.35
$C "$F2" "$OUT/steam_header_capsule_920x430.png" 920 430 --focus 0.5,0.62 --logo center --valign bottom --shade bottom --shade-reach 0.45 --shade-strength 0.85 --logo-scale 0.34 --margin 0.05 --vig 0.35
$C "$F2" "$OUT/steam_small_capsule_462x174.png" 462 174 --focus 0.5,0.55 --logo center --valign middle --shade bottom --shade-reach 1.0 --shade-strength 0.55 --logo-scale 0.78 --margin 0.05 --vig 0.5
$C "$F2" "$OUT/steam_vertical_capsule_748x896.png" 748 896 --focus 0.5,0.5 --logo center --valign bottom --shade bottom --shade-reach 0.4 --shade-strength 0.85 --logo-scale 0.26 --margin 0.05 --vig 0.35
$C "$F1" "$OUT/website_preview_1200x630.png" 1200 630 --focus 0.5,0.5 --logo left --valign top --shade top --shade-reach 0.45 --shade-strength 0.5 --logo-scale 0.22 --margin 0.05 --vig 0.4 --tagline "$TAG"
$C "$F1" "$OUT/website_hero_1920x1080.png" 1920 1080 --focus 0.5,0.5 --logo left --valign top --shade top --shade-reach 0.45 --shade-strength 0.5 --logo-scale 0.21 --margin 0.05 --vig 0.4 --tagline "$TAG"
python3 - "$HERE" "$OUT/logo_transparent_1280x720.png" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import compose
from PIL import Image
lg = compose.logo(560)
W, H = 1280, 720
s = min((W - 40) / lg.width, (H - 40) / lg.height, 1.0)
lg = lg.resize((int(lg.width * s), int(lg.height * s)), Image.LANCZOS)
c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
c.alpha_composite(lg, ((W - lg.width) // 2, (H - lg.height) // 2))
c.save(sys.argv[2])
print(sys.argv[2], c.size)
PY
