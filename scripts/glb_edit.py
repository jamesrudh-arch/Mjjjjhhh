#!/usr/bin/env python3
"""glb_edit.py - GLB surgery utilities for LEVERAGE asset passes.

Operations:
  replace-image : swap an embedded image's bytes in a GLB (D12 billboard fix)
  externalize   : extract embedded images to shared files + rewrite GLB to
                  reference them by URI; compacts the BIN chunk so the GLB
                  shrinks (character texture dedup, PCK size cut)

GLB format: magic 'glTF', version 2, then chunks (JSON, BIN). All offsets
4-byte aligned. Pure stdlib + PIL for PNG generation.
"""
import io
import json
import os
import struct
import sys
import hashlib


def read_glb(path):
    d = open(path, "rb").read()
    assert d[:4] == b"glTF", f"{path}: not a GLB"
    version, total = struct.unpack_from("<II", d, 4)
    assert version == 2, f"{path}: glTF version {version}, expected 2"
    off = 12
    js = None
    bin_chunk = None
    while off < len(d) - 8:
        clen, ctype = struct.unpack_from("<II", d, off)
        payload = d[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:  # 'JSON'
            js = json.loads(payload)
        elif ctype == 0x004E4942:  # 'BIN'
            bin_chunk = payload
        off += 8 + clen
    assert js is not None, f"{path}: no JSON chunk"
    return js, bin_chunk if bin_chunk is not None else b""


def write_glb(path, js, bin_data):
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    pad_json = (4 - len(js_bytes) % 4) % 4
    js_bytes += b" " * pad_json
    pad_bin = (4 - len(bin_data) % 4) % 4
    bin_out = bin_data + b"\x00" * pad_bin
    total = 12 + 8 + len(js_bytes) + 8 + len(bin_out)
    out = bytearray()
    out += b"glTF" + struct.pack("<II", 2, total)
    out += struct.pack("<II", len(js_bytes), 0x4E4F534A) + js_bytes
    out += struct.pack("<II", len(bin_out), 0x004E4942) + bin_out
    with open(path, "wb") as f:
        f.write(bytes(out))


def image_bytes(js, bin_data, image_idx):
    """Return the raw bytes of an embedded image."""
    img = js["images"][image_idx]
    if "bufferView" not in img:
        return None  # already external
    bv = js["bufferViews"][img["bufferView"]]
    off = bv.get("byteOffset", 0)
    return bin_data[off: off + bv["byteLength"]]


def material_image_indices(js, material_name):
    """Map a material name -> list of image indices used by its textures."""
    out = []
    for m in js.get("materials", []):
        if m.get("name") != material_name:
            continue
        pbr = m.get("pbrMetallicRoughness", {})
        for key in ("baseColorTexture", "metallicRoughnessTexture"):
            tref = pbr.get(key)
            if tref is None:
                continue
            tex = js["textures"][tref["index"]]
            if "source" in tex:
                out.append(tex["source"])
        for key in ("normalTexture", "emissiveTexture", "occlusionTexture"):
            tref = m.get(key)
            if tref is None:
                continue
            tex = js["textures"][tref["index"]]
            if "source" in tex:
                out.append(tex["source"])
    return out


def replace_image(path, image_idx, new_bytes):
    """Replace an embedded image's bytes; keeps bufferView lengths valid by
    padding/truncating is NOT allowed - instead rebuilds BIN layout."""
    js, bin_data = read_glb(path)
    img = js["images"][image_idx]
    assert "bufferView" in img, "image is already external"
    bvi = img["bufferView"]
    bv = js["bufferViews"][bvi]
    off = bv.get("byteOffset", 0)
    old_len = bv["byteLength"]
    # easiest correct path: same-length replacement when sizes match; else
    # rebuild all offsets (handled by externalize-style compaction below)
    if len(new_bytes) == old_len:
        bin_data = bin_data[:off] + new_bytes + bin_data[off + old_len:]
        write_glb(path, js, bin_data)
        return old_len
    # different length: full rebuild of bufferView offsets
    return _rebuild_with_image(path, js, bin_data, bvi, new_bytes)


def _rebuild_with_image(path, js, bin_data, image_bvi, new_bytes):
    """Rebuild BIN with one image's bytes replaced (length may differ)."""
    bvs = js["bufferViews"]
    # what uses each bufferView
    used = {}
    for acc in js.get("accessors", []):
        if "bufferView" in acc:
            used.setdefault(acc["bufferView"], []).append("acc")
    for i, im in enumerate(js.get("images", [])):
        if "bufferView" in im:
            used.setdefault(im["bufferView"], []).append(f"img{i}")
    new_bin = bytearray()
    new_offsets = {}
    for i, bv in enumerate(bvs):
        off = bv.get("byteOffset", 0)
        ln = bv.get("byteLength", 0)
        if i == image_bvi:
            data = new_bytes
        else:
            data = bin_data[off: off + ln]
        while len(new_bin) % 4 != 0:
            new_bin += b"\x00"
        new_offsets[i] = len(new_bin)
        bv["byteOffset"] = len(new_bin)
        bv["byteLength"] = len(data)
        new_bin += data
    js["buffers"][0]["byteLength"] = len(new_bin)
    write_glb(path, js, bytes(new_bin))
    return len(new_bin)


def externalize_images(path, out_dir, keep_prefix):
    """Extract ALL embedded images; write unique content to out_dir; rewrite
    the GLB to reference them by URI; compact the BIN. Returns bytes saved."""
    js, bin_data = read_glb(path)
    if not js.get("images"):
        return 0
    os.makedirs(out_dir, exist_ok=True)
    base = os.path.basename(path)
    written = {}  # image_idx -> (filename, bytes)
    for i, img in enumerate(js["images"]):
        if "bufferView" not in img:
            continue  # already external
        data = image_bytes(js, bin_data, i)
        if data is None:
            continue
        h = hashlib.md5(data).hexdigest()[:16]
        mime = img.get("mimeType", "image/png")
        ext = {"image/png": ".png", "image/jpeg": ".jpg"}.get(mime, ".png")
        fname = f"{keep_prefix}_{h}{ext}"
        fpath = os.path.join(out_dir, fname)
        if not os.path.exists(fpath):
            with open(fpath, "wb") as f:
                f.write(data)
        written[i] = (fname, data)
    if not written:
        return 0
    # determine bufferViews still in use (accessors + remaining embedded images)
    image_bvis = {img["bufferView"] for i, img in enumerate(js["images"])
                  if "bufferView" in img and i in written}
    used_bvis = set()
    for acc in js.get("accessors", []):
        if "bufferView" in acc:
            used_bvis.add(acc["bufferView"])
    for i, img in enumerate(js["images"]):
        if "bufferView" in img and i not in written:
            used_bvis.add(img["bufferView"])
    # rewrite image entries as URI references
    for i, (fname, _data) in written.items():
        js["images"][i] = {"uri": f"shared/{fname}"}
    # compact BIN: copy only used bufferViews, in original offset order
    old_size = len(bin_data)
    bvs = js["bufferViews"]
    order = sorted(range(len(bvs)), key=lambda k: bvs[k].get("byteOffset", 0))
    new_bin = bytearray()
    for k in order:
        if k not in used_bvis:
            continue
        bv = bvs[k]
        off = bv.get("byteOffset", 0)
        ln = bv.get("byteLength", 0)
        while len(new_bin) % 4 != 0:
            new_bin += b"\x00"
        bv["byteOffset"] = len(new_bin)
        new_bin += bin_data[off: off + ln]
    # drop unused bufferViews entries entirely (cleaner JSON) + remap accessors
    kept = [k for k in order if k in used_bvis]
    old_to_new = {orig: new for new, orig in enumerate(kept)}
    js["bufferViews"] = [bvs[k] for k in kept]
    for acc in js.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = old_to_new[acc["bufferView"]]
    js["buffers"][0]["byteLength"] = len(new_bin)
    write_glb(path, js, bytes(new_bin))
    return old_size - len(new_bin)
