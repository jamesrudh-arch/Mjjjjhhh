# LEVERAGE — World Design: Cinder City

One contiguous map ≈ 1.4 × 1.4 km, six areas bolted together by roads. Coordinates in meters, origin at city center (0,0,0). North = -Z. Ground plane y=0.

## Map layout (top view)

```
            THE HEIGHTS (north, y up to 40 on hill)
                   | Hill Road (serpentine)
 OLD QUARTER ---- MAIN CROSS ---- KESTREL FINANCIAL (east, towers)
   (west, dense)        |                  |
   Old Docks Rd    CIVIC AVENUE        Bridge Ave
                   |                  |
 DOCKLANDS ----- CANAL DISTRICT? no — IRONWORKS (south-west, industrial)
                   |
            NEON STRIP (south, night life)
```

Six areas (authoritative ids):

| id | name | extents (m) | character | landmark |
|---|---|---|---|---|
| `old_quarter` | Old Quarter | x -450..-80, z -380..-40 | low brick, alleys, markets | Marisol's Bar (story) |
| `docklands` | Docklands | x -450..-80, z 40..420 | warehouses, cranes, containers | The Docks (Tommy's job site) |
| `kestrel_district` | Kestrel Financial District | x 80..450, z -380..-40 | glass towers, plaza | Kestrel Tower (Corporation HQ) |
| `neon_strip` | Neon Strip | x 80..450, z 40..420 | clubs, neon, crowds | The Verdigris club |
| `ironworks` | Ironworks | x -420..-120, z 480..760? — south band beyond docklands | factories, scrapyards | Scrapyard arena (finale) |
| `heights` | The Heights | x -120..300, z -720..-420 | villas on the hill, quiet | Castellane Villa (Family) |

Road grid: MAIN CROSS (E-W, z=-10), CIVIC AVENUE (N-S, x=10), Hill Road north, Bridge Avenue east, Old Docks Road west, Iron Spine south. All roads two-lane 12 m + sidewalks 3 m; intersections with phased traffic lights (traffic_manager).

## Interiors (load into same scene, x=+2000 "interior shelf" zone)

- Marisol's Bar (old_quarter): bar counter, stools, tables, jukebox → dialogue hub for Drunken arc.
- Iron Gym (ironworks edge): ring, bags → discipline training, Big Theo.
- Dez's Apartment (old_quarter): bed (save), wardrobe (outfits), radio, phone.
- Lennox Clinic (old_quarter/docklands border): respawn point.
- Kestrel Tower lobby (kestrel_district): mission site.
- Pawn & Barrel shop (old_quarter): weapons/armor purchase. Threads & Threads (neon_strip): outfits. QuickMart kiosks: food (health).

## NPCs placement

16 named NPCs have home/work/evening anchors (see `characters_story.md`); ~25 pedestrians per active area with spawn tables per area and hour; night shifts densities to Neon Strip; rush hour via `schedule_pressure()`.

## World events (persistent, `world_events.gd`)

| id | trigger | effect |
|---|---|---|
| `market_bust` | day 1, 10:00 | Old Quarter market police raid; market stalls close for 2 h |
| `dock_strike` | after chapter 2 choice | Docklands workers picket; traffic slows, mission availability changes |
| `storm_warning` | weather=storm | NPCs run indoors, umbrellas, puddle reflections |
| `neon_blackout` | after "Sabotage" side mission | Neon Strip lights dim for one night |
| `turf_skirmish` | when family rep < -20 | Old Quarter alleys get Vetch Crew patrols |
| `mayoral_parade` | day 3, 14:00 | Main Cross closed, crowd NPCs, pickpocket side job |

## Weather & day/night

24-minute full day; dawn/dusk graded via WorldEnvironment color/energy lerps; street lamps + window emission masks on after 19:00; rain/storm states with particle precipitation and wet-roughness lowering; storm adds lightning flashes + thunder SFX. Rain intensity 0..1 smooth.

## Wanted-system area rules

Police response is fastest in Kestrel District (Corporation security = private police 1 tier higher), normal in Old Quarter/Heights, slower in Docklands/Ironworks, lowest in Neon Strip (crowds, bribes). Heat decays by area multiplier.
