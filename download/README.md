# LEVERAGE — use the right file (v2.4.0 "Alive City")

- `LEVERAGE_v2.4.0_XOGOT_project.zip` (102 MB) — for **Xogot on iPhone/iPad**:
  1) in the Files app tap the zip ONCE to extract (open the extracted
  FOLDER, never the zip, in Xogot), 2) open it in Xogot, 3) press Play.
  The asset cache is pre-imported (4.7-native) so the first open is fast.
  Full steps + troubleshooting: `FIRST_READ.txt` inside the zip and
  `docs/final_verification_guide.md`.
- `LEVERAGE_hello_diag_project.zip` (5.8 KB) — **try this first if anything
  misbehaves**: a zero-dependency 30-second test of the exact same delivery
  path (open folder in Xogot -> Play). Its FIRST_READ.txt tells you how to
  read the result (delivery problem vs in-game problem).
- `LEVERAGE_2.4.0.pck` (44 MB) — desktop **Godot 4.4-4.6 only**:
  `godot --main-pack LEVERAGE_2.4.0.pck` (4.7+ desktop rejects 4.4-built packs).
- `LEVERAGE_v2.4.0_Audit_and_WorldClass_Report.pdf` — the full
  audit-test-verify results, research and upgrade recommendations
  (session 10), re-verified end-to-end in session 11.
- `LEVERAGE_delivery_report.md` — what shipped, how it was verified,
  install steps.
- `CHECKSUMS.txt` — SHA-256 + byte size of every file here; compare after
  transfer if anything misbehaves.

## What's new in v2.4.0
- Random street encounters (muggings, drug deals, brawls, dropped stashes)
- Wanted-evasion arc: blinking stars while police search, EVADED payoff
- 5-star police helicopter with searchlight
- Mission medals (BRONZE/SILVER/GOLD) for replay
- Pedestrian panic (screams + cower); vehicle engine sound restored
