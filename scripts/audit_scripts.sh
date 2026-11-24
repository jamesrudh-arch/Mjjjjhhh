#!/bin/bash
# Audit: parse-check ALL .gd scripts in an IMPORTED project dir on a given
# engine. Reports every script that fails to load (real ship-blockers).
# Usage: audit_scripts.sh <project_dir> <godot_binary> <tag>
set -u
PROJ="$1"; GODOT="$2"; TAG="$3"
cd "$PROJ"
FAIL=0; TOTAL=0
REPORT=/home/z/my-project/scratch/audit_${TAG}.txt
: > "$REPORT"
while IFS= read -r -d '' f; do
  TOTAL=$((TOTAL+1))
  OUT=$("$GODOT" --headless --check-only --script "$f" --path "$PROJ" 2>&1)
  if echo "$OUT" | grep -q "Failed to load script"; then
    FAIL=$((FAIL+1))
    echo "=== $f ===" >> "$REPORT"
    echo "$OUT" | grep -E "SCRIPT ERROR" | head -3 >> "$REPORT"
  fi
done < <(find scripts tests -name "*.gd" -print0 | sort -z)
echo "AUDIT[$TAG] total=$TOTAL failed=$FAIL"
[ $FAIL -gt 0 ] && cat "$REPORT" || echo "(all scripts parse clean)"
