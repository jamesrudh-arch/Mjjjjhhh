# LEVERAGE — Changelog

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
