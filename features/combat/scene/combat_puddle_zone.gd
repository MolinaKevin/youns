class_name CombatPuddleZone
extends RefCounted

## Contrato de una zona de charco. El mapa conserva diccionarios por
## compatibilidad con biomas y puertos existentes; las creaciones pasan por
## este constructor para que todas tengan el mismo esquema.

static func make(id: int, pos: Vector2, radius: float, effect: String, turns: int, damage: int, lens: bool = false, exclusions: Array = [], parents: Array = []) -> Dictionary:
	return {
		"id": id,
		"pos": pos,
		"radius": radius,
		"effect": effect,
		"turns": turns,
		"damage": damage,
		"lens": lens,
		"excl": exclusions,
		"parents": parents,
	}


static func id_of(zone: Dictionary) -> int:
	return int(zone.get("id", -1))


static func position_of(zone: Dictionary) -> Vector2:
	return zone.get("pos", Vector2.ZERO) as Vector2


static func radius_of(zone: Dictionary) -> float:
	return float(zone.get("radius", 0.0))


static func effect_of(zone: Dictionary) -> String:
	return str(zone.get("effect", "wet"))


static func turns_of(zone: Dictionary) -> int:
	return int(zone.get("turns", 0))


static func damage_of(zone: Dictionary) -> int:
	return int(zone.get("damage", 0))


static func is_lens(zone: Dictionary) -> bool:
	return bool(zone.get("lens", false))


static func exclusions_of(zone: Dictionary) -> Array:
	return zone.get("excl", []) as Array


static func parents_of(zone: Dictionary) -> Array:
	return zone.get("parents", []) as Array


static func set_turns(zone: Dictionary, value: int) -> void:
	zone["turns"] = value
