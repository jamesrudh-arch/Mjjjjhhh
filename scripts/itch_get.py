#!/usr/bin/env python3
"""Anonymous itch.io free-download downloader using /download_url endpoint.
Paced against 429s. Saves zips to tools/assets_raw/itch_<pack>/."""
import time, random, sys, os, re, json
import requests
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
DUMP = "/home/z/my-project/tools/itch_probe"
OUT = "/home/z/my-project/tools/assets_raw"
S = requests.Session()
S.headers.update({"User-Agent": UA})


def slow(t=None):
    time.sleep(t or random.uniform(45, 75))


def robust(fn, *a, **kw):
    """Retry with long backoff on 429/5xx."""
    delays = [90, 180, 300, 420]
    for attempt in range(5):
        try:
            r = fn(*a, **kw)
            if r.status_code == 429 or r.status_code >= 500:
                d = delays[min(attempt, len(delays) - 1)]
                print(f"  [429/{r.status_code}] backing off {d}s", flush=True)
                time.sleep(d)
                continue
            return r
        except Exception as e:
            print(f"  [net-err] {e}; retrying", flush=True)
            time.sleep(30)
    return None


def dump(name, r):
    os.makedirs(DUMP, exist_ok=True)
    with open(f"{DUMP}/{name}.html", "w") as f:
        f.write(r.text)
    print(f"  [{r.status_code}] {name} ({len(r.text)} b) -> {r.url}", flush=True)


def download_stream(rr, dest_dir, label):
    ct = rr.headers.get("content-type", "")
    if "text/html" in ct:
        print(f"  [ERROR] html not binary: {label}", flush=True)
        return False
    cd = rr.headers.get("content-disposition", "")
    fn = ""
    if cd:
        m = re.search(r'filename="?([^";]+)"?', cd)
        if m:
            fn = m.group(1)
    if not fn:
        fn = re.sub(r"[^a-zA-Z0-9._-]", "_", label) + ".zip"
    path = os.path.join(dest_dir, fn)
    total = 0
    with open(path, "wb") as f:
        for chunk in rr.iter_content(1 << 16):
            f.write(chunk)
            total += len(chunk)
    print(f"  [saved] {fn} ({total/1e6:.1f} MB)", flush=True)
    return total > 1000


def get_pack(game_url, pack_name):
    dest = os.path.join(OUT, "itch_" + pack_name)
    os.makedirs(dest, exist_ok=True)
    print(f"== {pack_name}: {game_url}", flush=True)
    # 1. game page: cookies + csrf
    r = robust(S.get, game_url, timeout=30)
    if r is None or r.status_code != 200:
        print(f"  [ERROR] game page {getattr(r,'status_code',None)}", flush=True)
        return False
    soup = BeautifulSoup(r.text, "html.parser")
    meta = soup.find("meta", attrs={"name": "csrf_token"})
    if not meta:
        print("  [ERROR] no csrf (may be paid-only pack)", flush=True)
        return False
    csrf = meta.get("value", "")
    slug = game_url.rstrip("/").split("/")[-1]
    slow()
    # 2. POST /<slug>/download_url
    r = robust(S.post, f"{game_url}/download_url",
               data={"csrf_token": csrf, "reward_id": ""}, timeout=60)
    if r is None:
        return False
    print(f"  download_url [{r.status_code}] {r.text[:200]}", flush=True)
    if r.status_code != 200:
        return False
    try:
        j = r.json()
    except Exception:
        return False
    if "url" not in j:
        print(f"  [ERROR] no url: {j}", flush=True)
        return False
    dl = j["url"]
    slow()
    # 3. fetch the download url (may be a page with more links, or direct file)
    r = robust(S.get, dl, timeout=60, allow_redirects=False)
    if r is None:
        return False
    if r.status_code in (301, 302, 303, 307):
        loc = r.headers.get("location", "")
        print(f"  -> redirect {loc[:100]}", flush=True)
        slow()
        r2 = S.get(loc, stream=True, timeout=600)
        return download_stream(r2, dest, pack_name)
    # page with upload links?
    if "text/html" in r.headers.get("content-type", ""):
        soup = BeautifulSoup(r.text, "html.parser")
        links = [a["href"] for a in soup.find_all("a", href=True)
                 if "download" in a["href"] or "itch.zone" in a["href"] or "itchcdn" in a["href"]]
        print(f"  page links: {links[:5]}", flush=True)
        for u in links:
            slow()
            rr = S.get(u, stream=True, timeout=600)
            if download_stream(rr, dest, u.split("/")[-2] if u.endswith("/") else u.split("/")[-1]):
                return True
        return False
    return download_stream(r, dest, pack_name)


PACKS = {
    "car_kit": "https://kenney-assets.itch.io/car-kit",
    "city_kit_suburban": "https://kenney-assets.itch.io/city-kit-suburban",
    "city_kit_industrial": "https://kenney-assets.itch.io/city-kit-industrial",
    "city_kit_roads": "https://kenney-assets.itch.io/city-kit-roads",
    "ual2": "https://quaternius.itch.io/universal-animation-library-2",
    "downtown_city_megakit": "https://quaternius.itch.io/downtown-city-megakit",
    "kenney_all_in_1": "https://kenney-assets.itch.io/kenney-game-assets-all-in-1",
}

if __name__ == "__main__":
    only = sys.argv[1:] or list(PACKS.keys())
    res = {}
    for k in only:
        try:
            res[k] = get_pack(PACKS[k], k)
        except Exception as e:
            print(f"  [PACK-ERROR] {k}: {e}", flush=True)
            res[k] = False
        time.sleep(random.uniform(8, 15))
    with open(os.path.join(OUT, "itch_results.json"), "w") as f:
        json.dump(res, f, indent=1)
    print(json.dumps(res, indent=1), flush=True)
