#!/usr/bin/env python3
"""List the contents of a Godot 4.x PCK (format: GDPC v2)."""
import struct, sys
from collections import Counter

path = sys.argv[1]
with open(path, "rb") as f:
    data = f.read()

off = 0
magic = data[0:4]; off += 4
assert magic == b"GDPC", f"not a PCK (magic={magic!r})"
fmt, major, minor, patch = struct.unpack_from("<IIII", data, off); off += 16
pack_flags, file_base = struct.unpack_from("<IQ", data, off); off += 12
count = struct.unpack_from("<I", data, off)[0]; off += 4

print(f"pck format={fmt} engine={major}.{minor}.{patch} files={count} "
      f"encrypted={bool(pack_flags & 1)} flags=0x{pack_flags:x}")

files = []
for i in range(count):
    slen = struct.unpack_from("<I", data, off)[0]; off += 4
    p = data[off:off+slen].rstrip(b"\0").decode("utf-8", "replace"); off += slen
    offset, size = struct.unpack_from("<QQ", data, off); off += 16
    off += 16  # md5
    flags = struct.unpack_from("<I", data, off)[0]; off += 4
    files.append((p, offset, size, flags))

ext, top, total = Counter(), Counter(), 0
for p, o, s, fl in files:
    ext[p.split(".")[-1] if "." in p else "(none)"] += 1
    top["/".join(p.split("/")[:2])] += 1
    total += s
print(f"total bytes={total/1e6:.1f} MB")
print("\n== by extension ==")
for k, v in ext.most_common(15):
    print(f"  {k:12s} {v}")
print("\n== by top dir ==")
for k, v in top.most_common(15):
    print(f"  {k:24s} {v}")

keys = ["project.godot", "scenes/boot/boot.tscn", "scripts/boot/boot.gd",
        "scripts/core/game_manager.gd", "scripts/core/event_bus.gd",
        "scenes/menus/main_menu.tscn", "scripts/world/world.gd",
        "assets/textures/", "assets/characters/", "assets/ui/portraits/",
        ".godot/imported"]
print("\n== boot-chain presence ==")
present = {p for p, _, _, _ in files}
for k in keys:
    hits = [p for p in present if k in p]
    print(f"  {k:34s} {len(hits)}")

print("\n== largest files ==")
for p, o, s, fl in sorted(files, key=lambda x: -x[2])[:8]:
    print(f"  {s/1e6:8.2f} MB  {p}")
