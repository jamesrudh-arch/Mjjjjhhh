# LEVERAGE — Technical Architecture

## Target and runtime compatibility

- Authoring: Godot 4.7.2-stable (`tools/Godot_v4.7.2-stable_linux.x86_64`), Mobile rendering method.
- Runtime: **XOGOT on iPhone embeds a Godot 4.4.x runtime**; therefore every script/scene uses only the 4.4-compatible API subset. `project.godot` declares `config/features=PackedStringArray("4.4","Mobile")`.
- Headless CI: `tools/Godot_v4.4.1-stable_linux.x86_64` — tests run on the runtime version that matters (4.4), never on 4.7-only APIs.
- Renderer: Mobile ( GLES3/GLSL with mobile clustering). MSAA 2x, ETC2/ASTC VRAM compression enabled (`textures/vram_compression/import_etc2_astc=true`).

## Scene & autoload topology

```
boot.tscn (main)  -> main_menu.tscn -> world.tscn (single open-world scene)
world.tscn children: City (area roots ×6), TrafficManager, NPCDirector-owned NPCs,
PoliceSystem units, Player (CharacterBody3D + rig + AnimationPlayer + camera boom),
HUD/touch overlay, WorldEnvironment (day-night/weather grade)
```

Autoloads (registered in project.godot, single dependency direction):

```
EventBus (signals only) <- all
GameState (data) <- SaveSystem, directors
SaveSystem -> GameState (snapshot/restore)
InputRouter -> player/vehicle/combat (canonical action semantics)
AudioSystem <- EventBus (music_layer_requested, sfx_requested, ambience_area_changed)
TimeWeather -> directors (hour/weather signals)
WorldEvents, CityDirector, NPCDirector, PoliceSystem, MissionSystem, DialogueSystem
GameManager (flow: menu/world/pause/gameover; autosave cadence)
```

Rule: systems communicate via EventBus signals; directors may read GameState but never write each other directly.

## Player & camera

- `CharacterBody3D` + custom `player_controller.gd` (move_and_slide; ground snap; lock-on strafe mode).
- Camera: SpringArm3D (3.5 m, margin 0.4) + camera collision via `PhysicsShapeQueryParameters3D` exclusion of player; lock-on lerps yaw to target; touch drag and mouse both feed `InputRouter.camera_delta`.
- Animations: single AnimationPlayer per humanoid sharing the UAL animation library; state machine implemented in code (`combat_player.gd`) not AnimationTree (4.4-compatible and testable headless).

## Combat architecture

- `combat/disciplines/*.gd` (5 classes: brawler, kickboxing, grappling, drunken, weapon) share a `Discipline` interface: `get_combo(action) -> AttackDef`, `modifiers`, `counter_rules`.
- AttackDef: animation name, damage, stamina, startup/active/recover frames, hit shape (sphere at offset), knockback, stagger.
- Hit resolution: per-active-frame sphere overlap query; `EventBus.hit_landed` carries damage/kind; NPC health/death handled by their controllers; player i-frames during dodge roll.

## Vehicles & traffic

- `VehicleBody3D` player cars/motorcycles (custom center-of-mass, wheel traction curves tuned for touch steering).
- Traffic: `traffic_manager.gd` keeps N (12-18 by quality setting) AI cars on lane splines; intersection right-of-way by simple phase clocks; pedestrian avoidance raycast. Cars are Node3D bodies without VehicleBody physics (kinematic follow) to stay mobile-cheap; they turn into "drivable" full bodies when the player jacks them? — **Design decision: traffic cars are lightweight kinematic agents; the player drives the same visual model with real VehicleBody physics on possession (swap node).**

## NPC simulation

- `npc_director.gd`: 16 named NPCs are always-instantiated but simulated at three LODs: FULL (within 60 m: animation, senses, schedule), LITE (60-150 m: position on schedule rail, cheap tick), FROZEN (>150 m: stored state).
- ~25 pedestrians pooled around the player, spawned/despawned by distance; routines driven by `TimeWeather.schedule_pressure()`.
- NPC memory = `GameState.npc_memory` + `npc_relationships`; memorable events recorded via `GameState.remember_npc_event()`; dialogue lines filter on memory keys.

## Police & wanted

- `police_system.gd`: wanted 0-5; heat value decays; spawn waves scale by level (foot patrol → cruisers → interceptors → SWAT-equivalent "Kestrel Tactical"); roadblocks at level ≥3; line-of-sise detection with reporting delay; losing wanted requires out-of-sight timer.

## Story & missions

- `mission_system.gd`: mission graph defined in `data/missions.json`-equivalent GDScript dictionaries (kept in code for 4.4-safe Resource loading simplicity); objectives typed (GOTO, FIGHT, DEFEND, COLLECT, DRIVE, CHOICE, ESCAPE).
- `dialogue_system.gd`: node-based conversations, choices with tags → `EventBus.choice_made`, consequences applied to GameState (flags, reputation, relationships), subtitle UI + phone message variants.

## Streaming & persistence

- World = one scene; six area roots with `visible`+`process_mode` toggling by player distance (cheap "streaming"), city geometry baked into shared MultiMeshInstance3D per material class (buildings, roads, props).
- Persistence via SaveSystem JSON (see `save_system.gd`); world data: player pose, vehicles in use, time/weather, active world events.

## Testing strategy (honest taxonomy)

- Headless Godot 4.4.1 runs `tests/run_tests.gd` with `LEVERAGE_TEST=1`: boots every autoload, exercises menus, spawns world, drives scripted input frames through InputRouter, runs combat/mission/traffic sim ticks, asserts invariants, writes `test_reports.md` rows. **This is "Tested", never "Verified".**
- "Verified" = rendered screenshots from Godot 4.4.1 `--write-movie`-less viewport capture on a software GL context (if the sandbox GL allows; else stays Device-only).
- "Device-only" = iPhone + XOGOT: PCK export instructions in `final_verification_guide.md`.

## Performance budget (Mobile renderer)

- Draw calls < 120 typical; skinned humanoids < 20 on screen; shadows: directional 2048, only player + vehicles cast; MSAA 2x; physics ticks 30 Hz for traffic agents; texture budget ≤ 256 MB with ETC2/ASTC.
