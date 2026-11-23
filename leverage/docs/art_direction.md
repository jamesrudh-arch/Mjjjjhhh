# LEVERAGE — Art Direction Guide

**One sentence:** neo-noir under cinder-amber light — a low-poly city of charcoal concrete and warm street glow, where every material is honest (flat color, minimal texture) and every silhouette is readable from a moving camera.

## Palette (authoritative — LvgTheme constants)

- Charcoal `#15161a` — night base / UI base
- Panel `#1d1f24` / Lift `#25272e` / Line `#2a2d34` — UI surfaces
- Text `#e8e6e3` / Dim `#9a9a94`
- **Cinder amber `#f0a33c`** — hero accent (title, wanted, objectives, neon)
- Deep amber `#c8761f` — pressed states, danger-glow edges
- Danger `#d64541` (damage/low health), Police blue `#3b6fd6` (cop accents, sirens), Success `#5aa05a`.

District tints: Old Quarter = warm brick `#6e4a33`; Docklands = cold steel `#3a4448`; Kestrel = glass gray-blue `#5a6a7e` + white emission; Neon Strip = magenta/amber neon `#d84fa0`/`#f0a33c`; Ironworks = rust `#7a3b28`; Heights = sandstone `#8a7a5a` + greenery `#3a5a3a`.

## Form language

- Low-poly, flat-shaded or 1-2 tone gradient; no baked AO maps; MSAA 2x carries the edges.
- Buildings: simple massing with strong silhouettes; window emission masks for night life (10% random lit).
- Characters: mannequin-derived rig with tinted tops/bottoms/skin; faceless is intentional for pedestrians, named cast get signature colors + accessories (hat, cap, ponytail, jacket collar) + floating name tag when relevant.
- Vehicles: toy-like proportions (slightly cab-forward), readable colors; damage = dark tint + smoke particles.

## Lighting

- Sun warm 4800K; dusk orange; night moon `#4a5a8a` low energy; street lamps as static omni-lite quads (fake light planes + a few real OmniLight3D near player only — Mobile renderer budget).
- Rain: world roughness down, reflections faked via emission ramps; storm = 2-3 s lightning flash (Environment energy spike) + thunder SFX.

## Camera & feel

- Third person 3.5 m spring arm, 8° down pitch, FOV 62 (slight widescreen letterbox during cinematics: black bars 12%).
- Combat lock-on: yaw lerps to target; hits get 6-frame 0.6 camera micro-shake; heavy finishers get 0.3 s 18% slowmo (engine time scale).

## UI look

Lilita One display caps for headers; Liberation Sans for body; amber rules 4 px with deep-amber edge; panels 2 px border, 6 px corner; buttons ≥ 96 px height on touch. HUD: thin bars (health amber→red, stamina white, armor blue), wanted stars top-right under minimap. Toasts bottom-center. Phone: full-screen dark sheet with message bubbles; radio chip bottom-left in vehicle.

## Audio-visual sync

Neon Strip signs blink with strip_wave music pulse (energy modulated by beat clock from AudioSystem).

## Out-of-brand

No gradients on UI surfaces, no photo textures, no realistic shading, no emoji glyphs in UI.
