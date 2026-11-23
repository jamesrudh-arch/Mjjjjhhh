# LEVERAGE — Final Verification Guide (iPhone + XOGOT)

This is the **Device-only** checklist. Sandbox evidence never substitutes for it.

## What you need

- An iPhone (iOS 16+) with **XOGOT** installed (App Store; free Godot player by Indie developer — the app embeds a Godot 4.4-series engine with Mobile renderer).
- The exported game package `leverage.pck` produced from this project (Godot 4.7.2 or 4.4.1 → Export → PCK/ZIP; feature tag "mobile"). The export preset is `export_presets.cfg` in the project root.
- Transfer: AirDrop / Files app / XOGOT's document import. Open the .pck with XOGOT ("Open in XOGOT").

## Install steps

1. Copy `leverage.pck` to the iPhone.
2. Share sheet → Open in XOGOT. XOGOT registers the package and lists it in its library.
3. Launch from XOGOT's library. Landscape lock recommended.

## Device verification checklist (mark each PASS/FAIL)

Boot flow:
- [ ] D'YOUNGS GAMES card shows full duration; LEVERAGE title + tagline; content notice; main menu.
- [ ] New Game → opening cinematic plays with subtitles; skip with X works.

Controls:
- [ ] Virtual joystick moves Dez; right-half drag orbits camera.
- [ ] Combat: X = punch, Y = heavy, A = kick, B = dodge roll — exact fixed mapping.
- [ ] B enters/exits vehicles; vehicle pedals steer; X = handbrake.
- [ ] MFi gamepad (if any) matches the physical map in control_map.md.

Performance (60 Hz target, 30 acceptable):
- [ ] Old Quarter street scene holds ≥ 30 fps with pedestrians + 3 traffic cars.
- [ ] Combat vs 4 enemies holds ≥ 30 fps; no hitch > 250 ms on discipline switch.
- [ ] Rain scene: frame time stable; storm lightning doesn't tank fps.
- [ ] Memory: app stays under ~700 MB RSS after 20 minutes free-roam.

Systems:
- [ ] Autosave at 2-minute cadence; Continue restores money/area/time.
- [ ] Wanted 1→5 escalation + roadblocks at 3; losing wanted via out-of-sight.
- [ ] Phone messages arrive on story beats; radio stations switch in vehicles.
- [ ] Choices recorded: chapter 3 ledger choice alters endgame availability.
- [ ] Weather/day-night: night street lights + window emission; rain wet look.

Completion:
- [ ] Full campaign from Ch 1 to one ending; credits; post-credits free roam.
- [ ] No crash across a 30-minute session; airplane-mode safe (no network calls).

## Reporting back

Record device model, iOS version, XOGOT version, fps observations, and any FAIL rows → append to test_reports.md as Device-only section. Any FAIL becomes a Known Defect with device reproduction notes.
