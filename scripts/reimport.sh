#!/bin/bash
# Re-import changed resources into the Godot project (must run before render probes
# when assets changed on disk; non-editor runs use the last import).
cd /home/z/my-project/leverage
timeout 240 /home/z/my-project/tools/Godot_v4.4.1-stable_linux.x86_64 --headless -e -q --quit --path . 2>&1 | grep -cE "Importing|import" || true
echo "reimport done"
