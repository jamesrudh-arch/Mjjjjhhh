#!/usr/bin/env python3
"""Recursive public Google Drive folder downloader for Quaternius CC0 packs.
Fast quota-skip: on quota, wait 90s, retry once, then defer to a final pass.
Skips preview/license files. Two-phase: walk-all, then download."""
import re, sys, time, json, os, random
import requests
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
OUT_ROOT = "/home/z/my-project/tools/assets_raw"
S = requests.Session()
S.headers.update({"User-Agent": UA})

MANIFEST = {
    "animated_men": "17LibivOaUidsQhSkcxP3YYvDr0n7wIwu",
    "animated_women": "1c13R--fMqdR6r2MRlcKKsbPky0__T-yJ",
    "cars": "1fKlbDry77iY8KlEoxzUxIAZQL_XhzWlA",
    "modular_streets": "1-YvMpLDYBIy-0Ms7ZlFmUpChTbHku8IJ",
    "ultimate_guns": "12V-mHNB6bnW2WzgpJfRBQd-TG4pOO3yx",
    "ultimate_textured_buildings": "1RE3qXhbE5yGS3t-xGFJ8GmOtTgCUF3LQ",
    "ultimate_home_interior": "1SNK9PwPi8xqqxmpU5xEZeiQjB26C1oX6",
    "furniture": "1CLWStkb7cipC1ZdTunYJXKVqEVwtXWXK",
    "public_transport": "1GUIE138uPVNraiQEf33dIx9wENhttZ15",
    "simple_buildings": "1r-FcNFxC6ziN0oI3GqZJdEkdzglFQHQH",
}

SKIP_NAMES = ("preview", "license")


def list_folder(fid):
    url = f"https://drive.google.com/embeddedfolderview?id={fid}#list"
    r = S.get(url, timeout=30)
    soup = BeautifulSoup(r.text, "html.parser")
    files, folders = [], []
    for entry in soup.find_all("div", class_="flip-entry"):
        a = entry.find("a")
        if not a:
            continue
        href = a.get("href", "")
        name = a.get_text(strip=True)
        mf = re.search(r"/file/d/([a-zA-Z0-9\-_]+)", href)
        mo = re.search(r"/drive/folders/([a-zA-Z0-9\-_]+)", href)
        if mf:
            files.append((mf.group(1), name))
        elif mo:
            folders.append((mo.group(1), name))
    return files, folders


def walk_collect(folder_id, prefix, out, depth=0, max_depth=3):
    files, folders = list_folder(folder_id)
    for fid, name in files:
        if any(s in name.lower() for s in SKIP_NAMES):
            continue
        if name.lower().endswith((".zip", ".glb", ".gltf", ".fbx", ".bin")):
            out.append((fid, f"{prefix}/{name}"))
    if depth < max_depth:
        for sfid, sname in folders:
            if sname.lower().startswith(("blend", "source", "unity", "unreal", "sourcefiles", "obj")):
                continue
            walk_collect(sfid, f"{prefix}/{sname}", out, depth + 1, max_depth)
            time.sleep(random.uniform(1, 2))


def download_file(fid, name, dest_dir, quota_wait):
    dest = os.path.join(dest_dir, name.replace("/", "_"))
    if os.path.exists(dest) and os.path.getsize(dest) > 1000:
        return "exists"
    try:
        url = f"https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t"
        r = S.get(url, stream=True, timeout=600)
        ct = r.headers.get("content-type", "")
        if "text/html" in ct:
            txt = r.text[:300]
            if "Quota exceeded" in txt or "Too many users" in txt:
                if quota_wait > 0:
                    print(f"  [quota] {name}; waiting {quota_wait}s", flush=True)
                    time.sleep(quota_wait)
                    r = S.get(url, stream=True, timeout=600)
                    ct = r.headers.get("content-type", "")
                    if "text/html" in ct and ("Quota" in r.text[:300] or "Too many" in r.text[:300]):
                        return "quota"
                else:
                    return "quota"
            else:
                soup = BeautifulSoup(r.text, "html.parser")
                form = soup.find("form")
                if form is None:
                    print(f"  [ERROR] html no form for {name}: {txt[:80]!r}", flush=True)
                    return "error"
                post = form.get("action", "")
                if post.startswith("/"):
                    post = "https://drive.usercontent.google.com" + post
                data = {i["name"]: i.get("value", "") for i in form.find_all("input") if i.get("name")}
                r = S.post(post, data=data, stream=True, timeout=600)
        total = 0
        with open(dest, "wb") as f:
            for chunk in r.iter_content(1 << 16):
                f.write(chunk)
                total += len(chunk)
        if total > 1000:
            print(f"  [ok] {name} ({total/1e6:.1f} MB)", flush=True)
            return "ok"
        return "error"
    except Exception as e:
        print(f"  [err] {name}: {e}", flush=True)
        return "error"


def main():
    only = sys.argv[1:] if len(sys.argv) > 1 else list(MANIFEST.keys())
    manifest_files = []
    for pack in only:
        print(f"== walking {pack}", flush=True)
        try:
            walk_collect(MANIFEST[pack], pack, manifest_files)
        except Exception as e:
            print(f"  [WALK-ERROR] {pack}: {e}", flush=True)
        time.sleep(random.uniform(2, 4))
    print(f"== total {len(manifest_files)} files to download", flush=True)
    failed = []
    for fid, name in manifest_files:
        pack = name.split("/")[0]
        dest_dir = os.path.join(OUT_ROOT, pack)
        os.makedirs(dest_dir, exist_ok=True)
        st = download_file(fid, name, dest_dir, quota_wait=90)
        if st in ("quota", "error"):
            failed.append((fid, name))
        time.sleep(random.uniform(2, 5))
    # final retry pass for quota-blocked files with long waits
    if failed:
        print(f"== retrying {len(failed)} failed files with long waits", flush=True)
        for fid, name in failed:
            pack = name.split("/")[0]
            dest_dir = os.path.join(OUT_ROOT, pack)
            st = download_file(fid, name, dest_dir, quota_wait=420)
            if st in ("quota", "error"):
                print(f"  [STILL-FAILED] {name}", flush=True)
            time.sleep(random.uniform(30, 60))
    done = sum(1 for f in os.listdir(OUT_ROOT) if os.path.isdir(os.path.join(OUT_ROOT, f)))
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
