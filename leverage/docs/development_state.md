# LEVERAGE — Development State

**THE authoritative status document. Read this first when resuming work.**
Project root: `leverage/` (single authoritative project — no backups, no duplicates).
Status taxonomy: **Implemented** (code exists) / **Tested** (verified by automated headless run) / **Verified** (rendered and visually confirmed) / **Device-only** (requires iPhone + XOGOT hardware; never claimed from sandbox).

Last updated: 2026-11-24 (session 11 — v2.4.0 RE-VERIFIED FROM SCRATCH + DELIVERY HARDENED + FALSE-COMMIT CORRECTED). **State: v2.4.0 — user-directed full audit re-verified v2.3.2 from scratch (334/334 both engines fresh imports, 292/292 from-pack, render battery), then five world-class upgrades shipped (street encounters, wanted-evasion loop + EVADED payoff, 5-star air unit, mission medals, ped panic) plus two real audit finds closed (D20 silent vehicle engines, D21 render-PNG PCK leak). Suite 334→379 checks; from-pack 335/335; PCK 44.16 MB; XOGOT zip + GitHub main are the delivery paths (D17/D19 standing).**

## Session 11 — re-verification, delivery hardening, hello diag, v2.4.0 actually committed

1. **Sandbox recycled again** (`tools/` + Godot binaries + lavapipe wiped; `scratch/` survived): Godot 4.4.1 + 4.7.2 re-downloaded from official GitHub releases into `tools/` (gitignored), mesa lavapipe debs re-extracted to `tools/mesa_vk`; system x11-utils/Xvfb/ffmpeg present. Recovery is now a documented one-liner (this entry + `scripts/verify_render.sh` header).
2. **Full audit-test-verify re-run on the v2.4.0 tree, zero assumptions**: 4.4.1 clean-room (fresh import → 379/379, 0 fail, 0 SCRIPT ERROR → PCK export 44,159,440 B → from-pack 335/335, 0 fail); 4.7.2 (Xogot's engine) on the main tree (fresh import → 379/379, 0 fail → tests/last_run.txt refreshed); real-boot render battery on 4.7.2 Forward Mobile + lavapipe: boot cards + menu all non-black (95%), VLM verdict on menu "no obvious rendering problems — text crisp and legible, scene renders fully"; world_shot gameplay frames 76% non-black, VLM reads full HUD (minimap, objective, joystick, A/B/X/Y, PHONE VOICE) + third-person player in yellow jacket. Suite numbers identical to session 10 — tree had not drifted.
3. **False-commit corrected (the real hole this session)**: the session-10 delivery report claimed v2.4.0 was "committed locally (cdb7380)" — reflog audit proved no such commit exists (context ran out before committing); 395 files of v2.4.0 sat uncommitted on top of v2.3.1 (07a4cc0). v2.4.0 + all artifacts are committed to main THIS session; report text corrected. Push still awaits a fresh PAT (old one exposed in chat — user must keep it revoked).
4. **Hello diag delivered** (`hello_diag/` project + `download/LEVERAGE_hello_diag_project.zip`, 5.8 KB): zero-dependency diagnostic (ColorRect + default font only — no assets, no autoloads) that isolates the delivery chain from the game. Verified on 4.7.2: fresh import OK, real render 95% non-black, VLM reads "LEVERAGE HELLO DIAG" + moving band + fps line verbatim, and the SHIPPED zip extracted to a clean dir boots instantly with the pre-imported cache accepted. Decision table in its FIRST_READ.txt triages hello-works/game-fails vs hello-also-fails.
5. **Deliverables rebuilt from the verified tree**: `LEVERAGE_v2.4.0_XOGOT_project.zip` 106,802,448 B (2,022 files; 4.7.2-native `.godot` cache; `leverage.pck` excluded) + `LEVERAGE_2.4.0.pck` 44,159,440 B (4.4.1 preset, desktop 4.4–4.6 per D19) + `download/CHECKSUMS.txt` (sha256 + bytes for every download file). Stale v2.3.1/v2.3.2 artifacts purged from download/.
6. **D22 recorded (tooling, not a game defect)**: `audit_scripts.sh` (--check-only) cannot resolve autoload identifiers — standalone parse audits report false compile errors ("Identifier not found: GameManager/EventBus/…") for every autoload-referencing script, identically on 4.4.1 and 4.7.2; session 10's audit_g472.txt shows the same pattern. Authoritative compile gate = the suite (loads every script in the real autoload context; 379/379 + from-pack 335/335, 0 SCRIPT ERROR).

## Session 10 — audit-test-verify-audit + "Alive City" (v2.4.0)

1. **Zero-assumption re-verification of v2.3.2 first**: `rm -rf .godot` → fresh 4.4.1 import → 334/334; fresh PCK export → from-pack 292/292; wipe → fresh 4.7.2 import → 334/334; full real-flow render probe on 4.7.2 (7 frames, all non-black, VLM-confirmed menu + gameplay). Only after that, any changes.
2. **Audit holes found** (code had zero TODO/FIXME; the holes were systemic): (a) no emergent encounters in free-roam — the single most-praised feature of world-class open worlds; (b) wanted stars vanish without an evasion arc (no searching state, no payoff); (c) pedestrian panic is silent and homogeneous; (d) nothing above ground level at 5 stars (no pursuit climax); (e) no replay incentive (no mission scoring); (f) **D20: vehicle engine-loop audio path was dead since the .ogg conversion** (`engine_loop.wav` never existed — vehicles silent); (g) **D21: render probe PNGs leak into the PCK post-render-run** (+1.9 MB observed).
3. **v2.4.0 shipped** (details in changelog v2.4.0): `StreetEncounters` autoload director (TDL #35), `is_searching()` + HUD blink + EVADED flash + `sfx_wanted_clear`, `AirUnit` code-built helicopter with tracking spotlight + looping rotor (TDL #36), mission medals (bronze/silver/gold, best retained, `sfx_medal` fanfare), ped scream/cower panic, `make_looping_spatial` + engine-loop fix (D20), `exclude_filter="docs/*,tests/render_out/*"` (D21). 4 new original SFX via `scripts/audio_gen_v240.py` → ffmpeg .ogg (the established pipeline).
4. **Validation**: 379/379 on 4.4.1 AND 4.7.2 (fresh imports, zero SCRIPT ERRORs); 335/335 from the re-exported 44.16 MB PCK; render battery re-run on 4.7.2 (all 7 frames non-black; menu shows v2.4.0; VLM: "real, fully rendered 3D game frame … menu panel with Continue/New Game/Settings/Credits" and "full HUD — minimap OLD QUARTER, objective, mobile control buttons"). Evidence: `docs/evidence/session10/`.
5. Git: v2.4.0 committed locally (session-10 commit); push to `jamesrudh-arch/Mjjjjhhh` main requires a fresh PAT from the user (the old one was exposed in chat and must be revoked — see final reply).

## Session 9 — the “still issues” round: latent parse errors + delivery hardening

1. Sandbox had been recycled (tools/ + .godot wiped): Godot 4.4.1 + 4.7.2 re-downloaded from official GitHub releases; full fresh-extraction verification of the v2.3.1 zip reproduced boot→menu cleanly (import 0 errors, 288/288, rendered + VLM-verified) — the delivery format itself was now sound.
2. **D18 found and fixed**: `scripts.parse` audit (check-only on every script, then load-compile in runtime context) exposed two scripts that fail to parse on BOTH engines — `phone.gd:169` (C-style ternary) and `pause_menu.gd:41` (untyped `:=` on a for-loop var). On device: Phone panel and Pause Menu dead-on-arrival (hud.toggle_phone does `load(...).new()` → null). Fixed; new standing `scripts.parse` suite (46 checks) added to the runner so every script must load-compile in the real autoload context — suite 288→334 checks, 0 failed on 4.7.2 AND 4.4.1 (fresh imports); from-pack 292/0 (pack-mode: DirAccess enumeration unavailable → explicit loads of the historically-broken files).
3. **D19**: the 4.4.1-exported PCK segfaults Godot 4.7.2 (`Binary GDScript is not compatible with this engine version` — upstream version lock). PCK relabeled desktop 4.4–4.6 only; XOGOT (project folder) unaffected.
4. **Delivery hardened**: XOGOT zip now carries the pre-imported `.godot` cache (4.7.2-built; `.godot/editor` + shader caches excluded) → first open on device is near-instant and immune to iOS killing a long import; falls back to normal re-import on engine mismatch. `FIRST_READ.txt` at zip root (extract first — never open the zip itself in Xogot; what you should see; triage line). Version 2.3.1→2.3.2 everywhere (project.godot, menu footer, boot diag).
5. **Workflow hazard documented (TDL #33)**: switching a project dir between engine-generation caches without a clean re-import produces transient anim-load failures (39 test fails, 4.7-cache + 4.4-runner); always `rm -rf .godot` + clean `--import` when changing engine generations.
6. Validation evidence: `docs/evidence/session9/` (title card, notice card, main menu, menu-stable-at-27s) rendered under 4.7.2 Forward Mobile + Vulkan (lavapipe); menu idle stability probe byte-identical captures out to 55 s. World render under llvmpipe still stalls on first-frame shader compile (known sandbox limitation; world build is covered headlessly inside the 334). Final-zip render verified on BOTH present paths: Vulkan/llvmpipe (early frames + VLM) and OpenGL-3 fallback (menu frames at 10/18/25/32 s, all 393,405 B, VLM-confirmed from the shipped zip); late black x11grab frames under llvmpipe are a sandbox present-path quirk, not a game defect.

## Session 8 — gray-screen root cause closed (delivery format)

1. User reported (again): gray screen, nothing renders — never able to test since creation. Root cause found via fresh web research: **Xogot is the Godot EDITOR for iPad/iPhone (Xibbon, App Store id6469385251), embedding Godot 4.7** — it opens Godot project folders (Files/iCloud/USB/GitHub); it has no bare-.pck player. Sessions 1–7 delivered only `leverage.pck` with "Open in XOGOT" instructions for a nonexistent player flow → the device showed an empty editor viewport (the reported uniform gray); the game never launched on-device. TDL #31 corrects #1/#13 (D17).
2. Xogot-engine-generation validation (sandbox): Godot 4.7.2 — clean `--import`, 288/288 tests, real boot→menu flow rendered under Forward Mobile + Vulkan 1.4.305 lavapipe, VLM-verified (title card, main menu with key art + buttons). World-load capture under llvmpipe stalls in-sandbox (sub-fps software GPU; not representative of an A-series GPU) — device checklist covers world rendering (session 7 VLM-verified it under Forward Mobile on 4.4.1). 4.4.1: 288/288 in-project + from-pack (v2.3.1 PCK, 44.0 MB).
3. `boot.gd` on-device diagnostics: `[LEVERAGE v…] boot start | Godot … | renderer … | OS … | mem …` + `boot cards done -> main menu` marker → visible in Xogot's debugger Output; launch failures self-explain (Xogot 1.7.12+ also reports launch-failure reasons itself).
4. Delivery corrected: `download/LEVERAGE_XOGOT_project.zip` (full project for Xogot; first open imports ~81 MB sources on-device) + GitHub main branch; stale PCKs removed from download/; PCK kept for desktop `godot --main-pack`.
5. Docs: final_verification_guide.md rewritten (real Xogot flow), D17 recorded, changelog v2.3.1, TDL #31, this file. `export_presets.cfg` gained include_filter/[preset.0.options] keys so 4.7-series editors stop printing preset-validation errors on open.

## Session 7 — what shipped (all remaining approved recommendations)

1. **D5 closed — rider visible while driving**: seated stand-in spawned from the player's own character body (`VehiclePlayer._spawn_rider`, per-class `seat_offset()`, Sitting_Idle, forward-facing), freed on exit. Car seat height tuned by VLM A/B of three candidates (y=0.20); bike astride y=0.52. Traffic motorcycles carry NPC riders; jacking pulls the rider off.
2. **D6 closed — motorcycle AI traffic**: 14% of traffic spawns are bikes + 2 deterministic seeded bikes near the player (nearest road, correct lane); bike agents brake tighter (7 m) and cruise slightly faster; jacked traffic bikes convert to real Motorcycle physics bodies.
3. **Interiors actually reachable now**: street-side amber glow door markers (interact → enter) for all 7 interiors (2 new: quickmart_store, pawn_backroom); in-room spawn respects room size (was a fixed offset that could drop the player inside a wall).
4. **D15 closed + latent flow bug fixed**: GameManager state-fade layer (CanvasLayer 60) — world entry fades from black (telemetry 1.0→0.46→0.0), MainMenu entry fade; the main menu was NEVER freed on game start (it stayed in the tree over the world — masked by the old probe freeing it manually and tests bypassing the menu); `_load_world` now frees the outgoing menu; motion probe proves `MENU FREED OK=true` through the real NEW GAME path.
5. **D9 fixed — new key art**: composed from a HUD-free dusk world capture (time forced to 19:30, live call declined, UI hidden) + neon-noir grade/bloom/vignette (`scripts/compose_keyart.py`); menu re-rendered FROM THE PACK under Forward Mobile (VLM PASS).
6. **D13 closed**: in-motion Mobile-renderer frames VLM-verified — pedestrians mid-stride, arms bent, no T-pose across multiple captures.
7. **Latent runtime errors fixed** (shipped silently in v2.1/v2.2): impact particles used a nonexistent `draw_pass` property (never spawned) → `mesh`; CinematicOverlay connected a nonexistent `EventBus.cinematic_requested` (lives on MissionSystem) + 0-arity lambda on a 1-arg signal.
8. **PCK hygiene**: probe screenshots were riding in the PCK (9.6 MB); render_out now gitignored scratch, evidence in `docs/evidence/session7/` (git, excluded from pack), export `exclude_filter="docs/*"`. PCK 46.1→45.6 MB despite new features.
9. **Validation**: 288/288 project + from-pack (31 new checks: presentation.cinematic, traffic.motorcycles, world.interiors, rider/jack checks); full real-flow motion probe under Forward Mobile/lavapipe (VLM-verified frames + objective telemetry). D16 recorded (VLM vehicle close-up oscillation; countered by clay-silhouette solidity 0.838 + byte-identity + A/B equality).

## Session 6 — what shipped

1. **Cinematic overlay** (`scripts/ui/cinematic_overlay.gd`): letterbox on dialogue/story beats, mission title cards (CHAPTER n + briefing), fades; wired in world.gd.
2. **Ambient one-shot audio**: 6 new synthesized sounds (horn/distant siren/chatter/birds/pass-by/wind) + district+day/night weighted scheduler in AudioSystem (7-16 s gaps, off during combat/chase).
3. **PCK 77.5→46.1 MB**: GLB image externalization via `scripts/glb_edit.py` (28 chars 40.2→22.3 MB, 8 vehicles 10.2→2.2, props 3.5→0.5; shared hash-dedup texture dirs), 420 derived source PNGs moved out of res:// to `asset_sources/` (repo, not PCK).
4. **D12 fixed**: authored billboard poster texture + flat maps (streak source removed).
5. Validation: 257/257 project + from-PCK; fresh Mobile-renderer frames VLM-verified (no regressions, textures intact).

## Session 5 — what shipped (all in the authoritative project, no backups)

1. **Combat juice (P0)**: `combat_feel.gd` static helpers — hit-stop, slow-mo, pooled impact particles. Player connects now hit-stop + camera-kick + shake + particles (scaled by damage); throws slow-mo + FOV punch-in; counters get hit-stop + sfx. Enemy brain rewritten: attack tokens (2 max), circle/flank, telegraphed wind-ups (readable counters), knockdown→lie→Roll get-up (×2 vulnerable), wounded retreat + shout, weapon reload every 3rd strike, discipline flavor. Cinematic last-enemy slow-mo finisher.
2. **Movement/world (P1/P2)**: footsteps by gait, sprint FOV kick, ped target 25→50 with idle variety (conversations, phone poses).
3. **Verification upgraded**: 257/257 on 4.4.1 in project dir AND from the fresh PCK. **Mobile renderer now renderable in sandbox** via user-local Mesa lavapipe Vulkan ICD (`tools/vulkan-deb/`, `VK_DRIVER_FILES=...lavapipe_icd.json`) — TDL #25; fresh Mobile-renderer gameplay capture VLM-verified.
4. User "gray screen" report investigated: shipped v2 PCK boots + renders correctly under BOTH opengl3 and Mobile/lavapipe from the pack (probe frames VLM-verified). Likely user-side causes: loading the raw project (needs `--import` first — cache is gitignored) or first-run 77 MB PCK load time. Fresh `download/LEVERAGE_2.0.0.pck` exported & validated.


## Environment facts (verified)

- Sandbox: Debian 13 (trixie) x86_64, 2 cores, ~4 GB RAM, ~6 GB free disk.
- Godot **4.7.2-stable** AND **4.4.1-stable** Linux binaries at `tools/` (headless works on both).
- Blender **4.5.9 LTS** at `tools/blender-4.5.9-linux-x64/` (sourceless .pyc restore documented in TDL #24; run with `env -u PYTHONHOME -u PYTHONPATH`).
- Xogot is a **Godot 4.7-based editor** (App Store id6469385251) that opens project folders from Files/iCloud/USB/GitHub — no bare-.pck playback (session 8 correction, TDL #31); delivery = project zip / GitHub, PCK kept for desktop `--main-pack`. Headless tests run on **Godot 4.4.1 AND 4.7.2** (session 8).
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
- v2.4.0 encounters tuning on device (spawn distance feels/weights per area) — logic Tested; feel is Device-only.
- Vehicle close-up micro-polish (arch rims, panel gaps) — reads correctly at gameplay distance; flagged in `known_defects.md`.
- Character close-up micro-polish (hairline transitions, facial material variety) — passes at gameplay camera distance.
- VLM review scores oscillated 3→5→7 across identical-improving frames; treat pixel evidence + game-distance renders as authoritative, not single-frame macro reviews.

## Exact resumption point (for any future session)

1. Read this file, then `docs/visual_quality_audit.md`, then `docs/changelog.md`.
2. Re-verify: `tools/Godot_v4.4.1-stable_linux.x86_64 --headless res://tests/test_runner.tscn` (expect `379 checks, 0 failed`; from-pack `335 checks, 0 failed`). If tools/ was wiped by a sandbox recycle: re-download Godot 4.4.1 + 4.7.2 from official GitHub releases into tools/, and re-create the lavapipe ICD via `apt-get download mesa-vulkan-drivers && dpkg -x` (TDL #25). NEVER mix engine-generation caches: `rm -rf .godot` + clean `--import` after switching engine builds (TDL #33).
3. Re-render: `bash ../scripts/reimport.sh` then `Xvfb :99 & DISPLAY=:99 LEVERAGE_RENDER=1 tools/Godot_v4.4.1-stable_linux.x86_64 --rendering-driver opengl3 res://tests/render_probe.tscn`.
4. Asset rebuilds (Blender): `env -u PYTHONHOME -u PYTHONPATH tools/blender-4.5.9-linux-x64/blender -b --factory-startup -P scripts/build_<character|vehicle|building|props>.py -- <specs.json> [ids...]` — one import per Blender session; never `read_factory_settings` between exports (breaks the glTF addon).
5. New defects → `docs/known_defects.md` (never delete). New decisions → `docs/technical_decision_log.md` with sources. Status moves only with evidence.

## Rules of engagement (from directive)

- Never claim sandbox test = iPhone verification. iPhone/XOGOT checks are **Device-only**.
- No backups/duplicate projects; this directory is the single truth.
- Record technical decisions with sources; do not silently drop any requirement.
