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
