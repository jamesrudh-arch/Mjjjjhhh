#!/bin/bash
# Deterministic before/after cinematography capture (GL Compatibility +
# llvmpipe; the Mesa 25.0.7 lavapipe Vulkan path stalls in this sandbox —
# logic ticks fine under Vulkan, only present/swapchain hangs, so the game
# itself is unaffected; on-device Xogot uses the real GPU).
# Usage: cmp_shot.sh <tag> <out_dir>
set -u
TAG="${1:?tag}"
OUT="${2:?out dir}"
GODOT=/home/z/my-project/tools/Godot_v4.7.2-stable_linux.x86_64
PROJ=/home/z/my-project/leverage
export LD_LIBRARY_PATH=/home/z/my-project/tools/mesa_vk/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
mkdir -p "$OUT"
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
  setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 < /dev/null &
  sleep 1.5
fi
cd "$PROJ"
rm -f "$OUT/${TAG}_"*.png
DISPLAY=:99 LEVERAGE_PROBE_OUT="$OUT" LEVERAGE_CMP_TAG="$TAG" \
  timeout 300 "$GODOT" --path . --resolution 1280x720 \
  --rendering-method gl_compatibility res://tests/compare_shot.tscn >"$OUT/${TAG}.log" 2>&1
RC=$?
echo "exit=$RC"
grep -E "CMP|SCRIPT ERROR" "$OUT/${TAG}.log" | head -10
ls -la "$OUT/${TAG}_"*.png 2>/dev/null
