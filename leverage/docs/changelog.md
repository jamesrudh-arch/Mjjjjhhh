# LEVERAGE — Changelog

## 2026-11-24 (session 11 — v2.4.0 re-verified + delivery hardened; no game-code changes)
- Full audit-test-verify re-run from scratch on the v2.4.0 tree (sandbox had recycled; Godot 4.4.1 + 4.7.2 + lavapipe restored): 379/379 on both engines (fresh imports), 335/335 from the re-exported 44.16 MB PCK, real-boot render battery + VLM on 4.7.2 (menu + gameplay frames clean), world_shot gameplay evidence.
- **Corrected the session-10 delivery report's false claim**: v2.4.0 was never actually committed ("cdb7380" does not exist — reflog ends at v2.3.1). v2.4.0 + artifacts committed for real this session.
- New `hello_diag/` zero-dependency diagnostic project (5.8 KB zip) — isolates the delivery chain from the game on the user's device; VLM-verified render + extracted-zip instant boot on 4.7.2.
- Deliverables rebuilt from the verified tree (XOGOT zip 106,802,448 B with 4.7.2-native cache, PCK 44,159,440 B), `download/CHECKSUMS.txt` (sha256 + bytes), stale v2.3.x artifacts purged.
- D22 tooling note: --check-only audits can't resolve autoloads (false compile errors, both engines, same as session 10) — the suite is the authoritative compile gate.

## v2.4.0 — "Alive City" upgrade pass (session 10, 2026-11-24)
Full user-directed audit-test-verify-audit run first: fresh-sandbox re-verification of v2.3.2 before any change (334/334 on 4.4.1 fresh import, 334/334 on 4.7.2 fresh import, 292/0 from-pack, full real-flow render battery non-black on 4.7.2 — zero assumptions carried). Audit then found five excitement gaps vs the world-class bar and one real audio defect; all closed this session:

