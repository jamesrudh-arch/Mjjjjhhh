# LEVERAGE — Known Defects

Open defects. Each has status and the taxonomy — never mark a sandbox fix as device-verified.

| id | Description | Severity | Status | Notes |
|---|---|---|---|---|
| D1 | `ui_theme.gd` referenced absent `LiberationMono-Regular.ttf` | med | **Fixed** | switched to DejaVuSans fallback (TDL #11) |
| D2 | project.godot declared 6 autoload scripts that did not exist — project failed to boot | blocker | **Fixed** | autoloads implemented this session |
| D3 | Sandbox has no GPU; "Verified" visual checks limited to headless captures where GL allows | info | Accepted | see test_reports.md method notes |
| D4 | Headless runs print `Parameter "material" is null` (×2, dummy rendering storage) during time.weather suite, and 4.7.2 prints "N resources still in use at exit" | low | **Accepted (headless-only artifact)** | Occurs identically in project-dir and PCK runs; suite passes 238/238 regardless; no evidence of gameplay impact; dummy renderer path only (no GPU in sandbox) |
| D5 | Rider mesh hidden while riding (cars and motorcycles alike); camera follows the vehicle | low | **Fixed (v2.3.0)** | seated rider stand-in from the player's own body, `Sitting_Idle`, per-class seat offset (car y=0.20 tuned; bike astride y=0.52); freed on exit. VLM-verified in probe + in-world (D10/D16 discipline) |
| D6 | Traffic AI drives cars only; motorcycles are player-usable (parked spawns) | info | **Fixed (v2.3.0)** | 14% bike agent share + 2 seeded bikes, NPC riders on AI bikes, bike jack converts to a real Motorcycle body; TDL #14 scope note superseded |

## Open items: none blocking. D4 accepted (headless artifact); D5/D6 fixed in v2.3.0; D16 is a measurement caveat, not a defect.

(Discipline: new defects get rows here with reproduction and fix status; never deleted.)

## Session 4 entries
- D7: PCK size 77 MB (28 char GLBs embed duplicate texture copies). Optimization backlog: shared texture atlas / runtime material assignment.
- D8: Vehicle/character close-up micro-polish (arch rims, hairline transitions) below AAA bar at macro distances; reads correctly at gameplay camera distance (3-10 m).
- D9: Key art recomposed from gameplay render; faint HUD remnants may appear behind menu scrim.
- D10: VLM single-frame reviews oscillate (3-7 on improving content); authoritative evidence = pixel sampling + game-distance renders + automated suite.
- D11: keyart_probe.gd world-capture path renders black (world/player async init under intro state) — key art composed from gameplay render instead.

## Session 5 entries
- D12: One storefront billboard shows streaky/smeared vertical artifacts under the Mobile renderer (VLM single-frame review). Suspect UV/mip on one emissive sign texture; verify on device before rebuilding the texture.
- D13: Single-frame VLM review reported one pedestrian near T-pose; all anims referenced by new idle-variety code verified present on the mannequin (57/57). Likely spawn-transition frame or VLM oscillation (D10) — re-check in motion on device.

## Session 6 entries
- D14: (resolves D12) Billboard streak artifact fixed at source (authored poster texture + flat maps). Minor dark-edge read at distance remains possible; check on device.
- D15: Cinematic overlay fade used only for future state transitions; menu->game entry fade-in not yet wired to GameManager (title card + letterbox ARE live).

## Session 7 entries (v2.3.0)
- D15 **closed**: GameManager state-fade layer wired — world entry fades in from black (probe telemetry 1.0→0.46→0.0); MainMenu entry fade; and the latent never-freed-menu flow bug fixed (menu no longer overlays the world after NEW GAME).
- D9 **fixed**: key art recomposed from a HUD-free dusk capture (call declined, HUD/touch/banner hidden) — no more HUD remnants; menu renders from the PCK (VLM PASS).
- D13 **closed**: in-motion Mobile-renderer frames show pedestrians mid-stride (arms bent, walking) across multiple captures; no T-pose. Widened close-shot caveat: distant figures remain ambiguous at 1280×720 — device re-check if desired.
- D16 (new): single-frame VLM verdicts on DARK GLOSSY vehicle close-ups oscillate wildly ("collapsed/spiky" on byte-identical geometry that passed review in session 4). Counter-evidence: clay-pass silhouette solidity 0.838, accessor byte-equality vs v2.1.0 git blobs, A/B render equality old-vs-new. Rule reaffirmed (extends D10): vehicle integrity is judged at GAMEPLAY distance + objective metrics, never single-frame close-up VLM alone.
- Test-hygiene notes (not defects): phone suite queue race made deterministic; jack tests restore player position; from-pack runs cannot rewrite tests/last_run.txt (stdout is authoritative).
