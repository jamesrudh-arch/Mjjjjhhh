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

Machine summary of the final run is mirrored at `tests/last_run.txt` (regenerated at each suite run).

## Visual evidence (Verified level, headless GL where allowed)

`tests/render_out/` holds 7 distinct captures (md5-verified non-blank, 1280×720): 01 boot company card, 02 title, 03 content notice, 04 main menu, 05 intro cinematic, 06 world gameplay, 07 world gameplay late. Sandbox has no vision model this session; renders were verified programmatically (distinct hashes, 190–238 grey levels, correct dark-splash/bright-gameplay luminance profile). On-device look remains Device-only.

## Method notes

- Headless dummy renderer prints `Parameter "material" is null` ×2 during time.weather and "resources still in use at exit" on 4.7.2 — D4, cosmetic, identical in project and PCK runs.
- Audio correctness cannot be auditioned headless (no audio device) — AudioSystem logic + asset existence are Tested; listening is Device-only.
- Performance (fps/memory) is Device-only — no GPU in sandbox.
