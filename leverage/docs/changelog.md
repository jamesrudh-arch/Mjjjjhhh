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
