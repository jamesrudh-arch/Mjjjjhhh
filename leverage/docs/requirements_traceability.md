# LEVERAGE — Requirements Traceability Register

Directive requirement → implementation → status. Status values: Implemented / Tested / Verified / Device-only / Deferred(never silently). Every requirement from the founding directive has a row.

| # | Requirement | Where | Status |
|---|---|---|---|
| R1 | Full game LEVERAGE, third-person open-world crime-action, fully playable start-to-finish | project + docs | **Tested** (journey suite drives the full campaign ch1→ending; free-roam systems live; on-device playthrough is Device-only) |
| R2 | Target Godot 4.7 Mobile renderer | project.godot `rendering_method="mobile"`; 4.4-compatible subset (TDL #1) | **Tested** (boots + full suite green on 4.4.1 AND 4.7.2) |
| R3 | Runs via XOGOT on iPhone | 4.4-compatible subset; `leverage.pck` exported + suite-passing from the pack; final_verification_guide.md | **Tested** (package proven); runtime on iPhone: **Device-only** |
| R4 | Environment investigation FIRST | development_state.md §Environment facts | **Verified** |
| R5 | Official docs research before tech decisions | technical_decision_log.md | **Verified** |
| R6 | Asset research + licences | asset_register.md; Quaternius/UAL CC0; motorcycle authored in-project | **Verified** |
| R7 | D'YOUNGS GAMES → title → notice → menu → cinematic → tutorialized entry | boot.gd + intro_cinematic.gd + world tutorial | **Tested** (boot.flow, intro.cinematic suites; renders 01–05) |
| R8 | 5 combat disciplines distinct with animations | combat/disciplines.gd + UAL library anims | **Tested** (34-check combat.disciplines suite incl. anim-library existence) |
| R9 | X=Punch, Y=Heavy, A=Kick, B=Dodge fixed | input_router.gd; control_map.md | **Tested** (ui.touch fixed-mapping checks) |
| R10 | Touch controls matching authoritative map | touch_controls.gd emits canonical actions | **Tested** (ui.touch suite) |
| R11 | Complete weapon system | weapons.gd + 5 weapon GLBs + aim/shoot/reload | **Tested** (weapons component integration + combat.sim damage paths) |
| R12 | Armour system | armor stat in game_state + shop + pickups | **Implemented** (flows through combat damage math; no dedicated harness row) |
| R13 | Vehicles cars+motorcycles, traffic AI, intersections, lights, ped avoidance | vehicle_player.gd, motorcycle.gd (added s3), traffic_manager/agent.gd | **Tested** (vehicles.traffic + traffic.sim + vehicles.motorcycle suites) |
| R14 | 6-area connected open world | city_builder/director.gd (6 areas, roads, interiors) | **Tested** (city.areas + world.integration) |
| R15 | Streaming/loading/persistence | area activation + interiors + save/load | **Tested** (saves.roundtrip: position/area/time restored) — architecture is single-scene per-area activation (mobile-realistic), not literal async streaming; noted in TDL |
| R16 | 16 named NPCs routines/memory/relationships | npc_director.gd + named_npc_agent.gd | **Tested** (npc.sim: 16 cast, anchors, witness memory) |
| R17 | ~25 pedestrians living routines | pedestrian.gd pool | **Tested** (pedestrians.pool: target 3..25 dynamic) |
| R18 | Police AI + wanted levels | police_system.gd + police_unit.gd | **Tested** (police.wanted + police.units suites) |
| R19 | Persistent world events, weather, day/night | world_events.gd + time_weather.gd | **Tested** (world.events + time.weather suites) |
| R20 | Story with meaningful choices/consequences | mission_system + dialogue_system + 4 endings | **Tested** (story.consequences + ending resolved) |
| R21 | Missions system + side content | mission_system.gd (13 missions + side jobs) | **Tested** (mission.journey: all 13 start+complete) |
| R22 | Economy, shops, inventory | game_state + shop_screen.gd + inventory | **Tested** (state.economy suite; shop UI live in world) |
| R23 | Phone (contacts/messages), map, radio | phone.gd, map_screen.gd, radio wired end-to-end this session | **Tested** (audio.radio suite: stations load, play in-vehicle, retune live, stop on exit) |
| R24 | Save/load + checkpoints | save_system.gd (3 slots + autosave) | **Tested** (saves.roundtrip) |
| R25 | Complete audio identity | audio_system.gd + synthesized set | **Implemented** (logic Tested; audition without audio device impossible → Device-only listening) |
| R26 | Mobile-first UI/UX | LvgTheme + touch_controls + HUD | **Tested** (ui.touch suite; menu.build) |
| R27 | Continuous autonomous development, no approval gates | changelog (3 sessions) | **Ongoing → complete** |
| R28 | Documentation set in one authoritative project | docs/ (14 documents) | **Implemented** |
| R29 | Development State w/ exact resumption point | development_state.md | **Implemented** |
| R30 | Honest status taxonomy | all docs + this register | **Ongoing** (final audit passed) |
| R31 | Full pre-delivery audit | delivery_report.md | **Done** |
| R32 | Final delivery report with Device-only disclosure | delivery_report.md + packaged zip | **Done** |
| R33 | No reuse of other AI agents' implementations | original GDScript + CC0 assets | **Verified** |
| R34 | Emergent street encounters during free-roam (world-class "alive city" upgrade, session-10 research) | scripts/world/street_encounters.gd + world.gd visuals; encounters.sim suite | **Tested** (12/12; 379/379 both engines) |
| R35 | Wanted-evasion tension loop (searching stars, EVADED payoff) + 5-star air pursuit unit | police_system.gd is_searching + hud.gd blink/flash + air_unit.gd; police.evasion + police.air suites | **Tested** (13/13; VLM render battery unaffected) |
| R36 | Mission performance medals + ped panic audio/behavior + engine-loop audio regression | mission_system.gd _award_medal, pedestrian.gd cower/scream, audio_system.gd make_looping_spatial; missions.medals + peds.panic + audio.sfx suites | **Tested** (16/16) |

Update rule: statuses only move forward with evidence; regressions get a Known Defects row instead.
