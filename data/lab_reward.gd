class_name LabReward
extends RefCounted

## Tipos de recompensa que pueden declarar las recetas del laboratorio.
## Los recursos .tres conservan strings para ser editables en el Inspector;
## el código debe usar estas constantes para no dispersar esos contratos.
const UNLOCK_RECIPE := "unlock_recipe"
const UNLOCK_CLOCK_UI := "unlock_clock_ui"
const UNLOCK_CARE_UI := "unlock_care_ui"
const ITEM := "item"
const WORLD_BRIDGE := "world_bridge"
const YOUN_GROWTH_BONUS := "youn_growth_bonus"
const MATERIAL_PRODUCTION := "material_production"
const MAX_HP := "max_hp"

const TYPES := [
	UNLOCK_RECIPE,
	UNLOCK_CLOCK_UI,
	UNLOCK_CARE_UI,
	ITEM,
	WORLD_BRIDGE,
	YOUN_GROWTH_BONUS,
	MATERIAL_PRODUCTION,
	MAX_HP,
]

## Campos serializables permitidos para cada tipo. Así los .tres siguen siendo
## simples de editar, pero no aceptan payloads que el juego ignoraría.
const FIELDS_BY_TYPE := {
	UNLOCK_RECIPE: ["type", "id"],
	UNLOCK_CLOCK_UI: ["type"],
	UNLOCK_CARE_UI: ["type"],
	ITEM: ["type", "id", "amount"],
	WORLD_BRIDGE: ["type", "id"],
	YOUN_GROWTH_BONUS: ["type", "value"],
	MATERIAL_PRODUCTION: ["type", "value"],
	MAX_HP: ["type", "value"],
}


static func type_of(reward: Dictionary) -> String:
	return str(reward.get("type", ""))


static func is_known(reward: Dictionary) -> bool:
	return type_of(reward) in TYPES


static func expected_fields(reward_type: String) -> Array:
	return FIELDS_BY_TYPE.get(reward_type, [])
