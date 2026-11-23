#!/usr/bin/env python3
"""GLB structural validator: checks accessor/index sanity per mesh primitive.
Detects the broken-splice corruption mode (indices out of range, absurd
POSITION bounds, malformed bufferViews)."""
import json, struct, sys, os


def parse_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"glTF" or len(data) < 20:
        return None, None, "not a glb"
    ver, length = struct.unpack_from("<II", data, 4)
    clen, ctype = struct.unpack_from("<II", data, 12)
    if ctype != 0x4E4F534A:  # JSON
        return None, None, "first chunk not json"
    js = json.loads(data[20:20 + clen].decode("utf-8", "replace"))
    off = 20 + clen
    # pad
    while off % 4 != 0:
        off += 1
    blen, btype = struct.unpack_from("<II", data, off)
    bin_start = off + 8
    return js, data[bin_start:bin_start + blen], None


def validate(path):
    js, bindata, err = parse_glb(path)
    if err:
        return [f"{path}: PARSE FAIL {err}"]
    problems = []
    accs = js.get("accessors", [])
    bvs = js.get("bufferViews", [])
    meshes = js.get("meshes", [])
    total_pos = 0
    for mi, mesh in enumerate(meshes):
        for pi, prim in enumerate(mesh.get("primitives", [])):
            pos_idx = prim["attributes"]["POSITION"]
            pos_acc = accs[pos_idx]
            total_pos += pos_acc.get("count", 0)
            if "min" not in pos_acc or "max" not in pos_acc:
                continue
            mn, mx = pos_acc["min"], pos_acc["max"]
            span = [mx[i] - mn[i] for i in range(3)]
            if any(abs(v) > 100 for v in span):
                problems.append(f"mesh{mi} prim{pi}: POSITION span absurd {span}")
            if "indices" in prim:
                idx_acc = accs[prim["indices"]]
                im = idx_acc.get("max")
                if im is not None and im >= pos_acc["count"]:
                    problems.append(f"mesh{mi} prim{pi}: INDEX OOB max={im} verts={pos_acc['count']}")
            # bufferView sanity
            for key in ("indices",):
                if key in prim:
                    bv = bvs[accs[prim[key]]["bufferView"]]
                    need = accs[prim[key]]["count"] * {5123: 2, 5125: 4, 5126: 4}.get(accs[prim[key]]["componentType"], 1)
                    if bv["byteLength"] < need:
                        problems.append(f"mesh{mi} prim{pi}: bufferView too small {bv['byteLength']} < {need}")
    # accessors referencing beyond buffer
    if bindata is not None:
        for ai, a in enumerate(accs):
            if "bufferView" in a:
                bv = bvs[a["bufferView"]]
                end = bv.get("byteOffset", 0) + bv["byteLength"]
                if end > len(bindata):
                    problems.append(f"accessor{ai}: bufferView ends {end} > bin {len(bindata)}")
    return problems if problems else [f"OK ({len(meshes)} meshes, {total_pos} verts)"]


if __name__ == "__main__":
    targets = sys.argv[1:]
    for t in targets:
        if not os.path.exists(t):
            print(f"{t}: MISSING")
            continue
        for line in validate(t):
            print(f"{os.path.basename(t)}: {line}")
