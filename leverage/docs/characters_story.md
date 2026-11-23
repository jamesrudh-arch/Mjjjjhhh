# LEVERAGE — Characters, Story & Missions

Protagonist: **Dez Carter**, 34, former repo-man (car repossession), quick hands, bad sleep. The tagline is literal: everyone — Family, Corporation, Crew, even allies — holds leverage over him by the time the credits roll.

## The three powers

- **The Family** (Old Quarter/Heights) — Castellane crime family. Boss: **Vito "Ledger" Castellane**. They financed Tommy's debt and took him.
- **Kestrel Corporation** (Financial District) — private security, data leverage, clean hands. Executive: **Ava Kestrel**.
- **Vetch Crew** (Docklands/Ironworks) — street-level muscle running docks cargo. Boss: **Ren Vetch**.

## 16 named NPCs (id, role, anchor, discipline links)

1. `dez` — player.
2. `tommy` — brother, hostage (appears in cinematics + rescue mission).
3. `marisol` — bar owner, Marisol's Bar; Drunken discipline arc; ex-boxer.
4. `big_theo` — gym owner, Iron Gym; Kickboxing + Grappling training arc.
5. `vito` — Family boss, Castellane Villa.
6. `rizzo` — Vito's lieutenant, hands out dirty jobs.
7. `ava` — Kestrel executive; offers the "clean way out".
8. `ren` — Vetch Crew boss; docks antagonist.
9. `lucy_fang` — Vetch enforcer, recurring miniboss.
10. `officer_brant` — honest cop, potential ally (community rep path).
11. `sergeant_oduya` — patrol sergeant, recurring pursuer.
12. `doc_lennox` — clinic doctor; respawn/heal services.
13. `nadia` — pawn shop owner (Pawn & Barrel), arms dealer, fence.
14. `juno` — Dez's neighbor, phone contact, side jobs.
15. `cabbie_moses` — taxi driver, radio monologues, fast travel option.
16. `the_tipster` — anonymous phone contact feeding side jobs.

Named-NPC animation identities (mannequin rig): signature idle/tint + accessory (hat/cap/ponytail); `big_theo` gets ring-idle; `marisol` gets towel-wipe custom loop, etc. via tint/attachment combos.

## Story arc — 5 chapters + finale (choices with consequences)

**Ch 1 — "Everyone has leverage on you."**
Cinematic: Tommy's kidnapping (Dez comes home to a ransacked room, phone rings: "Your brother owes Ledger. He works for us now — so do you."). Tutorialized entry: movement/camera in Old Quarter → first fight (Vetch collectors in the market) → first drive (junk car to the pawn shop) → phone intro.
Mission 1 `debt_first` (FIGHT collectors) → Mission 2 `make_change` (steal back repo'd car, DRIVE) → Mission 3 `rendezvous` (meet Rizzo at the docks; CHOICE: give the car to Family or hide it for Kestrel's offer — first fork recorded).

**Ch 2 — "The gym and the bar."** Big Theo gym arc (Kickboxing unlocked; training minigames), Marisol bar arc (Drunken unlocked; Lucy Fang shakes the bar down — defense fight). Choice: pay Lucy off / fight her crew / tip off Brant. Relationship forks for `marisol`, `big_theo`, `officer_brant`.

**Ch 3 — "Clean hands."** Ava Kestrel: data leverage on the Family. Heists into Kestrel Tower (sneak or front-door CHOICE), sabotage `neon_blackout` side mission ties in. Choice: burn Family ledger for Kestrel / keep it as YOUR leverage → world: family reputation collapse vs. power grab; Vito's heat on player.

**Ch 4 — "Everything is collateral."** Gang war in the streets (turf_skirmish world event). Grappling unlocked via gym tier 2. Lucy Fang boss fight at the scrapyard. Tommy letter side mission humanizes the stakes.

**Ch 5 — "Leverage."** The trade: bring the ledger/ledger-equivalent to the scrapyard meet. Finale: rescue Tommy — combat gauntlet + vehicle chase out of Docklands. Final CHOICE at the Villa: (a) kill Vito (Family collapses, Oduya arrest warrant, "Blood Ledger" ending), (b) accept Vito's counter-deal (Family ending — you become Rizzo's boss; Tommy freed but cabbie/commmunity fear you), (c) hand ledger to Brant (Community ending — Family dismantled, Ava keeps Kestrel leverage over YOU: the tagline lands), (d) give ledger to Ava (Corporation ending — city cleaned of Family but Kestrel owns the city; epilogue slides).

Endings gate on accumulated `reputation`/flags: four endings + epilogue text cards; post-credits free roam with world state reflecting choices (district patrols, shop prices, NPC greetings).

## Side content

- Side jobs via Tipster/Juno (8+: courier, repo-man callbacks, pickpocket parade, bar bounce, taxi fares via Moses).
- Collectibles: 20 "Cinder Tokens" (graffiti tags) → cash + lore.
- Trainings (gym) discipline XP minigames.
- Radio stations: `cinder_fm` (neo-noir), `strip_wave` (synthpop), `iron_pulse` (industrial) — synthesized loops with Moses monologues between tracks on cinder_fm.

## Mission objective types

GOTO, TALK, FIGHT (defeat N tagged enemies), DEFEND (timer survival), COLLECT (pickups), DRIVE (route with optional damage/time), ESCAPE (wanted wipe), CHOICE (dialogue fork), INTERACT.

Consequence records: every CHOICE writes `story_flags` + at most 2 reputation deltas + up to 3 relationship deltas — enforced by `MissionSystem.apply_consequence()` schema.
