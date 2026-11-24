# LEVERAGE — Delivery Report (v2.4.0 "Alive City")

**Project:** LEVERAGE — "Everyone has leverage on you." Third-person open-world crime-action drama in Cinder City.
**Target:** Xogot on iPhone/iPad (the Godot EDITOR app by Xibbon, embedding Godot 4.7) — Mobile renderer.
**Date:** 2026-11-24. Built session 10; **session 11 re-verified everything from scratch and hardened the delivery; session 12 re-verified the suite again live and pushed to GitHub. State: DELIVERED + COMMITTED + PUSHED.**

---

## 1. What happened in sessions 11–12

The user said "Go" on the full pipeline. The sandbox had recycled again
(Godot binaries + lavapipe wiped), so the toolchain was rebuilt first
(official GitHub releases, Godot 4.4.1 + 4.7.2, into gitignored `tools/`),
then the entire audit-test-verify battery was re-run on the v2.4.0 tree
with zero assumptions, and the delivery was hardened:

1. **Re-verification (all fresh this session)**:
   - 4.4.1 clean-room: fresh import → **379/379, 0 failed, 0 SCRIPT
     ERROR** → PCK re-export (44,159,440 B) → **335/335 from-pack**.
   - 4.7.2 (Xogot's engine), main tree: fresh import → **379/379, 0 failed**.
   - Real-boot render battery on 4.7.2 Forward Mobile + lavapipe: boot
     cards → menu, all frames non-black (95%); VLM on the menu frame:
     "no obvious rendering problems — text crisp and legible, scene
     renders fully" (title, NEW GAME/SETTINGS/CREDITS, key art).
   - `world_shot` gameplay: 76% non-black frames, VLM reads the full HUD
     (minimap + objective marker, $250, joystick, A/B/X/Y, PHONE VOICE
     dialogue) and the third-person player in a yellow jacket.
   - Numbers identical to session 10 — the tree had not drifted.
2. **A real hole was found and closed — the git state**: the session-10
   report claimed v2.4.0 was "committed locally (cdb7380)". Reflog audit
   this session proved **no such commit ever existed** (the session ran out
   of context before committing); 395 files of v2.4.0 work sat uncommitted
   on top of v2.3.1 (07a4cc0). v2.4.0 + all session artifacts are now
   **committed to main for real this session** (see §6 for the push).
3. **New: `LEVERAGE_hello_diag_project.zip`** — a zero-dependency 5.8 KB
   diagnostic project (no assets, no autoloads; ColorRect + default font
   only). Verified on 4.7.2: import OK, real render 95% non-black, VLM
   reads "LEVERAGE HELLO DIAG" + the moving band + fps line verbatim, and
   the SHIPPED zip extracted to a clean directory boots instantly with the
   pre-imported cache accepted. It isolates the delivery chain from the
   game on your device — its FIRST_READ.txt triages the result.

## 2. What ships (in `download/`)

| Item | Purpose |
|---|---|
| **`LEVERAGE_v2.4.0_XOGOT_project.zip`** (106,802,448 B) | **The one you want.** Full project + pre-imported 4.7-native asset cache — Xogot's first open is fast and can't be killed mid-import. |
| **`LEVERAGE_hello_diag_project.zip`** (5,818 B) | 30-second delivery-chain test; try it first if anything misbehaves. |
| `LEVERAGE_2.4.0.pck` (44,159,440 B) | Desktop only, Godot 4.4–4.6: `godot --main-pack LEVERAGE_2.4.0.pck` |
| `LEVERAGE_v2.4.0_Audit_and_WorldClass_Report.pdf` | Full audit results + research + recommendations to 10/10 |
| `CHECKSUMS.txt` | SHA-256 + byte size of every file in download/ |
| `LEVERAGE_delivery_report.md` | This file |

Key checksums (full list in CHECKSUMS.txt; verify after transfer):
- XOGOT zip `sha256 = 10957c3bba816e48f3bb8f38bc13656bba3c566485e25283287b6fbc862af7cc` (106,802,448 B)
- PCK `sha256 = 449e5d512956cb320f494b8a436cf2a41b829af7a2bd14f70d637881ecf37b7a` (44,159,440 B)
- hello diag zip `sha256 = 5ae7680cf14a8119c235954b27600fdc0215e93247c4204f55f7d7e39900bcd3` (5,818 B)

GitHub `main` (`jamesrudh-arch/Mjjjjhhh`): v2.4.0 + all session artifacts
**committed and pushed to GitHub** (session 12). The push went out only
after a fresh in-turn re-verification: 379/379 on Godot 4.7.2 and 335/335
from the shipped PCK on 4.4.1 — identical to session 11. Note: the 102 MB
XOGOT zip itself is a sandbox-download deliverable only (GitHub caps files
at 100 MB); the repo carries the full project source under `leverage/`
plus the 44 MB desktop PCK, so a git clone opens in Xogot too (first open
just re-imports instead of using the pre-baked cache).

## 3. Verification evidence (session 11, all fresh)

- 379/379 + 335/335 as in §1; zero SCRIPT ERRORs anywhere.
- Render evidence this session: `scratch/render_s11/` (boot cards, menu ×2,
  world_10s, world_18s); session-10 evidence remains in
  `docs/evidence/session10/` (in-repo, in-zip).
- Known tooling note (D22): standalone `--check-only` audits report false
  compile errors for autoload-referencing scripts on both engines
  (identical in session 10) — the suite is the authoritative compile gate.
- Session 12 (push turn, all live): suite re-run on 4.7.2 → 379/379, 0
  failed; from-pack on 4.4.1 → 335/335, 0 failed; deliverable SHA-256s
  re-verified against CHECKSUMS.txt; then `git push origin main`.

## 4. Install — iPhone + Xogot (5 steps, in order)

1. Get `LEVERAGE_v2.4.0_XOGOT_project.zip` onto the iPhone (AirDrop / iCloud / Files).
2. **In Files, tap the zip ONCE to extract** → creates the project FOLDER.
   **Never open the zip itself in Xogot.**
3. Open Xogot → open that folder (or its `project.godot`). Version warning →
   continue. The pre-imported cache should make this quick; if your build
   re-imports, keep Xogot in the foreground until it finishes.
4. Press **Play** → D'YOUNGS GAMES card → LEVERAGE title → notice → **main
   menu with key art**. A few seconds of black first (shader compile) is normal.
5. In game, try the new stuff early: walk Old Quarter for a minute (a street
   encounter should find you), commit a crime and **escape the pursuit**
   (stars blink while they search; EVADED payoff when clear), and push to
   **5 stars for the helicopter**.

If launch still fails: run `LEVERAGE_hello_diag_project.zip` first (same
install steps — 30 seconds). Hello works + game fails = in-game problem on
your device: send the Xogot Output lines (they start with
"[LEVERAGE v2.4.0] boot start | Godot … | renderer … | OS …"). Hello also
fails = delivery/open issue (say exactly how you opened it). Xogot 1.7.12+
shows the launch-failure reason on its panel either way. Send iPhone model,
iOS version, Xogot version with any report.

## 5. What v2.4.0 added (full detail in the PDF report + repo changelog)

Street encounters director (mugging / drug deal / brawl / dropped stash with
witnesses → police heat), wanted-evasion loop (searching stars + EVADED flash
+ stinger), 5-star police helicopter (orbit + tracking searchlight + looping
rotor, keeps reporting sightings), mission medals (bronze/silver/gold, best
retained across replays), pedestrian panic (screams + cower), vehicle engine
sound restored (D20), PCK hygiene fixed (D21), four new original SFX.

## 6. Required user actions

1. **Play test v2.4.0 on device** (steps above) — the sandbox has proven
   everything it can; the remaining Device-only items (fps feel, audio
   audition, encounter tuning) need your iPhone.
2. The repo is **pushed to GitHub** (the PAT you re-sent worked). Since
   that token has been pasted into chat, rotate it when convenient:
   github.com → Settings → Developer settings → Personal access tokens →
   revoke it and create a fresh one for any future session.
3. Report anything that fails with the exact Xogot Output lines.

— D'YOUNGS GAMES. Everyone has leverage on you.
