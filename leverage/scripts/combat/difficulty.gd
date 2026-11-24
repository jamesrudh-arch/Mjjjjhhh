class_name Difficulty
## Difficulty - the chapter-based difficulty director. Later chapters field
## tougher, harder-hitting crews in larger numbers, so a mission replayed at
## chapter 5 reads visibly harder than the same fight at chapter 1. Applied by
## World on every mission/encounter spawn.

## Multipliers per chapter index (1..5, index 0 unused).
const HP_TABLE := [1.0, 1.0, 1.22, 1.45, 1.68, 1.9]
const DMG_TABLE := [1.0, 1.0, 1.12, 1.28, 1.45, 1.62]
const COUNT_TABLE := [0, 0, 0, 1, 1, 2]


static func chapter() -> int:
        return clampi(int(GameState.story_flags.get("chapter", 1)), 1, 5)


static func hp_mult() -> float:
        return HP_TABLE[chapter()]


static func dmg_mult() -> float:
        return DMG_TABLE[chapter()]


## Extra bodies added to non-boss fight waves.
static func count_bonus() -> int:
        return COUNT_TABLE[chapter()]


## Label shown on the HUD/pause for the current ramp (debug + player-facing).
static func tier_name() -> String:
        match chapter():
                1: return "STREETS"
                2: return "PRESSURE"
                3: return "HIGH STAKES"
                4: return "WAR PATH"
                _: return "LEVERAGE"


## Test hook: multipliers for an explicit chapter value.
static func multipliers_for(ch: int) -> Dictionary:
        var c := clampi(ch, 1, 5)
        return {"hp": HP_TABLE[c], "dmg": DMG_TABLE[c], "count": COUNT_TABLE[c], "tier": tier_name_for(c)}


static func tier_name_for(ch: int) -> String:
        match clampi(ch, 1, 5):
                1: return "STREETS"
                2: return "PRESSURE"
                3: return "HIGH STAKES"
                4: return "WAR PATH"
                _: return "LEVERAGE"
