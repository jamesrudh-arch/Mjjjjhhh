#!/usr/bin/env python3
"""Complete itch free-download flow: claim ($0 purchase) -> download page -> file."""
import time, sys, requests
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
game = "https://quaternius.itch.io/downtown-city-megakit"
upload_id = "17615373"
dest = "/home/z/my-project/tools/assets_raw/megakit.zip"

S = requests.Session()
S.headers.update({"User-Agent": UA, "Referer": game})

def paced(fn, *a, **kw):
    time.sleep(6)
    r = fn(*a, **kw)
    if r.status_code == 429:
        print("429, waiting 120s"); time.sleep(120)
        r = fn(*a, **kw)
    return r

r = paced(S.get, game, timeout=30); print("game:", r.status_code)
csrf = BeautifulSoup(r.text, "html.parser").find("meta", attrs={"name": "csrf_token"}).get("value")
r = paced(S.get, game + "/purchase", timeout=30); print("purchase page:", r.status_code)
csrf = BeautifulSoup(r.text, "html.parser").find("meta", attrs={"name": "csrf_token"}).get("value")
data = {"csrf_token": csrf, "price": "0", "email": "", "initiator": "popup",
        "source": "paypal", "medium": "default", "bp": "", "json": "true"}
r = paced(S.post, game + "/purchase", data=data, timeout=60, allow_redirects=False)
print("claim:", r.status_code, r.text[:80])
r = paced(S.post, game + "/download_url", data={"csrf_token": csrf, "reward_id": ""}, timeout=60)
print("download_url:", r.status_code)
url = r.json()["url"]
r = paced(S.get, url, timeout=60)   # download page = claim proof
print("dl page:", r.status_code, "game_download" in r.text)
r = paced(S.get, game + "/file/" + upload_id, timeout=60, allow_redirects=False, stream=True)
print("file:", r.status_code, r.headers.get("content-type", "?")[:40])
if r.status_code in (301, 302, 303, 307):
    loc = r.headers["location"]
    print("redirect ->", loc[:100])
    rz = S.get(loc, stream=True, timeout=1200)
    ct = rz.headers.get("content-type", "")
    print("final:", rz.status_code, ct[:40], rz.headers.get("content-length"))
    if "html" not in ct:
        total = 0
        with open(dest, "wb") as f:
            for c in rz.iter_content(1 << 16):
                f.write(c); total += len(c)
        print("SAVED", total, "bytes")
    else:
        print("HTML - failed")
