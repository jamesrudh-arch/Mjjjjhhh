#!/usr/bin/env python3
"""Probe itch.io anonymous purchase flow; dump each step's HTML for analysis."""
import time, random, sys, requests
from bs4 import BeautifulSoup

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
S = requests.Session()
S.headers.update({"User-Agent": UA, "Referer": "https://itch.io/"})
DUMP = "/home/z/my-project/tools/itch_probe"

def dump(name, r):
    import os
    os.makedirs(DUMP, exist_ok=True)
    with open(f"{DUMP}/{name}.html", "w") as f:
        f.write(r.text)
    print(f"[{r.status_code}] {name} ({len(r.text)} b) -> {r.url}")

def slow(t=None):
    time.sleep(t or random.uniform(25, 35))

game = sys.argv[1] if len(sys.argv) > 1 else "https://kenney-assets.itch.io/car-kit"

r = S.get(game, timeout=30); dump("1_game", r)
r = S.get(game + "/purchase", timeout=30); dump("2_purchase", r)
soup = BeautifulSoup(r.text, "html.parser")
for form in soup.find_all("form"):
    act = form.get("action", "")
    fields = {i.get("name"): i.get("value", "") for i in form.find_all("input") if i.get("name")}
    print("FORM:", act, fields)
