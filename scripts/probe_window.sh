#!/bin/bash
# Probe: does the Godot game window survive >20s of menu idle? Captures frames
# at intervals and checks the X window tree + process liveness each time.
set -u
PROJ=/home/z/my-project/scratch/leverage
OUT=/home/z/my-project/scratch/probe_win
GODOT=/home/z/my-project/tools/Godot_v4.7.2-stable_linux.x86_64
TOOLS=/home/z/my-project/tools
export VK_DRIVER_FILES="$TOOLS/mesa_vk/usr/share/vulkan/icd.d/lvp_icd.json"
export LD_LIBRARY_PATH="$TOOLS/mesa_vk/usr/lib/x86_64-linux-gnu"
rm -rf "$OUT"; mkdir -p "$OUT"
if ! pgrep -f "Xvfb :99" >/dev/null; then setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 </dev/null & sleep 1.5; fi
cd "$PROJ"
DISPLAY=:99 "$GODOT" --path . --resolution 1280x720 >"$OUT/game.log" 2>&1 &
GP=$!
START=$(date +%s)
for T in 12 18 24 30 40 55; do
  while [ $(( $(date +%s) - START )) -lt $T ]; do sleep 0.3; done
  EL=$(( $(date +%s) - START ))
  ALIVE=$(kill -0 $GP 2>/dev/null && echo yes || echo no)
  WIN=$(DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -c "Godot\|LEVERAGE" || true)
  SZ=$(DISPLAY=:99 xwininfo -root -children 2>/dev/null | grep -oE "[0-9]+x[0-9]+" | head -3 | tr '\n' ' ')
  ffmpeg -y -loglevel error -f x11grab -video_size 1280x720 -i :99 -frames:v 1 "$OUT/f${EL}s.png" 2>/dev/null
  echo "t=${EL}s alive=$ALIVE godot_windows=$WIN sizes=[$SZ] bytes=$(stat -c%s "$OUT/f${EL}s.png" 2>/dev/null)"
done
kill $GP 2>/dev/null
grep -E "LEVERAGE|ERROR|SCRIPT" "$OUT/game.log" | grep -v ALSA | head -8
