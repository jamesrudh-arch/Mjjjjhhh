#!/bin/bash
set -u
PROJ=/home/z/my-project/leverage
OUT=/home/z/my-project/leverage/docs/evidence/session13
TOOLS=/home/z/my-project/tools
export VK_DRIVER_FILES="$TOOLS/mesa_vk/usr/share/vulkan/icd.d/lvp_icd.json"
export LD_LIBRARY_PATH="$TOOLS/mesa_vk/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
  setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 < /dev/null &
  sleep 1.5
fi
cd "$PROJ"
export LEVERAGE_PROBE_OUT="$OUT"
DISPLAY=:99 timeout 560 "$TOOLS/Godot_v4.7.2-stable_linux.x86_64" --path . --rendering-driver opengl3 --resolution 800x450 res://tests/evidence_world.tscn >"$OUT/game_world.log" 2>&1
echo "exit=$?"
grep -E "\[EV\]" "$OUT/game_world.log"
