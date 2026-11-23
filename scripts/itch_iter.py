#!/usr/bin/env python3
"""Iterate itch.io purchase: try corrected POST fields."""
import time, random, sys, requests, json
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
DUMP = "/home/z/my-project/tools/itch_probe"
S = requests.Session()
S.headers.update({"User-Agent": UA, "X-Requested-With": "XMLHttpRequest",
                  "Accept": "application/json, text/javascript, */*; q=0.01"})

game = sys.argv[1] if len(sys.argv) > 1 else "https://kenney-assets.itch.io/car-kit"

r = S.get(game, timeout=30); print("game", r.status_code)
time.sleep(25)
r = S.get(game + "/purchase", timeout=30)
soup = BeautifulSoup(r.text, "html.parser")
csrf = soup.find("meta", attrs={"name": "csrf_token"}).get("value")
with open(f"{DUMP}/iter_purchase.html", "w") as f: f.write(r.text)
time.sleep(25)
data = {"csrf_token": csrf, "price": "0", "email": "", "initiator": "popup",
        "source": "paypal", "medium": "default", "bp": "", "json": "true"}
r = S.post(game + "/purchase", data=data, allow_redirects=False, timeout=60)
print("POST", r.status_code, r.headers.get("content-type"))
print(r.text[:500])
if r.status_code == 200:
    try:
        j = r.json()
        print("JSON:", json.dumps(j)[:400])
    except Exception:
        pass
elif r.status_code in (301, 302, 303):
    print("redirect:", r.headers.get("location"))
