# LEVERAGE — Final Verification Guide (iPhone + Xogot)

Device-only checklist. Sandbox evidence never substitutes for it.

## CORRECTION (session 8) + FIX (session 9) — the gray screen

**You were right — something was wrong, twice, and neither was your iPhone.**

1. **Delivery format (session 8, fixed)**: Xogot (App Store `id6469385251`, by
   Xibbon) is the full **Godot editor** for iPad/iPhone (embeds Godot 4.7). It
   opens Godot **project folders** — it cannot play a bare `.pck`. Sessions
   1–7 handed you a .pck → empty editor viewport → the uniform gray screen.
   v2.3.1 switched delivery to the project zip. **Never open the .pck in
   Xogot.**
2. **Dead-on-arrival UI scripts (session 9, fixed in v2.3.2)**: v2.3.1 also
   shipped two scripts that cannot parse on ANY Godot version — the in-game
   **Phone panel** and the **Pause Menu** were dead the moment you used them
   (`load()` returned null). One-line fixes each + a standing `scripts.parse`
   test suite that load-compiles every script so this class of bug can never
   ship again.

Sandbox proof for v2.4.0 (session 10, fresh imports): zero SCRIPT ERRORs,
**379/379 checks on Godot 4.7.2 (Xogot's engine) and 4.4.1**, from-pack
335/335, and the real boot-cards → main-menu flow rendered under Forward
Mobile + Vulkan with VLM-verified frames (title card, notice, menu with 3D key
art). The zip now also ships the **pre-imported asset cache** so the first
open on device is fast and cannot be killed mid-import.

## What you need

- iPhone, iOS 16+, **Xogot 1.7.12 or newer** (that release shows
  launch-failure reasons).
- The project in ONE of these forms:
  - **A. `LEVERAGE_v2.4.0_XOGOT_project.zip`** — sources + pre-imported
    `.godot` cache (AirDrop / iCloud Drive / Files).
  - **B. GitHub**: `https://github.com/jamesrudh-arch/Mjjjjhhh` (branch
    `main`) — Xogot can open projects directly from GitHub (this path has no
    cache, so it does the full on-device import once).

## Install — 5 steps, in order

1. Get the zip onto the iPhone (AirDrop / iCloud / Files).
2. **In the Files app, TAP THE ZIP ONCE to extract it** — this creates the
   `LEVERAGE_v2.4.0_XOGOT_project` folder. **Do not open the zip itself in
   Xogot.** (A long-press → Compress is the reverse; you want the folder.)
3. Open Xogot → open the **folder** (or its `project.godot`). If Xogot warns
   the project was last edited in another Godot version (tag "4.4"), confirm
   and continue — verified to import and run on the 4.7 generation. The
   pre-imported cache should make the first open quick; if Xogot's engine
   build differs it will re-import — keep it in the foreground until done.
4. Press **Play**. A few seconds of dark (shader compile) before the
   D'YOUNGS GAMES card is normal. Card → LEVERAGE title → content notice →
   main menu with key art = the gray screen is gone.
5. In game, CHECK the two fixed features early: **pause the game** (menu
   shows Save slots) and **open the Phone** (threads render, replies work).

If launch fails: Xogot 1.7.12+ shows the reason in its launch-failure panel;
the debugger Output pane prints `[LEVERAGE v2.4.0] boot start | Godot … |
renderer … | OS …` and `boot cards done -> main menu` — copy those lines into
the failure report.

## Device verification checklist (mark each PASS/FAIL)

Boot flow:
- [ ] D'YOUNGS GAMES card full duration; LEVERAGE title + tagline; content
      notice; main menu with key art.
- [ ] New Game → opening cinematic plays with subtitles; skip with X works.

Controls:
- [ ] Virtual joystick moves Dez; right-half drag orbits camera.
- [ ] Combat: X = punch, Y = heavy, A = kick, B = dodge roll — fixed mapping.
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

## Desktop alternative (optional sanity check)

**Godot 4.4–4.6 only** (a 4.4-built pack's binary scripts are rejected by
Godot 4.7+ — engine version lock, D19): `godot --main-pack LEVERAGE_2.4.0.pck`
from a folder containing the pack. Or open the project folder in any desktop
Godot 4.4–4.7 and press F5.

## Reporting back

Record device model, iOS version, Xogot version (Settings → About; the engine
line should read Godot 4.7.x), fps observations, and any FAIL rows → append to
`test_reports.md` as a Device-only section. Any FAIL becomes a Known Defect
with device reproduction notes.
