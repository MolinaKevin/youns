extends ItemEffect
class_name ItemEffectCombat

## Efecto que solo sirve en combate (comodín ▲▼ "Ítem"): cura vida, recupera MP
## y/o saca los estados negativos del jugador. Fuera del combate no hace nada.

@export var heal_hp: int = 0
@export var restore_mp: int = 0
## Saca los estados negativos del jugador (quemado, veneno, congelado...).
@export var cleanse: bool = false

func apply(_save: PlayerSaveData) -> void:
	pass

## Aplica el efecto al combate. Devuelve lo que pasó, para el log.
func apply_in_combat(state: CombatState) -> Dictionary:
	var result := {}
	if heal_hp > 0:
		result["healed"] = state.heal_player(heal_hp)
	if restore_mp > 0:
		result["mp"] = state.restore_mp(restore_mp)
	if cleanse:
		result["cleansed"] = state.cleanse_player()
	return result
