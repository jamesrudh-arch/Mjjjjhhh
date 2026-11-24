#!/bin/bash
set -u
PROJ=/home/z/my-project/leverage
TOOLS=/home/z/my-project/tools
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
  setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 < /dev/null &
  sleep 1.5
fi
cd "$PROJ"
DISPLAY=:99 timeout 240 "$TOOLS/Godot_v4.4.1-stable_linux.x86_64" --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/neon_probe.tscn > /tmp/beauty.log 2>&1
echo "exit=$?"
grep -E "\[BEAUTY\]|\[BLD\]" /tmp/beauty.log | head -10
