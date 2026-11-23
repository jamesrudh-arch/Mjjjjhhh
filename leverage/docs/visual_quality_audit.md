# LEVERAGE — Visual Quality Audit (Session 4)

**Evidence:** VLM inspection of 5 fresh renders (tests/render_out/01..07, Godot 4.4.1 + Xvfb GL, 2026-11-23). Verdict from the independent art-director pass: **"low-poly mobile prototype — a Godot graybox with mannequin avatars"**.

## Genuinely good (keep)
- Control foundation: X=punch / Y=heavy / A=kick / B=dodge mapping, input router, touch controls.
- UAL animation library: 57 pro animations (walk/jog/sprint/idle/punch/kick/grapple/drunken/hit/death/driving/pistol) — reusable.
- Systems skeleton: save/load, event bus, state machine, audio system, phone UI shell, mission scaffolding.
- Headless test harness (238 checks) — keep as regression net.

## Basic / unacceptable as final presentation (replace)
1. **Characters:** untextured capsule mannequins, no faces/hair/clothing; identity via tint + box accessories. → REBUILD.
2. **World:** flat brown plane, plain box roads without markings/curbs, single-material cubes with painted-on windows, no trees, no parked cars, no street furniture, no variation. → REBUILD.
3. **Presentation:** boot/title/main menu are flat text panels; no key art, no cinematic composition. → REBUILD.
4. **Life:** near-empty streets, no traffic density feel, no crowd panic/ambience presence. → IMPROVE.
5. **Lighting/atmosphere:** default harsh single sun, washed-out palette, no fog, no night identity. → REBUILD.

## Overhaul plan (executing now)
- Procedural PBR texture set (asphalt+markings, brick, concrete, pavement, fabric, skin) via PIL.
- Blender-authored realistic humans (anatomy, faces, hair, layered clothing) skinned to the UAL DEF-* rig → keeps all 57 animations. Per-character variants for protagonist/16 named NPCs/enemies/pedestrians.
- Blender-authored detailed vehicles (body panels, glass, lights, wheels/rims/tyres, interiors) + per-class handling.
- Blender-authored architecture (5 district families, inset windows, sills, cornices, storefronts, signage, balconies, fire escapes) + rebuilt roads (markings, curbs, crosswalks), sidewalks, trees with sway, streetlights, parked cars, hydrants, bins, benches.
- Cinematic lighting: graded environment, day/night, fog, wet roads; camera FOV/composition pass.
- Systems: functional world map + GPS routing on road graph; missions 3–6 playable; phone with real incoming calls/ringtones/message threads; combat combos; police escalation.

Status taxonomy unchanged: Implemented / Tested / Verified / Device-only.
