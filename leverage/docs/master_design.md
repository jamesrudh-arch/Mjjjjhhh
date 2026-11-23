# LEVERAGE — Master Design Document

**Title:** LEVERAGE
**Tagline:** "Everyone has leverage on you."
**Genre:** third-person open-world crime-action drama
**Platform:** Godot 4.7 project authored on the 4.4-compatible API subset; Mobile renderer; runs via XOGOT on iPhone (landscape, touch + gamepad).
**Studio card:** D'YOUNGS GAMES presents.

## 1. Fantasy and pillars

You are **Dez Carter**, a former repo-man in **Cinder City**. Your brother Tommy owes the wrong people, they took him to make you work, and every job they hand you drags you deeper. The core loop: drive, fight, negotiate, choose — and watch the city remember.

Pillars:
1. **Leverage everywhere** — the story hook AND the systemic hook: NPCs remember what you did; relationships are currency; missions can be finished by force, stealth, money or reputation.
2. **Five fists, one city** — five unlockable combat disciplines (Brawler, Kickboxing, Grappling, Drunken, Weapon) that genuinely play differently: different combos, cancels, counters, risk/reward.
3. **A city that keeps score** — wanted levels, faction reputation, world events that persist between sessions, weather and day/night that change NPC routines.
4. **Mobile-first, console-feel** — fixed face-button combat (X punch, Y heavy, A kick, B dodge), lock-on camera, virtual joystick + touch buttons designed for thumbs.

## 2. Player

- Third-person character controller: walk/jog/sprint, jump, crouch, roll (dodge), lock-on strafing.
- Health + armor + stamina; stamina gates sprint, dodges and heavy attacks.
- Progression: money, discipline XP (per discipline), outfits (5+), weapons, collectibles.

## 3. Combat (fixed button map — authoritative)

| Button | In combat | Outside combat |
|---|---|---|
| X | Punch (light, chains) | Quick strike |
| Y | Heavy attack | Draw/holster weapon |
| A | Kick | Jump |
| B | Dodge (evade roll; late-window = counter) | Contextual interact |

Disciplines (see `characters_story.md` for unlock arcs):
- **Brawler** (start): jab-cross chains, simple but reliable.
- **Kickboxing** (Big Theo, gym): kick-first combos, push-kick keeps enemies off, better stagger.
- **Grappling** (gym tier 2): grabs → throws, counters deal big damage, weakest vs groups.
- **Drunken** (Marisol bar arc): sway evasion (auto-dodge chance while staggering), wild heavy hits, stamina-hungry.
- **Weapon** (first firearm acquired): pistol aim/fire, melee-with-gun, reload discipline.

## 4. World — Cinder City

Six connected areas (full detail in `world_design.md`): Old Quarter, Docklands, Kestrel Financial District, Neon Strip, Ironworks, The Heights. Roads connect all six; seamless single scene with distance-based NPC simulation and area streaming around the player.

## 5. Systems

- **Police**: 5 wanted levels, patrols scale with heat, arrest/death → Lennox Clinic respawn (fee).
- **NPCs**: 16 named (story cast) + ~25 pedestrians simulated by distance with routines (home→work→bar), memory of player actions, relationship values.
- **Missions**: story chapters with objectives, optional approaches, choices with consequences recorded as world state; side jobs.
- **Economy**: cash, shops (weapon/clothing/food), collectibles.
- **Phone**: contacts, messages (mission flow + story beats), radio stations.
- **Saves**: 3 slots + autosave; world position, story flags, reputations persist.

## 6. Opening flow (mandatory order)

1. D'YOUNGS GAMES presents card (2.4 s)
2. LEVERAGE title + tagline (3.0 s)
3. Content notice (2.2 s)
4. Main menu (Continue / New Game / Settings / Credits)
5. New Game → opening cinematic (Tommy's kidnapping; letterboxed, subtitles) → tutorialized entry (movement, camera, first fight, first drive, phone intro)

## 7. Audio identity

Neo-noir: brushed drums + upright bass for exploration day; dark synth tension; combat gets driving percussion; chase adds brass stabs. Ambience per area (docks: gulls+water; financial: glass+traffic; strip: crowd+neon hum). Radio stations in vehicles. All assets synthesized for this project (see `asset_register.md`).

## 8. UI/UX

Charcoal + cinder-amber palette, Lilita One display type, generous touch targets (min 96 px buttons), HUD scale option, minimap toggle, subtitle support. Pause menu; map; phone; shop screens; wanted stars; objective tracker; toasts for unlocks.

## 9. Out-of-scope / non-goals

Multiplayer; cutscene voice acting (text + synthesized stingers only); streaming-external-IP audio. iPhone-only target means no Android-specific tuning claims.
