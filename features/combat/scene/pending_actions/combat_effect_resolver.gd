class_name CombatEffectResolver
extends RefCounted

## Base de las clases "cast": aplican el efecto de una carta ya confirmada
## (el punto/dirección/objetivo ya se eligió en el mapa — eso lo resuelve el
## CombatPendingAction correspondiente). No manejan selección ni fases,
## solo reciben los datos resueltos y los ejecutan. Ver CombatSpellCasts y
## CombatModuleCasts.

var host: CombatPlayerActions

func _init(p_host: CombatPlayerActions) -> void:
	host = p_host


func _flow_is_active(flow: AsyncFlowToken) -> bool:
	return host.is_flow_active(flow)
