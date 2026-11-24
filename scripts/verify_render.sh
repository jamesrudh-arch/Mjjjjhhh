#!/bin/bash
# Fresh-eyes render verification of the XOGOT zip delivery (session 9).
# Boots the real game (no test mode) under Godot 4.7.2 + Forward Mobile via
# lavapipe software Vulkan on Xvfb :99, captures boot-card + menu frames.
# Usage: verify_render.sh <project_dir> <out_dir> [godot_binary] [runtime_s]
set -u
PROJ="${1:-/home/z/my-project/scratch/leverage}"
OUT="${2:-/home/z/my-project/scratch/render_out}"
GODOT="${3:-/home/z/my-project/tools/Godot_v4.7.2-stable_linux.x86_64}"
RUNTIME="${4:-12}"
TOOLS=/home/z/my-project/tools
export VK_DRIVER_FILES="$TOOLS/mesa_vk/usr/share/vulkan/icd.d/lvp_icd.json"
export LD_LIBRARY_PATH="$TOOLS/mesa_vk/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

mkdir -p "$OUT"
# --- X display ---
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
  setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 < /dev/null &
  sleep 1.5
fi
# --- run the game (real boot, no LEVERAGE_TEST) ---
cd "$PROJ"
DISPLAY=:99 timeout $((RUNTIME + 8)) "$GODOT" --path . --resolution 1280x720 >"$OUT/game.log" 2>&1 &
GODOT_PID=$!
# --- capture frames while it runs ---
# capture at wall-clock seconds (engine start under llvmpipe costs ~3s, so
# game-time t roughly equals wall - 3)
SPECS="${SPECS:-3:01_company 6:02_title 10:03_notice 18:04_menu 24:05_menu_late}"
PREV=0
for spec in $SPECS; do
  T="${spec%%:*}"; NAME="${spec##*:}"
  NOW=$(date +%s); START=${START:-$NOW}
  TARGET=$((START + T))
  while [ "$(date +%s)" -lt "$TARGET" ]; do sleep 0.3; done
  DISPLAY=:99 xwininfo -root -children >/dev/null 2>&1 || true   # X round-trip: forces frame sync before grab (without this, x11grab can return a stale/black frame)
  # burst-grab: x11grab races the game's redraw under llvmpipe and can return
  # root pixels (black) on individual frames; take 10 frames and keep the
  # largest (real content) as the canonical capture.
  rm -f "$OUT/_burst.png" "$OUT/_burst"*.png
  ffmpeg -y -loglevel error -f x11grab -video_size 1280x720 -framerate 10 -i :99 -frames:v 10 "$OUT/_burst%d.png" 2>>"$OUT/game.log"
  BEST=$(ls -S "$OUT"/_burst*.png 2>/dev/null | head -1)
  [ -n "$BEST" ] && cp "$BEST" "$OUT/${NAME}.png"
  rm -f "$OUT"/_burst*.png
done
wait $GODOT_PID 2>/dev/null
echo "--- game.log (diag lines) ---"
grep -E "LEVERAGE|Godot|renderer|Vulkan|ERROR|SCRIPT ERROR" "$OUT/game.log" | head -20
ls -la "$OUT"
