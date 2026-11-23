# LEVERAGE — Development State

**THE authoritative status document. Read this first when resuming work.**
Project root: `leverage/` (single authoritative project — no backups, no duplicates).
Status taxonomy: **Implemented** (code exists) / **Tested** (verified by automated headless run) / **Verified** (rendered and visually confirmed) / **Device-only** (requires iPhone + XOGOT hardware; never claimed from sandbox).

Last updated: 2026-11-23 (session 3 — audit + close-out). **State: DELIVERED.**

## Environment facts (verified)

- Sandbox: Debian 13 (trixie) x86_64, 2 cores, ~4 GB RAM, ~5 GB free disk.
- Godot **4.7.2-stable** AND **4.4.1-stable** Linux binaries at `tools/` (headless works on both).
- Blender **4.5.9 LTS** at `tools/blender-4.5.9-linux-x64/` (FBX/glTF pipeline — used for the motorcycle authoring in session 3).
- Python 3.12 + requests/beautifulsoup4; Node 24. Network: quaternius.com, github.com, itch.io, opengameart.org, drive.google.com reachable. kenney.nl 403, poly.pizza unreachable.
- XOGOT runtime is Godot-4.4-based; project targets the **4.4-compatible API subset** (`config/features=PackedStringArray("4.4","Mobile")`) so one PCK runs under XOGOT and stays openable in 4.7. **All headless tests run on Godot 4.4.1** (the runtime version that matters); 4.7.2 is secondary validation.
- Mobile renderer is the rendering method (`renderer/rendering_method="mobile"`).

## Current state (session 3 close-out)

- **238/238 automated checks PASS** on: 4.4.1 (project dir), 4.7.2 (project dir), and 4.4.1 running from the exported `leverage.pck` (package completeness proof). Evidence: `docs/test_reports.md`, machine summary `tests/last_run.txt`.
- Motorcycles shipped (R13 closed): authored GLB + `Motorcycle` class + parked spawns + 12 checks.
- `export_presets.cfg` ("XOGOT PCK", feature `mobile`, ETC2/ASTC) and `leverage.pck` (13.4 MB) in project root; PCK included in the delivered zip.
- Visual evidence: 7 non-blank distinct captures in `tests/render_out/` (programmatic verification this session; sandbox lacks a vision model — on-device look is Device-only).
- Docs complete and current: master_design, technical_architecture, art_direction, world_design, characters_story, control_map, asset_register, requirements_traceability, technical_decision_log, development_state (this file), changelog, test_reports, known_defects, final_verification_guide, delivery_report.

## Open work — nothing blocking delivery

- **Device-only**: everything in `docs/final_verification_guide.md` (iPhone + XOGOT install/run checklist, fps/memory targets). Sandbox evidence never substitutes for it.
- Polish backlog (non-blocking, recorded not dropped): seated rider mesh while driving (D5); bike traffic AI (D6); armour-specific harness row (R12); phone/radio dedicated harness rows (R23).
- Sandbox headless artifacts (D4) — accepted, cosmetic.

## Exact resumption point (for any future session)

1. Read this file, then `docs/delivery_report.md`, then `docs/requirements_traceability.md`.
2. To re-verify everything in ~2 minutes: `LEVERAGE_TEST=1 tools/Godot_v4.4.1-stable_linux.x86_64 --headless res://tests/test_runner.tscn` (expect `238 checks, 0 failed`).
3. To rebuild the PCK: `tools/Godot_v4.4.1-stable_linux.x86_64 --headless --export-pack "XOGOT PCK" leverage.pck --path .`
4. To re-render captures: `LEVERAGE_RENDER=1 tools/Godot_v4.4.1-stable_linux.x86_64 --headless res://tests/render_probe.tscn`.
5. New defects → `docs/known_defects.md` rows (never delete). New decisions → `docs/technical_decision_log.md` with sources. Status moves only with evidence.

## Rules of engagement (from directive)

- Never claim sandbox test = iPhone verification. iPhone/XOGOT checks are **Device-only**.
- No backups/duplicate projects; this directory is the single truth.
- Record technical decisions with sources; do not silently drop any requirement.
