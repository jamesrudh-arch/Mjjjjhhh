# LEVERAGE — Delivery Report (v2.5.0 "The Living City")

**Project:** LEVERAGE — "Everyone has leverage on you." Third-person open-world crime-action drama in Cinder City.
**Target:** Xogot on iPhone/iPad (the Godot EDITOR app by Xibbon, embedding Godot 4.7) — Mobile renderer.
**Date:** 2026-11-25. Built session 13; session 14 re-verified the entire tree from scratch, rebuilt the device zip, and committed + pushed everything. **State: DELIVERED + COMMITTED + PUSHED (repo main @ v2.5.0).**

---

## 1. What v2.5.0 is — the full-stack 10/10 pass

The mandate was widened from game-feel to the ENTIRE game: graphics, fonts,
animation, buildings, vehicles, filling stations, trains, camera, landscape,
rivers + full wildlife (fish, animals, birds, insects, rodents), music, SFX,
the DE YOUNG GAMES logo, a conversational intro that establishes the story,
fewer-but-deeper levels with rising difficulty and a real ending — "a world
on its own, a new entry in the DE YOUNG GAMES universe."

Shipped (details + evidence pointers in `leverage/docs/changelog.md` v2.5.0):

1. **The Cinder River** — carved terrain channel through the 48k-vert ground
   mesh, animated water shader (scrolling waves + sun glints + bank foam),
   stone parapets, 2 bridges with lamps, a marina with 3 bobbing boats,
   3 fish shoals that jump with splash SFX + particles, water-lap ambience.
2. **Wildlife** — pigeon flocks (peck/wander/flee-and-land), circling river
   gulls, night rats in the alleys, fireflies after dark, moths orbiting
   streetlights; gunfire scatters all of it.
3. **Two filling stations** (Dez Depot, East Strip) — canopy/pumps/kiosk/
   price totem, and the pumps are EXPLOSIVE: chained cinematic explosions
   with fire particles, shockwave ring, hit-stop, camera shake, radius damage.
4. **The Cinder Line train** — northern elevated viaduct, 2 platforms, a
   scheduled 5-car train (lit windows, headlight, horn, station bell,
   rumble) crossing east/west every 95 s.
5. **All 19 buildings rebuilt** from the Quaternius Downtown City MegaKit
   (CC0): real brick/metal/trim textures, custom window units with 35%
   warm-lit HDR night panes, storefront glass + canopies, NEON signs on
   every storefront, cornices, tiled roofs with AC units. Building payload
   29 MB → 5 MB. Closed the v2.4 latent defect where the night-emission
   ramp never ran (city geometry was parented to the wrong node).
6. **DE YOUNG GAMES animated ident** — DY monogram keyline draw-on, amber
   letter-by-letter wordmark illumination, glow pulse synced to a new
   audio sting. Branding standardized to "DE YOUNG GAMES" everywhere.
7. **Conversational intro** — camera flights over the live city while
   Rizzo and Dez actually talk (14 typewriter beats, portraits, Tommy's
   letter, the Ledger, an UNKNOWN CALLER threat), tap X to advance /
   hold X to skip, chapter card, then tutorialized entry.
8. **Difficulty director + deeper campaign** — chapter-scaled enemy
   HP/damage/count (1.0x → 1.9x by chapter 5, tier names on chapter
   cards); missions lengthened into multi-stage arcs; glowing world
   pickups for COLLECT objectives; chapter title cards on every mission.
9. **Cinematic fonts** (Anton + Oswald, OFL), **10 new original SFX**
   (train horn/rumble, station bell, water lap, splash, gull, pigeon
   flutter, crickets, ident sting, cinematic explosion), **blue-noir
   night look**, lane markings on every road, story bible
   (`docs/story_bible.md`) framing the DE YOUNG GAMES universe.

## 2. Session-14 zero-assumption re-verification

- **4.7.2 (Xogot's engine), fresh import:** 452/452 checks, 0 failed.
- **4.4.1, fresh import:** 452/452 checks, 0 failed, 0 SCRIPT ERRORs.
- **From-pack:** the shipped `LEVERAGE_2.5.0.pck` (31,801,872 B) runs the
  full suite via `--main-pack`: 401/401, 0 failed (51 project-dir-only
  enumeration checks don't apply in pack mode — same as every version).
- **Device zip integrity:** `LEVERAGE_v2.5.0_XOGOT_project.zip`
  (122,732,533 B, 2,352 files) extracted to a clean dir and imported by
  4.7.2: exit 0, 0 errors — the pre-imported cache is accepted.
- **Render evidence:** 14-shot battery from the real boot flow (ident,
  title, menu, river/bridge, dusk streets with lane markings + peds,
  train station with lit train, gas station, neon night close-ups,
  building beauty shot) in `docs/evidence/session13/`, VLM-verified
  (changelog v2.5.0); spot-checked on disk this session.
- Suite history: 215 → 238 → 257 → 288 → 334 → 379 → **452 checks**;
  PCK 44.16 MB → **31.8 MB** (buildings payload 29 → 5 MB).

## 3. Deliverables (all in `download/`, checksums in `CHECKSUMS.txt`)

| File | Size | For |
|---|---|---|
| `LEVERAGE_v2.5.0_XOGOT_project.zip` | 122,732,533 B | **iPhone/iPad + Xogot — use this one** |
| `LEVERAGE_2.5.0.pck` | 31,801,872 B | Desktop Godot 4.4–4.6 (`--main-pack`) |
| `LEVERAGE_hello_diag_project.zip` | 5,818 B | Delivery-chain diagnostic (try first if anything misbehaves) |
| `LEVERAGE_v2.4.0_Audit_and_WorldClass_Report.pdf` | — | Session-11 audit record (history) |
| `README.md`, `CHECKSUMS.txt`, this report | — | Docs |

GitHub `jamesrudh-arch/Mjjjjhhh` main carries the full project + docs +
PCK + this report (zips over 100 MB stay sandbox-delivery only — GitHub
hard cap). Stale v2.3.x/v2.4.0 artifacts were purged; `download/` holds
the current set only.

## 4. How to install (short version)

1. Files app → tap `LEVERAGE_v2.5.0_XOGOT_project.zip` ONCE (iOS extracts).
2. Xogot → open the extracted FOLDER (never the zip) → Play.
3. Expected: DE YOUNG GAMES ident → LEVERAGE title → notice → main menu
   (v2.5.0 footer). See `FIRST_READ.txt` (inside the zip) for the full
   checklist and the in-game tour (river, train, gas pumps, night).

## 5. Honest limits

- On-device performance/thermals and Xogot's import behavior remain
  Device-only (sandbox has no iPhone). The zip carries a 4.7.2-native
  cache to make the first open fast.
- Sandbox renders use software rasterizers (llvmpipe/OpenGL3) — device
  GPU output will look better, not worse.
- The suite proves code paths and invariants; "fun" is judged on the
  device. Session-14's recommendation list (in the chat reply) is the
  pre-testing punch list for the next pass.

— DE YOUNG GAMES. Everyone has leverage on you.
