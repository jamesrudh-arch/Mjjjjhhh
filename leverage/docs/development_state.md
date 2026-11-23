# LEVERAGE — Development State

**THE authoritative status document. Read this first when resuming work.**
Project root: `leverage/` (single authoritative project — no backups, no duplicates).
Status taxonomy: **Implemented** (code exists) / **Tested** (verified by automated headless run) / **Verified** (rendered and visually confirmed) / **Device-only** (requires iPhone + XOGOT hardware; never claimed from sandbox).

Last updated: 2026-11-23 (session 5 — COMBAT FEEL / "JUICE" PASS). **State: v2.1.0 — game feel upgraded, PCK re-exported and validated from-pack.**

## Session 5 — what shipped (all in the authoritative project, no backups)

1. **Combat juice (P0)**: `combat_feel.gd` static helpers — hit-stop, slow-mo, pooled impact particles. Player connects now hit-stop + camera-kick + shake + particles (scaled by damage); throws slow-mo + FOV punch-in; counters get hit-stop + sfx. Enemy brain rewritten: attack tokens (2 max), circle/flank, telegraphed wind-ups (readable counters), knockdown→lie→Roll get-up (×2 vulnerable), wounded retreat + shout, weapon reload every 3rd strike, discipline flavor. Cinematic last-enemy slow-mo finisher.
2. **Movement/world (P1/P2)**: footsteps by gait, sprint FOV kick, ped target 25→50 with idle variety (conversations, phone poses).
3. **Verification upgraded**: 257/257 on 4.4.1 in project dir AND from the fresh PCK. **Mobile renderer now renderable in sandbox** via user-local Mesa lavapipe Vulkan ICD (`tools/vulkan-deb/`, `VK_DRIVER_FILES=...lavapipe_icd.json`) — TDL #25; fresh Mobile-renderer gameplay capture VLM-verified.
4. User "gray screen" report investigated: shipped v2 PCK boots + renders correctly under BOTH opengl3 and Mobile/lavapipe from the pack (probe frames VLM-verified). Likely user-side causes: loading the raw project (needs `--import` first — cache is gitignored) or first-run 77 MB PCK load time. Fresh `download/LEVERAGE_2.0.0.pck` exported & validated.


## Environment facts (verified)

