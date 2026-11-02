extends ItemEffect
class_name ItemEffectStat

## DELTA suma (o resta, si es negativo) `amount` a la stat. SET la deja en
## `amount` exacto, sin importar el valor anterior.
enum Mode { DELTA, SET }

@export var stat_key: String = ""
@export var mode: Mode = Mode.DELTA
@export var amount: float = 0.0

func apply(_save: PlayerSaveData, context: ItemEffectContext = null) -> void:
	if stat_key.is_empty():
		return
	var ctx := runtime_context(context)
	if mode == Mode.SET:
		ctx.set_stat(stat_key, int(amount))
	else:
		ctx.add_stat(stat_key, int(amount))
