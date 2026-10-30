extends Resource
class_name ItemEffect

const ItemEffectRuntimeScript := preload("res://shared/item_effect_runtime.gd")

func apply(_save: PlayerSaveData, _context: ItemEffectContext = null) -> void:
	pass

func runtime_context(context: ItemEffectContext) -> ItemEffectContext:
	return context if context != null else ItemEffectRuntimeScript.context()
