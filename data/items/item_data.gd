extends Resource
class_name ItemData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var effects: Array[ItemEffect] = []
@export_range(0.0, 10.0, 0.1) var weight_gain: float = 0.0
@export_range(0.0, 10.0, 0.1) var poop_size: float = 0.0

func apply_effects(save: PlayerSaveData) -> void:
	for effect in effects:
		effect.apply(save)
	if weight_gain > 0.0:
		StatsManager.add_weight(weight_gain)
	if poop_size > 0.0:
		save.poop_pending += poop_size
	StatsManager.check_status()

## ¿Se puede usar en combate? (tiene algún ItemEffectCombat)
func is_combat_item() -> bool:
	return effects.any(func(e: ItemEffect) -> bool: return e is ItemEffectCombat)

## ¿Solo sirve en combate? (todos sus efectos son de combate)
func is_combat_only() -> bool:
	return not effects.is_empty() and effects.all(func(e: ItemEffect) -> bool: return e is ItemEffectCombat)

## Aplica los efectos de combate del ítem. Devuelve lo que pasó sumado:
## {"healed": int, "mp": int, "cleansed": bool}.
func apply_in_combat(state: CombatState) -> Dictionary:
	var total := {}
	for effect in effects:
		if effect is ItemEffectCombat:
			var r: Dictionary = (effect as ItemEffectCombat).apply_in_combat(state)
			for key in r:
				if r[key] is bool:
					total[key] = total.get(key, false) or r[key]
				else:
					total[key] = total.get(key, 0) + r[key]
	return total

func to_inventory_entry(count: int = 1) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"icon": icon.resource_path if icon else "",
		"data_path": resource_path,
		"count": count,
	}
