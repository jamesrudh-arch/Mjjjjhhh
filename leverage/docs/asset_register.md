# LEVERAGE — Asset Register & Licence Record

Every shipped asset, its provenance, and licence. Project license stance: all third-party assets are CC0 (public domain dedication) — no attribution legally required, credited here regardless. Original assets are © D'Youngs Games, licensed for use within this project.

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

**Motorcycle** — `assets/vehicles/motorcycle.glb` is **original, authored in-project** via `scripts/make_motorcycle.py` (Blender 4.5.9 headless; cubes/cylinders, 4 materials). © D'Youngs Games — no third-party licence applies.

## Fonts

| Font | Path | Licence |
|---|---|---|
| Lilita One (display) | `assets/fonts/lilita_one_regular.ttf` | SIL OFL 1.1 (`LICENSE-lilita.txt`) |
| Liberation Sans (body/bold) | `assets/fonts/LiberationSans-*.ttf` | SIL OFL 1.1 + exceptions (`LICENSE-liberation.txt`) |
| DejaVu Sans (fallback mono) | `assets/fonts/DejaVuSans.ttf` | Bitstream Vera/PDL + GPL exception — used as UI fallback only |

## Audio

All `.wav` files under `assets/audio/` are **synthesized for this project** by `scripts/audio_gen.py` (numpy DSP: music beds, ambience loops, SFX set, radio jingles). © D'Youngs Games — original, no third-party samples.

## Textures / materials

Flat-color StandardMaterial3D + small procedurally generated textures (noise-based asphalt, window emission masks) authored in code. No third-party textures shipped.

## Attribution (CC0, credited voluntarily)

- Quaternius (quaternius.com) — character, animation, vehicle, city, furniture, gun packs.
- If we ship any OpenGameArt item later, it gets a row here BEFORE entering `assets/`.
