# LEVERAGE — Asset Register & Licence Record

Every shipped asset, its provenance, and licence. Project license stance: all third-party assets are CC0 (public domain dedication) — no attribution legally required, credited here regardless. Original assets are © DE YOUNG GAMES, licensed for use within this project.

## Characters & animation

| Asset | Path | Source | Licence |
|---|---|---|---|
| Universal Animation Library (Mannequin + 46 anims) | `assets/characters/ual_mannequin.glb` | Quaternius "Universal Animation Library" (free/standard glTF version), via GitHub mirror `gltf-universal-animation-library` & itch.io page | **CC0 1.0** |
| Animated Men Pack (8 male meshes, 11 anims each) | `tools/assets_raw/animated_men/*.fbx` | Quaternius "Animated Men Pack" | **CC0 1.0** |
| Animated Women Pack | `tools/assets_raw/animated_women/*.fbx` | Quaternius "Animated Women Pack" | **CC0 1.0** |

## Vehicles / city / props (all Quaternius, downloaded from official Drive links)

| Pack | Contents used for | Licence |
|---|---|---|
| Ultimate Cars | player + traffic vehicles | CC0 |
| Public Transport | bus/tram ambient traffic | CC0 |
| Modular Streets | road pieces, sidewalks, lights, signs | CC0 |
| Textured Buildings / Simple Buildings | building volumes per district | CC0 |
| Home Interior / Furniture | interiors (Marisol's bar, gym, apartment, clinic) | CC0 |
| Ultimate Guns | pistol/rifle/shotgun visuals | CC0 |

**Motorcycle** — `assets/vehicles/motorcycle.glb` is **original, authored in-project** via `scripts/make_motorcycle.py` (Blender 4.5.9 headless; cubes/cylinders, 4 materials). © DE YOUNG GAMES — no third-party licence applies.

## Fonts

| Font | Path | Licence |
|---|---|---|
| Lilita One (display) | `assets/fonts/lilita_one_regular.ttf` | SIL OFL 1.1 (`LICENSE-lilita.txt`) |
| Liberation Sans (body/bold) | `assets/fonts/LiberationSans-*.ttf` | SIL OFL 1.1 + exceptions (`LICENSE-liberation.txt`) |
| DejaVu Sans (fallback mono) | `assets/fonts/DejaVuSans.ttf` | Bitstream Vera/PDL + GPL exception — used as UI fallback only |

## Audio

All `.wav` files under `assets/audio/` are **synthesized for this project** by `scripts/audio_gen.py` (numpy DSP: music beds, ambience loops, SFX set, radio jingles). © DE YOUNG GAMES — original, no third-party samples.

## Textures / materials

Flat-color StandardMaterial3D + small procedurally generated textures (noise-based asphalt, window emission masks) authored in code. No third-party textures shipped.

## Attribution (CC0, credited voluntarily)

- Quaternius (quaternius.com) — character, animation, vehicle, city, furniture, gun packs.
- If we ship any OpenGameArt item later, it gets a row here BEFORE entering `assets/`.

## Session 4 — authored assets (all original works, made for this project; CC0-equivalent)
- assets/textures/*.png — 17 procedural PBR sets (albedo/rough/normal) authored via scripts/build_textures.py.
- assets/characters/char_*.glb — 28 procedural human bodies (scripts/build_character.py) on the UAL DEF-* skeleton; embedded textures from assets/textures.
- assets/vehicles/*.glb — 8 procedural vehicles (scripts/build_vehicle.py); replaces Quaternius packs in-game.
- assets/buildings/b_*.glb — 19 procedural buildings (scripts/build_building.py).
- assets/props/*_v2.glb, tree_*.glb, hydrant/bin/bench/busstop/billboard/dumpster/barrier — 13 procedural props (scripts/build_props.py).
- assets/ui/portraits/*.png — 16 in-engine rendered contact head shots.
- assets/ui/keyart/menu_bg_0.png — cinematic key art composed from an in-engine render.
- UAL mannequin (itch.io, CC0) retained as the animation library + skeleton source only.

## v2.5.0 additions
- **Buildings (19 slots)**: recomposed from the Quaternius Downtown City
  MegaKit (CC0) plain wall/cornice/column modules + project-authored window
  units, doors, neon signs, roofs (compose_buildings_v3). Original (c) DE
  YOUNG GAMES composition; kit modules CC0.
- **megakit_tex/ (12 maps)**: downscaled from the MegaKit texture set (CC0),
  1024 basecolor / 512 normal+ORM, shared by all buildings.
- **road_dash.png**: project-authored dashed center-line texture (original).
- **Fonts**: Anton + Oswald (SIL OFL 1.1, see LICENSE-anton-oswald.txt).
- **SFX (10)**: sfx_train_horn, sfx_train_rumble, sfx_station_bell,
  sfx_water_lap, sfx_splash, sfx_gull, sfx_pigeon_flutter, sfx_crickets,
  sfx_logo_sting, sfx_explosion — original numpy DSP (audio_gen_v250.py).
- **River/wildlife/gas/train/explosion systems**: all geometry code-built
  (originals, (c) DE YOUNG GAMES); no third-party assets.
