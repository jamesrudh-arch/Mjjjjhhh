#!/bin/bash
# Probe runner: usage probe.sh <scene_res_path> <tag> <out_dir> [runtime_s]
set -u
SCENE="${1:?scene}"
TAG="${2:?tag}"
OUT="${3:?out dir}"
GODOT=/home/z/my-project/tools/Godot_v4.7.2-stable_linux.x86_64
TOOLS=/home/z/my-project/tools
PROJ=/home/z/my-project/leverage
export VK_DRIVER_FILES="$TOOLS/mesa_vk/usr/share/vulkan/icd.d/lvp_icd.json"
export LD_LIBRARY_PATH="$TOOLS/mesa_vk/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$OUT"
if ! pgrep -f "Xvfb :99" >/dev/null 2>&1; then
  setsid Xvfb :99 -screen 0 1334x756x24 -ac >/dev/null 2>&1 < /dev/null &
  sleep 1.5
fi
cd "$PROJ"
DISPLAY=:99 LEVERAGE_PROBE_OUT="$OUT" LEVERAGE_CMP_TAG="$TAG" \
  timeout "${4:-300}" "$GODOT" --path . --resolution 1280x720 \
  --mobile-renderer "$SCENE" >"$OUT/${TAG}.log" 2>&1
RC=$?
echo "exit=$RC"
grep -E "CMP|SHOT|WORLDSHOT|SCRIPT ERROR|ERROR" "$OUT/${TAG}.log" | grep -v ALSA | head -15
ls -la "$OUT/${TAG}_"*.png "$OUT/"world_*.png 2>/dev/null
