class_name CombatTurnResult
extends RefCounted

## Resultado tipado de una transición de CombatTurnController. Evita que el
## flujo de escena dependa de claves opcionales en diccionarios.

var kind := "idle"
var line: CardActionLine
var echo_card: CardData
var skipped_for_mp := 0
var mp_cost := 0
var cap := -1
var is_wild := false
var skipped := false

static func make(result_kind: String) -> CombatTurnResult:
	var result := CombatTurnResult.new()
	result.kind = result_kind
	return result
