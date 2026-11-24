# LEVERAGE — Test Reports

Method: headless Godot (`tools/Godot_v4.4.1-stable_linux.x86_64` primary — the XOGOT-matching runtime; `tools/Godot_v4.7.2-stable_linux.x86_64` secondary) running `tests/run_tests.gd` with `LEVERAGE_TEST=1` on sandbox CPU (no GPU, dummy renderer). These runs prove code paths and game-logic invariants — "Tested" level. They are NOT iPhone/XOGOT verification (see final_verification_guide.md, Device-only).

## Run log

| Date | Suite | Result | Environment | Notes |
|---|---|---|---|---|
| 2026-11-23 s2 | all 8 suites | **PASS 215/215** | 4.4.1 project dir | first full green run |
| 2026-11-24 s10 (audit, pre-change) | all suites | **PASS 334/334** | 4.4.1 fresh `rm -rf .godot` + import | v2.3.2 re-verified from scratch — no assumptions carried |
| 2026-11-24 s10 (audit, pre-change) | all suites | **PASS 292/292** | 4.4.1 `--main-pack` (fresh export) | v2.3.2 from-pack re-verified |
| 2026-11-24 s10 (audit, pre-change) | all suites | **PASS 334/334** | 4.7.2 fresh import | v2.3.2 on Xogot's engine generation |
| 2026-11-24 s10 | + encounters.sim (12), police.evasion (7), peds.panic (5), police.air (6), missions.medals (4), audio.sfx block (7), +1 autoload | **PASS 379/379** | 4.4.1 fresh import | v2.4.0 "Alive City": encounters + evasion loop + air unit + medals + ped panic + D20/D21 fixes |
| 2026-11-24 s10 | all suites | **PASS 379/379** | 4.7.2 fresh import | v2.4.0 on Xogot's engine generation; zero SCRIPT ERRORs |
| 2026-11-24 s10 | all suites | **PASS 335/335** | 4.4.1 `--main-pack leverage.pck` (44.16 MB) | **from-pack proof for the shipped v2.4.0 PCK** (D21 exclusion applied; probe PNGs out) |
| 2026-11-23 s3 | all suites | **PASS 215/215** | 4.7.2 project dir | directive-version validation; exit-time resource warnings (D4, cosmetic) |
| 2026-11-23 s3 | + vehicles.motorcycle (12 checks) | **PASS 227/227** | 4.4.1 project dir | R13 closed: bikes spawn/enter/exit/lean validated |
| 2026-11-23 s3 | all suites | **PASS 238/238** | 4.4.1 project dir | final: + audio.radio suite (in-vehicle radio wiring) |
| 2026-11-23 s3 | all suites | **PASS 238/238** | 4.7.2 project dir | final directive-version run |
| 2026-11-23 s3 | all suites | **PASS 238/238** | 4.4.1 `--main-pack leverage.pck` | **package completeness proof**: full suite runs from the final exported PCK |
| 2026-11-23 s4 | all suites + phone.system + map.gps | **PASS 257/257** | 4.4.1 project dir | v2.0.0 visual overhaul validation |
| 2026-11-23 s5 | all suites | **PASS 257/257** | 4.4.1 project dir + `--main-pack` | v2.1.0 combat feel pass; Mobile renderer verified via lavapipe (TDL #25) |
| 2026-11-23 s6 | all suites | **PASS 257/257** | 4.4.1 project dir + `--main-pack` | v2.2.0 cinematic/audio/PCK-dedup close-out |
| 2026-11-23 s7 | + presentation.cinematic, traffic.motorcycles, world.interiors; rider checks in vehicles.traffic / vehicles.motorcycle | **PASS 288/288** | 4.4.1 project dir | v2.3.0: rider + bike traffic + interiors + fades; also fixed latent v2.1/v2.2 runtime errors (combat particle `mesh` property, overlay signal arity/owner) |
| 2026-11-23 s7 | all suites | **PASS 288/288** | 4.4.1 `--main-pack leverage.pck` | **from-pack proof for the shipped v2.3.0 PCK (45.6 MB)** |

Machine summary of the final run is mirrored at `tests/last_run.txt` (regenerated at each suite run; from-pack runs cannot rewrite it — read the stdout summary).

## Visual evidence (Verified level, headless GL where allowed)

Session 7 evidence lives in `docs/evidence/session7/` (probe PNGs are kept OUT of res:// and out of the PCK — `tests/render_out/` is a scratch dir, gitignored):
- `rider_bike_q34 / rider_car_q34` — seated rider stand-in on motorcycle and sedan (VLM-verified: astride/forward-facing; head below roofline at tuned seat y=0.20).
- `clay_sedan_side` — unlit clay pass proving sedan silhouette solidity 0.838 (objective counter-evidence to D16 VLM oscillation).
- `m_02_world_fadein … m_09_keyart_clean` — full real-flow capture under Forward Mobile/lavapipe: fade-in telemetry (alpha 1.0 → 0.46 → 0.0), menu freed on game start, pedestrians mid-stride (D13), rider in-world, HUD-free dusk key-art source (D9).
- `menu_new_keyart` — new menu key art rendered in-scene; re-rendered **from the exported PCK** under Forward Mobile (VLM PASS).

Sandbox has no vision model in-loop during suite runs; captures are VLM-reviewed separately and cross-checked with pixel/objective metrics (D10/D16 discipline). On-device look remains Device-only.

## Method notes

- Headless dummy renderer prints `Parameter "material" is null` ×2 during time.weather and "resources still in use at exit" on 4.7.2 — D4, cosmetic, identical in project and PCK runs.
- Audio correctness cannot be auditioned headless (no audio device) — AudioSystem logic + asset existence are Tested; listening is Device-only.
- Performance (fps/memory) is Device-only — no GPU in sandbox.

## Session 9 (v2.3.2) — full fresh-sandbox re-verification

Fresh tools (Godot 4.7.2 + 4.4.1 re-downloaded), fresh extraction of the shipped zip, no state carried from session 8:

- **Fresh zip → 4.7.2 first-open import**: 21 s wall, 788 resources, 0 errors.
- **Suite on fresh extraction**: 4.7.2 `334 checks, 0 failed`; 4.4.1 (own clean import) `334 checks, 0 failed`.
- **Repo (fixed scripts)**: 4.7.2 `334/0`; 4.4.1 clean-import `334/0`; 4.4.1 stale-cache run exposed the cross-generation hazard (39 fails, clean re-import → 0; documented in decision #33).
- **From-pack (`--main-pack leverage.pck`)**: 4.4.1 `292 checks, 0 failed`; 4.7.2 **crashes by design scope** — D19: 4.4-built binary GDScript tokens rejected (upstream segfault); PCK labeled 4.4–4.6 desktop.
- **New `scripts.parse` suite**: 44 scripts compile-checked in the real autoload context + 2 assertions; pack-mode falls back to explicit loads of phone.gd/pause_menu.gd/hud.gd/boot.gd.
- **Render (4.7.2 Forward Mobile, Vulkan 1.4.305 lavapipe, Xvfb :99, 1280x720)**: real game boot — `[LEVERAGE v2.3.2] boot start | Godot 4.7.2-stable | renderer=mobile | OS=Linux | mem=43 MB` → `boot cards done -> main menu`; frames captured at 5/8/20/27/34 s: title card, content notice, main menu with 3D key art + menu panel (VLM-verified: "real rendered content", menu stable; late captures byte-identical 393,540 B with X-sync before grab — without the X round-trip ffmpeg x11grab can return a stale black frame, capture artifact only, game unaffected).
- **Menu idle stability probe**: captures at 12/18/24/30/40/55 s all byte-identical, process alive, no script errors.
- **Present-path quirk isolated (not a game defect)**: with `VK_DRIVER_FILES` (llvmpipe) the game renders real content but x11grab can return black root pixels at late times (llvmpipe present path; flaky, wandered between runs). With no ICD override the engine cleanly falls back to OpenGL 3 and every capture out to 32 s is a full menu frame — `s9_05_menu_from_final_zip.png` (VLM: "real rendered main menu", key art + NEW GAME/SETTINGS) comes from the FINAL SHIPPED ZIP on that path. Device GPUs present via the real window system; the quirk is sandbox visualization only.
- **World render under llvmpipe still stalls on first-frame shader compile (known sandbox limitation — session 7 note; device GPUs unaffected); world build itself is covered headlessly** (city/world/pedestrian/combat suites inside the 334).
- Evidence: `docs/evidence/session9/` (title card, notice card, main menu ×2 stability pair).
