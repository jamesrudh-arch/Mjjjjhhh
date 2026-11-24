#!/usr/bin/env python3
"""Interactive itch download debug: get the game page, request download_url,
then fetch it and inspect where it leads."""
import re, time, requests
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
S = requests.Session()
S.headers.update({"User-Agent": UA})
game = "https://quaternius.itch.io/downtown-city-megakit"

r = S.get(game, timeout=30)
print("game:", r.status_code)
soup = BeautifulSoup(r.text, "html.parser")
csrf = soup.find("meta", attrs={"name": "csrf_token"}).get("value")
print("csrf ok")
time.sleep(3)

r = S.post(game + "/download_url", data={"csrf_token": csrf, "reward_id": ""}, timeout=60)
print("download_url:", r.status_code)
url = r.json()["url"]
print("url:", url[:120])
time.sleep(3)

# follow the signed url WITH the session (cookies matter)
r = S.get(url, timeout=60, allow_redirects=False)
print("fetch:", r.status_code, r.headers.get("content-type", "?"))
print("location:", r.headers.get("location", "-")[:140])
if r.status_code == 200 and "text/html" in r.headers.get("content-type", ""):
    # find actual file links on the page
    links = [a["href"] for a in BeautifulSoup(r.text, "html.parser").find_all("a", href=True)]
    for l in links[:20]:
        if any(k in l for k in ("itch.zone", "itchcdn", "download", ".zip")):
            print("LINK:", l[:160])
