#!/bin/bash
# v2.5 evidence run: real boot flow under Xvfb + lavapipe (Forward Mobile).
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
DISPLAY=:99 timeout 900 "$TOOLS/Godot_v4.7.2-stable_linux.x86_64" --path . --resolution 1280x720 res://tests/evidence_v25.tscn >"$OUT/game.log" 2>&1
echo "exit=$?"
grep -E "\[EV\]|ERROR|SCRIPT" "$OUT/game.log" | head -25
ls -la "$OUT"/*.png 2>/dev/null | awk '{print $5, $9}'
