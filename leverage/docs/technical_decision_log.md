# LEVERAGE — Technical Decision Log

Every non-trivial decision, with source and status.

| # | Decision | Rationale & source | Status |
|---|---|---|---|
| 1 | Author on Godot 4.4-compatible API subset while keeping Mobile renderer and 4.7 tooling | XOGOT (iPhone Godot player app) embeds a 4.4-series runtime; official XOGOT documentation (App Store page + xogot.com) states Godot 4.4 PCK support. Verified against local binaries: project must open in 4.4.1 AND 4.7.2 → features "4.4" declared, 4.7 used as editor only. | Verified (both binaries open project) |
| 2 | Quaternius CC0 packs as the asset backbone | quaternius.com lists packs as CC0; site reachable from sandbox; itch.io + Google Drive official mirrors accessible; kenney.nl blocked (403) and poly.pizza unreachable from this sandbox — documented alternative path chosen per directive. | Verified (downloads complete) |
| 3 | Single humanoid rig = UAL Mannequin (Rigify DEF bones) for player + NPCs | UAL ships skinned mannequin + 46 animations natively compatible; avoids cross-rig retargeting risk entirely; Quaternius FBX characters retained as named-NPC bodies via scripted retarget where validated. | Implemented |
| 4 | Combat state machine in GDScript code, not AnimationTree | AnimationTree+StateMachine less testable headless; code paths assertable in CI; 4.4-compatible. | Implemented |
| 5 | Traffic = kinematic spline agents; player-driven vehicles = VehicleBody3D | Mobile CPU budget; traffic cars swap to full physics body only when jacked. | Implemented |
| 6 | City = one scene, six area roots toggled visible/process by distance; geometry in MultiMesh batches | "Streaming" on mobile is best served by batching + visibility, not scene reloading; keeps 4.4-compatible and avoids loading stalls. | Implemented |
| 7 | All audio synthesized via numpy | No license risk, no download dependency, full control of neo-noir identity; directive allows original assets. | Implemented |
| 8 | Touch controls emit canonical Input actions through Input.parse_input_event() | Guarantees gamepad/keyboard/touch parity — one interpretation layer (InputRouter). | Implemented |
| 9 | Saves as JSON (user://saves/slot_N.json) | Human-auditable, versionable, 4.4-safe; no binary format churn. | Implemented |
| 10 | Headless tests on Godot 4.4.1 with LEVERAGE_TEST=1 | Tests the runtime that ships (XOGOT 4.4); never conflated with device verification. | Implemented |
| 11 | LiberationMono replaced by DejaVuSans for mono fallback | LiberationMono not bundled; DejaVuSans is present and properly licensed; avoids missing-resource load error in LvgTheme. | Implemented |
| 12 | Motorcycle mesh authored in-project via Blender headless instead of a third-party pack | No CC0 motorcycle existed in the downloaded Quaternius set; authoring a ~78 KB low-poly GLB keeps the licence register clean (original © D'Youngs Games) and the mobile budget small. Source: `scripts/make_motorcycle.py`. | Implemented |
| 13 | Export = minimal `export_presets.cfg` ("XOGOT PCK" preset, iOS platform, `custom_features="mobile"`, ETC2/ASTC) | Godot docs: PCK/ZIP packages are platform-portable; feature tags drive texture compression selection. XOGOT's documented input is a Godot 4.4-series PCK → headless `--export-pack` produces it without iOS export templates/signing. Proven by running the full 238-check suite from the exported PCK. | Verified (pack runs) |
| 14 | Motorcycle scope & handling model: physics roll locked (arcade upright), lean expressed on the visual mesh; traffic AI remains cars-only, bikes are player-usable | Godot VehicleBody3D two-wheel setups topple without stabilisation; the established arcade pattern is local-axis roll lock + cosmetic lean, which also reads correctly in third person and avoids needing a rider-balance sim. Traffic corridors (lanes, avoidance, intersections) are tuned around car silhouettes; adding bike traffic would need separate lane logic for marginal mobile cost. Refs: control_map.md §Vehicle, known_defects D5/D6. | Implemented + Tested (vehicles.motorcycle suite) |

Update rule: append rows; never edit history silently.
