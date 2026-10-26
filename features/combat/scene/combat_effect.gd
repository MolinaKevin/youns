class_name CombatEffect
extends RefCounted

## Contrato único para los efectos persistentes del combate. Mantiene juntas
## las reglas (estado, duración y daño) y la configuración visual del charco.
const NONE := "ninguno"
const WET := "wet"
const FIRE := "fire"
const GREASE := "grease"
const VINE := "vine"
const BLOOD := "blood"
const POISON := "poison"
const SAND := "sand"
const ICE := "ice"
const BLOODY_ICE := "bloody_ice"
const DARK_SMOKE := "dark_smoke"

const BLIND := "blind"
const SLOW := "slow"
const ENTANGLE := "entangle"
const BURN := "burn"
const BLEED := "bleed"
const FREEZE := "freeze"

const ZONE_TYPES := [WET, FIRE, GREASE, VINE, BLOOD, POISON, SAND, ICE, BLOODY_ICE, DARK_SMOKE]
const STATUS_TYPES := [BLIND, SLOW, ENTANGLE, BURN, BLEED, POISON, FREEZE, WET]
const STATUS_SUMMARY_ORDER := [BURN, BLEED, POISON, WET, SLOW, ENTANGLE, FREEZE, BLIND]

const PATH_RULES := {
	WET: {"status": WET, "turns": 3, "refresh": true}, FIRE: {"status": BURN, "turns": 3},
	GREASE: {"status": SLOW, "turns": 3}, VINE: {"status": ENTANGLE, "turns": 2},
	BLOOD: {"status": BLEED, "turns": 4}, POISON: {"status": POISON, "turns": 3},
	SAND: {"status": BLIND, "turns": 2}, ICE: {"status": FREEZE, "turns": 2},
	DARK_SMOKE: {"status": BLIND, "turns": 3},
}
const DIRECT_IMPACT_EFFECTS := [WET, FIRE, POISON, BLOOD, GREASE, VINE, SAND, ICE]
const STATUS_FIELDS := {WET: "wet_turns", BURN: "burning_turns", SLOW: "greasy_turns", ENTANGLE: "entangled_turns", BLEED: "bleeding_turns", POISON: "poison_stacks", BLIND: "blinded_turns", FREEZE: "frozen_turns"}
const DAMAGE_ZONES := {BURN: FIRE, BLEED: BLOOD, POISON: POISON}
const ELEMENT_CONVERSIONS := {FIRE: [GREASE, VINE], ICE: [WET]}

static func is_known_zone(effect: String) -> bool:
	return effect in ZONE_TYPES

static func is_known_status(status: String, allow_none: bool = false) -> bool:
	return status in STATUS_TYPES or (allow_none and status == NONE)

static func path_rule(effect: String) -> Dictionary:
	return PATH_RULES.get(effect, {})

static func status_field(status: String) -> String:
	return STATUS_FIELDS.get(status, "")

static func damage_zone(status: String) -> String:
	return DAMAGE_ZONES.get(status, "")

static func combined_zone_effect(first: String, second: String) -> String:
	if (first == WET and second == ICE) or (first == ICE and second == WET): return ICE
	if (first == BLOOD and second == ICE) or (first == ICE and second == BLOOD): return BLOODY_ICE
	if (first == BLOOD and second == FIRE) or (first == FIRE and second == BLOOD): return DARK_SMOKE
	return ""

static func puddle_color(effect: String) -> Color:
	match effect:
		FIRE: return Color(1.0, 0.35, 0.05)
		GREASE: return Color(0.55, 0.45, 0.05)
		VINE: return Color(0.1, 0.70, 0.15)
		BLOOD: return Color(0.70, 0.05, 0.05)
		POISON: return Color(0.45, 0.0, 0.65)
		SAND: return Color(0.85, 0.75, 0.4)
		ICE: return Color(0.6, 0.9, 1.0)
		BLOODY_ICE: return Color(0.55, 0.65, 0.9)
		DARK_SMOKE: return Color(0.2, 0.15, 0.25)
		_: return Color(0.1, 0.4, 0.9)
