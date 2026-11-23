# LEVERAGE — Control Map (authoritative)

XOGOT on iPhone presents a virtual gamepad overlay when no MFi gamepad is connected; the same actions are also bound to keyboard for desktop testing. All bindings live in `project.godot` [input]; interpretation lives in `scripts/core/input_router.gd`.

## Face buttons — FIXED combat semantics (never remapped)

| Action | Combat context | Explore context | Vehicle context |
|---|---|---|---|
| `action_x` (X / J) | **Punch** (light, chains) | Quick strike | Handbrake |
| `action_y` (Y / I) | **Heavy attack** | Draw / holster weapon | — |
| `action_a` (A / K) | **Kick** | Jump | — |
| `action_b` (B / L) | **Dodge** (roll; late-window = counter) | Interact (talk/enter vehicle/pickup) | Exit vehicle |

Gamepad physical mapping (Xbox-style controller, Godot button indices): action_x=JOY_BUTTON_B(2)? No — authoritative: **action_x = button_index 2 (X on Xbox layout)**, **action_y = button_index 3 (Y)**, **action_a = button_index 0 (A)**, **action_b = button_index 1 (B)**, sprint = 10 (stick press), crouch = 12, lockon = 9 (right stick press), reload = 4 (LB), weapon_next = 5 (RB). XOGOT's virtual gamepad emits standard joy button indices, matching this map.

## Movement & camera

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| move_left/right/up/down | A/D/W/S | left stick | virtual joystick (left thumb zone) |
| sprint | Shift | L3 (10) | auto-sprint toggle + hold button |
| jump | Space | A (via action_a explore) | A button |
| crouch | C | 12 | hold toggle on HUD |
| camera | mouse (captured) | right stick | right-half drag |
| lockon | Q | R3 (9) | tap target chip |

## Combat extras

| Action | Keyboard | Gamepad |
|---|---|---|
| block | F (hold) | — (dodge covers) |
| aim | R (hold) | R3/9 |
| shoot | Left mouse | aim + X |
| reload | O | 4 |
| weapon_next/prev | N / P | 5 / — |

## Vehicle

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| steer/accelerate | WASD | left stick + RT/LT emulation | left joystick + right pedals |
| handbrake | J (action_x) | X | X button |
| exit | L (action_b) | B | B button |
| horn | G | — | horn chip |

Cars and motorcycles share the exact same map (B enters either; "Ride" prompt on bikes).
Motorcycles: lighter/quicker, lean into corners visually; physics roll locked for arcade upright stability (TDL #14). Parked bikes: Old Quarter curb (by Marisol's Bar) + Neon Strip curb.

## System

pause = Esc/Start; map_open = M; phone = T; interact_e = E (redundant with B); skip cinematic = X.

## Touch UI layout (landscape 2688×1242 design space)

- Left thumb zone (left 40% of screen): virtual joystick.
- Right side diamond: X (left), Y (top), B (right), A (bottom) — matches physical diamond; each button ≥ 110 px.
- Top-right chips: map, phone, pause. Top-left: minimap + health/stamina/armor bars; wanted stars under minimap.
- Vehicle mode: buttons morph (X=handbrake label, B=exit), right pedal pair appears (accelerate/brake).
- HUD scale setting multiplies all chip/button sizes (0.8-1.4).