- **Street encounters (RDR2-style emergent events)**: new `StreetEncounters` director (autoload) rolls weighted random encounters during free-roam — street mugging (break it up: fight + cash + rep), drug deal (two armed dealers, bigger stake), bar brawl (ambient, scatters as you close), dropped stash (grab = money + a witnessed crime that feeds the police heat system). Gating: no missions/combat/interiors/chase; cooldown 75 s; night + high-crime areas roll hotter; lifetime/abandon expiry. World scene instantiates combatants/pickup visuals via the PoliceSystem signal pattern. 12-check suite `encounters.sim`.
- **Wanted-evasion loop**: `is_searching()` pursuit-with-no-LOS state — HUD stars BLINK while police hunt blind (GTA-style escape tension); `_lose_level` to 0 now fires the evasion payoff: `police_lost_target` → HUD "WANTED LEVEL CLEARED — EVADED" flash + `sfx_wanted_clear` stinger. 7-check suite `police.evasion`.
- **5-star air pursuit**: `AirUnit` police helicopter (code-built mesh — boxes/cylinders/spinning rotor, no asset pipeline) orbits 30 m over the player with a tracking SpotLight3D + blinking nav light + looping rotor thump (`sfx_heli_loop`, new); reports sightings every 2.5 s so escaping 5 stars needs real cover; self-despawns below level 5. patrol_plan(5) adds `air_unit`; world spawns/despawns it. 6-check suite `police.air`.
- **Mission medals (replay value)**: every mission scores time-vs-par + damage-taken → BRONZE/SILVER/GOLD, best retained across replays, gold count in stats, fanfare `sfx_medal` + notification. 4-check suite `missions.medals`.
- **Pedestrian panic**: flee now SCREAMS (`sfx_ped_scream`), and ~30% of peds freeze in a cower instead of running (Crouch_Idle fallback Idle), recovering after the danger passes. 5-check suite `peds.panic`.
- **D20 (audit find, closed)**: `make_engine_loop()` loaded a nonexistent `engine_loop.wav` — vehicles have been engine-silent since the .ogg conversion. Now loads `sfx_engine_loop.ogg` as a true looping stream (`make_looping_spatial`); regression checks added (`audio.sfx` block).
- **D21 (audit find, closed)**: `tests/render_out/*` probe PNGs leaked into the PCK whenever a render probe had run before export (TDL #30's `docs/*` filter didn't cover them; +1.9 MB observed this session). `exclude_filter="docs/*,tests/render_out/*"` + re-export; PCK 46.09 → 44.16 MB.
- New SFX (all original numpy DSP, `scripts/audio_gen_v240.py` → .ogg pipeline): `sfx_ped_scream`, `sfx_wanted_clear`, `sfx_heli_loop`, `sfx_medal`.
- Version bumped everywhere (project.godot, main menu label). Boot card prints engine/renderer/OS as before.
- **Verification**: 379/379 on Godot 4.4.1 (fresh import) AND 4.7.2 = Xogot's engine (fresh import); 335/0 from the re-exported 44.16 MB PCK (D21 filter applied); full real-flow render battery on 4.7.2 (boot cards → menu v2.4.0 → intro → world gameplay; all frames non-black) + VLM-verified menu and gameplay frames (docs/evidence/session10/). Zero SCRIPT ERRORs in any run.

## 2026-11-23 (session 1)
- Environment investigation completed; Godot 4.7.2 + 4.4.1 + Blender 4.5.9 staged in tools/.
- Project skeleton created (project.godot, Mobile renderer, 4.4 feature set, input map incl. fixed X/Y/A/B).
- Core autoloads implemented: EventBus, GameState, GameManager, InputRouter, SaveSystem, AudioSystem, TimeWeather; LvgTheme; boot.gd splash sequence.
- Fonts bundled with licenses. UAL (CC0) downloaded; Quaternius pack download manifest established.

## 2026-11-23 (session 2)
- Documentation foundation completed: development_state, master_design, technical_architecture, control_map, asset_register, technical_decision_log, world_design, characters_story, art_direction, requirements_traceability, changelog, known_defects, test_reports, final_verification_guide.
- Quaternius CC0 packs downloaded via official Google Drive links: Animated Men (verified 8 FBX), Animated Women, Cars, Modular Streets, Ultimate Guns, Textured Buildings, Home Interior, Furniture, Public Transport, Simple Buildings.
- UAL Mannequin imported into project as the shared humanoid rig; character/asset Blender pipeline established.
- All six missing autoloads implemented (WorldEvents, CityDirector, NPCDirector, PoliceSystem, MissionSystem, DialogueSystem) — project boots.
- Boot/main-menu/world scenes created; player controller, camera rig, combat (5 disciplines), weapons, vehicles+traffic, city buildout, HUD + touch controls, phone, map, shops, radio, intro cinematic implemented.
- Audio asset set synthesized (music moods, ambience, SFX, radio loops, jingles).
- Headless test harness (`tests/`) executing on Godot 4.4.1; results in test_reports.md.

## 2026-11-23 (session 3 — audit + close-out)
- Full pre-delivery audit against the founding directive (delivery_report.md).
- **Motorcycles added (R13 closed)**: authored original low-poly motorcycle GLB via Blender headless (`scripts/make_motorcycle.py`, mobile budget ~78 KB); `Motorcycle` vehicle class (2-wheel VehicleBody3D, upright roll-lock + cosmetic lean, bike force/steer curve); parked bikes in Old Quarter + Neon Strip; 12-check test suite `vehicles.motorcycle`.
- `export_presets.cfg` ("XOGOT PCK" preset, feature tag `mobile`, ETC2/ASTC) — `leverage.pck` (13.4 MB) exported headless and **validated by running the entire 238-check suite from the PCK itself**.
- Final runs: 238/238 PASS on Godot 4.4.1 (project + PCK) and 4.7.2 (project).
- **In-vehicle radio wired end-to-end (R23 closed)**: audit found station tuning changed only the HUD label; AudioSystem now loads the station loop, plays it in-vehicle, ducks mood music, retunes live, stops on exit (dedicated killable tween — stale fade-outs were the root cause found by the new failing test). 11-check suite `audio.radio`.
- Docs brought to truth: test_reports (filled), requirements_traceability (statuses advanced with evidence), known_defects (D4/D5/D6), asset_register (motorcycle), control_map (motorcycle row), development_state rewritten to delivery state, delivery_report written.
- Deliverable packaged to `download/` (project zip + PCK + report).

## v2.0.0 — Total Visual Overhaul + Living Phone + GPS (session 4, 2026-11-23)

### Rebuilt (visual)
- PBR texture forge: 17 procedural texture sets (asphalt/markings, brick, concrete, pavement, fabrics, skin, foliage, metal, storefront).
- 28 realistic authored human bodies (faces, hair, beards, layered clothing, distinct casts) skinned to the UAL rig; runtime mesh/skin swap in CharacterFactory v2; proximity skinning replaces envelope auto-weights.
- 8 detailed vehicles (unified hull + region glass + wheel arch cutouts + detailed wheels/lights/grille/interior); motorcycle rebuilt.
- 19 authored buildings (5 district styles, inset windows, doors, storefronts w/ emissive signs, roofs).
- 13 authored street props (trees, streetlights, traffic lights, hydrant, bin, bench, bus stop, billboard, dumpster, barrier).
- City v2: 28-road shared network, textured roads/curbs/sidewalks/crosswalks, per-district buildings, night window emission ramp, player-following streetlight omnis, parked cars (≤400), slot-probability furniture.
- Cinematic environment: procedural sky, graded day/night, warm fog, ACES.
- Menu key art (cinematic graded cityscape) + contact portrait set (16 rendered head shots).

### Systems
- PhoneSystem: real incoming calls (ringtone loop + banner + ANSWER/DECLINE + subtitles), missed/declined consequences, reschedule-once, per-contact threads with timestamps/unread/quick-replies, call log, outgoing calls + voicemail, story-driven scheduling (mission completion → next giver calls + texts). Persisted.
- MapScreen v2: A* GPS routing over the road graph, location selection, route + HUD compass arrow + distance, zoom/pan, fog of war, live markers.
- Road graph: 21 cross streets; ironworks/neon/heights island bugs fixed.
- Tests: 238 → 257 checks (phone.system, map.gps suites). Campaign (13 missions) fully resolving.

### Fixes
- Animation name discovery (Godot glTF importer strips `_Loop`); Array.filter callback arity; menu/HUD tab-indentation parse errors; Blender session reuse (factory-reset breaks glTF addon); reimport-before-render discipline (stale import cache).

## v2.1.0 — Combat Feel / "Juice" Pass (session 5, 2026-11-23)

### Combat (P0)
- NEW `scripts/combat/combat_feel.gd`: static juice helpers — token-guarded hit-stop
  (`Engine.time_scale` + ignore_time_scale restore), slow-motion, pooled CPUParticles3D
  impact bursts (14-particle pool, mobile-renderer safe).
- Player hits now LAND: hit-stop scaled by damage/knockback, camera kick (damped pitch
  spring) + shake + impact particles per connect; throws get slow-mo + FOV punch-in;
  counters get hit-stop + `sfx_counter`.
- Enemy brain rewritten (`combatant.gd`): attack tokens (max 2 strike simultaneously,
  rest circle/flank at a ring with per-enemy direction), audible + visual telegraphs
  (slow wind-up anim + swing SFX at wind-up start so counters are READABLE),
  knockdown (Death01 fall → lie → Roll get-up, ×2 vulnerable while down), wounded
  retreat + shout for help, weapon users reload every 3rd strike, discipline-flavored
  reach/speed/strike anims. Nobody stands still eating hits.
- Death presentation: strong hit-stop + particles on every kill; last hostile in a
  brawl goes down in slow motion with camera zoom (cinematic finisher).

### Movement & world (P1/P2)
- Footstep SFX by gait cadence (was: no footsteps at all).
- Sprint FOV kick (+6° eased) via new `CameraRig.sprint_fov`.
- Pedestrian ambient target 25→50; idle variety (Idle_Talking conversations that
  face each other, Idle_Torch phone-like pose).

### Validation
- 257/257 PASS on 4.4.1 (project dir AND freshly exported PCK — from-pack validation
  now re-established for v2-line exports).
- Mobile (Vulkan) renderer path now exercised in sandbox via user-local Mesa lavapipe
  ICD (`tools/vulkan-deb/`, no root needed) — TDL #25. Fresh gameplay capture verified.

## v2.2.0 — Cinematic Presentation + Living Audio + PCK Dedup (session 6, 2026-11-23)

### Cinematic presentation (P3)
- NEW `scripts/ui/cinematic_overlay.gd` (CanvasLayer 40, code-built): animated
  letterbox bars on all dialogue + story beats, mission title cards (CHAPTER n
  + title + briefing, sfx, brief letterbox flavor), full-screen fades.
- Wired into world (world.cinematic), version footer bumped to 2.2.0.

### Living audio (P1)
- Six new synthesized one-shots (original DSP, `scripts/audio_ambient_gen.py`):
  city horn (doppler), distant siren, street chatter, birds, car pass-by,
  wind gust (.ogg).
- AudioSystem ambient one-shot scheduler: district+day/night weighted table,
  7-16 s randomized gaps, quiet distant mix, holds off during combat/chase.

### PCK size: 77.5 MB -> 46.1 MB (-40%)
- `scripts/glb_edit.py` GLB surgery: externalize embedded images to per-dir
  `shared/` texture sets (content-hash dedup), compact BIN, remap accessors.
  Applied to 28 character GLBs (40.2→22.3 MB + 0.9 MB shared), 8 vehicles
  (10.2→2.2 + 1.0 shared), props (3.5→0.5 + 0.6 shared); interiors already lean.
- 279 derived per-char PNGs (18.7 MB) + 96 vehicle + 45 prop source PNGs moved
  OUT of res:// to repo `asset_sources/` (still versioned; not PCK baggage).
- Godot external-image URI loading verified (textures intact post-surgery).

### D12 fixed
- Billboard streaks: authored 512x256 poster texture (clean blocks/lettering,
  no fine noise) + flat neutral normal/metallic maps; billboard.glb 238 KB→9.7 KB.

### Validation
- 257/257 in project dir AND from the 46.1 MB PCK (TDL #26 discipline).
- Fresh Mobile-renderer (lavapipe Vulkan) render-probe frames VLM-verified:
  characters fully textured, billboard clean, no regressions.

## v2.3.0 — All-Recommendations Pass: Rider, Bike Traffic, Interiors, Fades (session 7, 2026-11-23)

### Rider is visible while driving (D5 closed)
- `VehiclePlayer.enter()` spawns a seated rider stand-in from the player's OWN
  character body (CharacterFactory), parented to the vehicle at a per-class
  `seat_offset()` (car LHD y=0.20 tuned by VLM A/B of three candidates; bike
  astride y=0.52), `Sitting_Idle` pose, forward-facing. Freed on exit; the real
  player controller is untouched.
- Traffic motorcycles seat an NPC rider (child of the visual) so AI bikes are
  not ghost bikes; jacking pulls the rider off (freed) before the player rides.

### Motorcycle AI traffic (D6 closed)
- TrafficManager: 14% of agent spawns are bikes + 2 deterministic seeded bikes
  near the player (nearest road, ~95 m, correct lane); bike agents use a
  tighter brake profile (7 vs 9 m) and slightly higher cruise speed.
- Jacking a traffic bike converts to a REAL `Motorcycle` physics body
  (VehiclePlayer.create_from_agent dispatch; agent visual carried over).

### Enterable interiors — the entry path existed but was unreachable (fixed)
- NEW street-side door markers for all interiors: amber emissive glow
  cylinders (unlit, mobile-cheap) at each anchor; interact enters the room.
- Two new interiors (7 total): quickmart_store, pawn_backroom (authored props).
- In-room spawn now respects room size (clear of the wall), replacing the
  fixed +4.0 z that could drop the player inside a wall.

### Menu→game presentation (D15 closed) + latent flow bug fixed
- GameManager owns a persistent state-fade layer (CanvasLayer 60): the world
  arrives through a 0.55 s fade-in from black (probe telemetry: alpha 1.0 →
  0.46 → 0.0); MainMenu fades in from black on entry.
- **The main menu was never freed on game start** (it stayed in the tree
  covering the world — masked until now because the render probe freed it
  manually and tests bypass the menu). _load_world now frees the outgoing
  menu scene; motion probe proves `MENU FREED OK=true` through the real
  NEW GAME button path.

### New key art (D9 fixed)
- menu_bg_0.png recomposed from a HUD-free DUSK world capture (time forced to
  19:30, live incoming call declined, HUD/touch/banner hidden): upscale +
  amber/teal neon-noir grade + bloom + vignette (`scripts/compose_keyart.py`).
  Menu renders from the PCK verified (VLM PASS).

### Fixes found on the way
- v2.1.0 impact particles never spawned: `draw_pass` is not a CPUParticles3D
  property → now `mesh` (+ canonical unshaded shading_mode).
- v2.2.0 CinematicOverlay connected a nonexistent `EventBus.cinematic_requested`
  (it lives on MissionSystem) and a 0-arity lambda to a 1-arg signal — both fixed.
- Traffic test flake: background story calls can win the queue race in the
  phone suite (drained deterministically now); jack tests restore player pos.
- PCK no longer carries probe screenshots / docs (exclude_filter, render_out
  cleaned + gitignored; evidence lives in docs/evidence/, outside the pack).

### Validation
- **288/288** in project dir AND from the shipped 45.6 MB PCK (31 new checks:
  presentation.cinematic, traffic.motorcycles, world.interiors + rider checks).
- Full real-flow Mobile-renderer (lavapipe) motion probe VLM-verified:
  peds mid-stride/no T-pose (D13 closed), rider in-world, cars coherent at
  gameplay distance, fade + menu-free telemetry, HUD-free dusk key art.
- D16 recorded: single-frame VLM verdicts on dark glossy vehicle close-ups
  oscillate; objective clay-silhouette solidity (0.838) + byte-identical
  geometry vs v2.1.0 + old/new A/B equality prove no vehicle regression.

## v2.3.1 — Gray-Screen Root Cause Closed: Delivery Format (session 8, 2026-11-24)

### The bug was in the delivery, not the game
- Fresh research (App Store listing + xogot.com, Nov 2026): **Xogot is the
  Godot EDITOR for iPad/iPhone (Xibbon, App Store `id6469385251`), embedding
  Godot 4.7** — it opens Godot project folders from Files/iCloud/USB/GitHub
  and has **no bare-.pck player**. Sessions 1–7 shipped only `leverage.pck`
  with "Open in XOGOT" instructions written for a player app that doesn't
  exist → the reported gray screen was Xogot's empty editor viewport; the
  game never launched on-device. TDL #31 corrects the #1/#13 premise
  (append-only rule respected).

### Xogot-engine-generation validation (sandbox, this session)
- Full `--import` clean under **Godot 4.7.2** (the engine generation Xogot
  embeds).
- **288/288** tests under 4.7.2 (scratch copy) AND under 4.4.1 (authoritative
  dir + from-pack).
- Real boot-cards → main-menu flow rendered under **Forward Mobile +
  Vulkan 1.4.305 (lavapipe)** on 4.7.2 — VLM-verified frames (LEVERAGE title
  card with amber typography + tagline; main menu with key art +
  NEW GAME/SETTINGS/CREDITS). World-load capture under llvmpipe software
  rendering stalls in-sandbox (sub-fps software GPU is not representative of
  an A-series GPU); world rendering was VLM-verified under Forward Mobile in
  session 7 on 4.4.1, and the device checklist covers it.
- `boot.gd` now prints `[LEVERAGE v…] boot start | Godot … | renderer … |
  OS … | mem …` and a `boot cards done -> main menu` marker — these lines land
  in Xogot's debugger Output pane and make any device launch failure
  self-explaining (Xogot 1.7.12+ also surfaces launch-failure reasons itself).
- `export_presets.cfg` gained `include_filter`/`[preset.0.options]` keys so
  4.7-series editors no longer print preset-validation errors on project open.

### Delivery corrected
- New deliverable: **`LEVERAGE_XOGOT_project.zip`** — the full project folder
  (~85 MB) that Xogot actually opens; the first open triggers on-device
  import. GitHub `main` carries the same content for Xogot's GitHub open path.
- PCK re-exported (v2.3.1, 44.0 MB) and from-pack validated 288/288; kept for
  desktop `godot --main-pack` runs. Stale PCKs removed from `download/`.
- `final_verification_guide.md` rewritten around the real Xogot flow (open the
  project, never the .pck; wait for the on-device import; where launch errors
  appear).

## v2.3.2 — Parse-error ship-blockers fixed + cache-in-zip delivery (session 9, 2026-11-24)

### Found and fixed (the real reason in-game features died on device)
- **`scripts/ui/phone.gd:169`** shipped a C-style ternary (`mine ? " - sent" : ""` — invalid GDScript in every engine version): the in-game Phone panel was dead-on-arrival — `hud.toggle_phone()` did `load(...).new()` on a script that cannot parse.
- **`scripts/ui/pause_menu.gd:41`** shipped `var s_idx := slot` with untyped inference (for-loop variable) — the Pause Menu was dead-on-arrival the moment the user paused.
- Both parse-fail on Godot 4.4.1 **and** 4.7.2 (Xogot's engine); the 288-check suite never caught them because it never compiled those two UI scripts.
- **New standing regression net**: `scripts.parse` suite (test_runner) now load-compiles **every** `.gd` under `res://scripts` in the real autoload context (46 checks; pack-mode falls back to explicit loads of the historically-broken files). Suite: 288 → **334 checks, 0 failed** on 4.7.2 AND 4.4.1 (fresh-imported project dir); from-pack: **292 checks, 0 failed** (4.4.1).

### Delivery hardened
- **XOGOT zip now ships the pre-imported `.godot/` cache** (built by Godot 4.7.2 — Xogot's engine generation): first open on device no longer depends on a multi-minute on-device import that iOS can kill; worst case (cache format mismatch) falls back to a normal re-import. `.godot/editor` + shader caches excluded.
- `FIRST_READ.txt` at zip root: 5-step install (extract FIRST — do not open the zip in Xogot) + what you should see + one-line triage.
- Desktop PCK re-exported from the fixed project (`LEVERAGE_2.3.2.pck`, 44 MB). **Scope corrected (D19): runs on Godot 4.4–4.6 desktop only** — 4.7+ segfaults on 4.4-built binary GDScript (upstream engine lock, documented).
- Version 2.3.1 → 2.3.2 everywhere (project.godot, menu footer, boot diag).

### Re-verified today from scratch (fresh sandbox, fresh extraction)
- Fresh unzip of the shipped zip → Godot 4.7.2 first-open import: 21 s, 788 resources, 0 errors.
- Boot → cards → main menu rendered under 4.7.2 Forward Mobile + Vulkan (lavapipe), frames VLM-verified (title card, notice card, menu with key art + NEW GAME/SETTINGS/CREDITS panel); menu stable ≥ 55 s (byte-identical captures, process alive).
- Cross-version cache staleness documented: switching a project between 4.7- and 4.4-imported caches without a clean re-import yields transient anim-load failures — always re-import clean when changing engine generations (decision log #33 note).