- Sandbox: Debian 13 (trixie) x86_64, 2 cores, ~4 GB RAM, ~6 GB free disk.
- Godot **4.7.2-stable** AND **4.4.1-stable** Linux binaries at `tools/` (headless works on both).
- Blender **4.5.9 LTS** at `tools/blender-4.5.9-linux-x64/` (sourceless .pyc restore documented in TDL #24; run with `env -u PYTHONHOME -u PYTHONPATH`).
- XOGOT runtime is Godot-4.4-based; project targets the **4.4-compatible API subset** so one PCK runs under XOGOT and stays openable in 4.7. All headless tests run on **Godot 4.4.1**.
- Mobile renderer is the rendering method (`renderer/rendering_method="mobile"`).

## Session 4 — what was rebuilt (the overhaul)

User verdict on v1: "totally trash." Independent VLM audit agreed ("low-poly mobile prototype"). Everything below was rebuilt IN the authoritative project (no backups, no duplicates):

1. **PBR texture forge** (Implemented): 17 texture sets (asphalt+markings, crosswalk, brick x2, concrete/panel, pavement, cotton/denim/leather/skin, leaf/bark/grass, metal, storefront) via `scripts/build_textures.py`.
2. **Realistic human cast** (Implemented + Tested + sandbox-Verified at gameplay distance): 28 authored bodies (procedural anatomy, faces with eyes/lids/brows/nose/lips/ears, hair styles, beards, layered clothing, per-character skin tones + outfits) skinned to the UAL DEF-* rig with deterministic proximity skinning (`scripts/build_character.py`, `scripts/char_specs.json`). Runtime: mannequin scene (57 animations) + mesh/skin swap (`character_factory.gd` v2). Fixed animation name discovery (importer strips `_Loop`).
3. **Detailed vehicles** (Implemented): 8 authored vehicles (sedan/hatch/SUV/coupe x2/taxi/police + motorcycle) — unified hull with region glass, wheel arch cutouts, detailed wheels, lights, grille, bumpers, mirrors, interior, lightbars (`scripts/build_vehicle.py`). Wheels are separate nodes (ready for spin/steer).
4. **Authored architecture** (Implemented): 19 building variants across 5 district styles (brick/warehouse/tower/shopfront/house) with inset windows, doors, cornices, storefront awnings + emissive signs, roof junk, pitched roofs (`scripts/build_building.py`).
5. **Street props** (Implemented): 13 authored props (3 trees, 2 streetlights, traffic light, hydrant, bin, bench, bus stop, billboard, dumpster, barrier) — `scripts/build_props.py`.
6. **City v2** (`city_builder.gd` rewritten): 28-road network shared by traffic/police/GPS, textured roads + curbs + sidewalks + crosswalks, district-biased buildings (window emission ramps at night), streetlights with 8 player-following night omnis, trees, parked cars (up to 400), slot-probability street furniture. Road-graph islands fixed (ironworks/neon/heights connect).
7. **Cinematic environment**: procedural sky, day/night sun + sky grading, warm fog, ACES tonemap (`world.gd`).
8. **Living phone** (`phone_system.gd` + `phone.gd` + `call_banner.gd`): real incoming calls (ringtone loop, banner with ANSWER/DECLINE, portraits), dialogue subtitles, declined/missed consequences (voicemail + one reschedule), per-contact threads with game-hour timestamps + unread + quick replies, call log, outgoing calls with voicemail rules, story-driven scheduling (mission completion → next giver calls/texts). Saved in GameState.
9. **World map + GPS** (`map_screen.gd` rewritten): A* routing over the road graph, tap-to-select locations (shops/interiors/landmarks/mission), SET ROUTE → amber route line + HUD compass arrow + distance readout, zoom/pan/fog-of-war, live player + police + pulsing mission markers.
10. **Menu key art** (Implemented + Verified): cinematic composed-from-gameplay dusk cityscape behind the main menu (vignette + grade).

## Test status (session 4)

- **257/257 automated checks PASS** on 4.4.1 (`tests/last_run.txt`), including new suites `phone.system` (ring/answer/decline/idempotency/threads) and `map.gps` (A* routes over the road graph).
- Campaign: all 13 story missions + endings resolve end-to-end in the mission-journey suite.
- Visual evidence: fresh 1080p captures in `tests/render_out/` (boot, title, menu w/ key art, intro, gameplay x2) + cast/vehicle/portrait probes. Independent VLM final verdict on presentation: **7/10 vs the original graybox** (was 2-3/10).
- Render probes: `char_probe.tscn`, `cast_probe.tscn`, `veh_probe.tscn`, `portrait_probe.gd`, `keyart_probe.gd` — re-run after any asset change WITH `scripts/reimport.sh` first (non-editor runs use the last import; stale cache caused false "broken" renders twice this session).

## Open work / backlog (recorded, not dropped)

- **Device-only**: everything in `docs/final_verification_guide.md` (iPhone + XOGOT install/run checklist, fps/memory targets). Sandbox evidence never substitutes.
- PCK size 77 MB — texture dedup (28 char GLBs each embed their texture copies) is the top optimization; then LOD/visibility-range tuning for distant props.
- Vehicle close-up micro-polish (arch rims, panel gaps) — reads correctly at gameplay distance; flagged in `known_defects.md`.
- Character close-up micro-polish (hairline transitions, facial material variety) — passes at gameplay camera distance.
- VLM review scores oscillated 3→5→7 across identical-improving frames; treat pixel evidence + game-distance renders as authoritative, not single-frame macro reviews.

## Exact resumption point (for any future session)

1. Read this file, then `docs/visual_quality_audit.md`, then `docs/changelog.md`.
2. Re-verify: `tools/Godot_v4.4.1-stable_linux.x86_64 --headless res://tests/test_runner.tscn` (expect `257 checks, 0 failed`).
3. Re-render: `bash ../scripts/reimport.sh` then `Xvfb :99 & DISPLAY=:99 LEVERAGE_RENDER=1 tools/Godot_v4.4.1-stable_linux.x86_64 --rendering-driver opengl3 res://tests/render_probe.tscn`.
4. Asset rebuilds (Blender): `env -u PYTHONHOME -u PYTHONPATH tools/blender-4.5.9-linux-x64/blender -b --factory-startup -P scripts/build_<character|vehicle|building|props>.py -- <specs.json> [ids...]` — one import per Blender session; never `read_factory_settings` between exports (breaks the glTF addon).
5. New defects → `docs/known_defects.md` (never delete). New decisions → `docs/technical_decision_log.md` with sources. Status moves only with evidence.

## Rules of engagement (from directive)

- Never claim sandbox test = iPhone verification. iPhone/XOGOT checks are **Device-only**.
- No backups/duplicate projects; this directory is the single truth.
- Record technical decisions with sources; do not silently drop any requirement.
