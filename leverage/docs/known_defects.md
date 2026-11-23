# LEVERAGE — Known Defects

Open defects. Each has status and the taxonomy — never mark a sandbox fix as device-verified.

| id | Description | Severity | Status | Notes |
|---|---|---|---|---|
| D1 | `ui_theme.gd` referenced absent `LiberationMono-Regular.ttf` | med | **Fixed** | switched to DejaVuSans fallback (TDL #11) |
| D2 | project.godot declared 6 autoload scripts that did not exist — project failed to boot | blocker | **Fixed** | autoloads implemented this session |
| D3 | Sandbox has no GPU; "Verified" visual checks limited to headless captures where GL allows | info | Accepted | see test_reports.md method notes |
| D4 | Headless runs print `Parameter "material" is null` (×2, dummy rendering storage) during time.weather suite, and 4.7.2 prints "N resources still in use at exit" | low | **Accepted (headless-only artifact)** | Occurs identically in project-dir and PCK runs; suite passes 238/238 regardless; no evidence of gameplay impact; dummy renderer path only (no GPU in sandbox) |
| D5 | Rider mesh hidden while riding (cars and motorcycles alike); camera follows the vehicle | low | **By design** | consistent enter/exit contract; seated-rider posing would need per-seat mount animations — recorded as a polish backlog item, not a correctness defect |
| D6 | Traffic AI drives cars only; motorcycles are player-usable (parked spawns) | info | **By design (TDL #14)** | traffic corridors optimised around car silhouettes; bike traffic would need separate lane logic |

## Open items: none blocking. D4 accepted (headless artifact), D5/D6 by design (documented limitations).

(Discipline: new defects get rows here with reproduction and fix status; never deleted.)

## Session 4 entries
- D7: PCK size 77 MB (28 char GLBs embed duplicate texture copies). Optimization backlog: shared texture atlas / runtime material assignment.
- D8: Vehicle/character close-up micro-polish (arch rims, hairline transitions) below AAA bar at macro distances; reads correctly at gameplay camera distance (3-10 m).
- D9: Key art recomposed from gameplay render; faint HUD remnants may appear behind menu scrim.
- D10: VLM single-frame reviews oscillate (3-7 on improving content); authoritative evidence = pixel sampling + game-distance renders + automated suite.
- D11: keyart_probe.gd world-capture path renders black (world/player async init under intro state) — key art composed from gameplay render instead.
