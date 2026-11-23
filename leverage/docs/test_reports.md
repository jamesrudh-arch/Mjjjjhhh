# LEVERAGE — Test Reports

Method: headless Godot (`tools/Godot_v4.4.1-stable_linux.x86_64` primary — the XOGOT-matching runtime; `tools/Godot_v4.7.2-stable_linux.x86_64` secondary) running `tests/run_tests.gd` with `LEVERAGE_TEST=1` on sandbox CPU (no GPU, dummy renderer). These runs prove code paths and game-logic invariants — "Tested" level. They are NOT iPhone/XOGOT verification (see final_verification_guide.md, Device-only).

## Run log

| Date | Suite | Result | Environment | Notes |
|---|---|---|---|---|
| 2026-11-23 s2 | all 8 suites | **PASS 215/215** | 4.4.1 project dir | first full green run |
| 2026-11-23 s3 | all suites | **PASS 215/215** | 4.4.1 project dir | audit re-verification (fresh) |
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
