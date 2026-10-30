class_name ItemEffectRuntime
extends RefCounted

const ContextScript := preload("res://shared/item_effect_context.gd")

## Puente de compatibilidad para consumidores que todavía aplican un ItemData
## sin inyectar contexto. Los recursos de datos siguen sin conocer autoloads.
static func context() -> ItemEffectContext:
	var tree := Engine.get_main_loop() as SceneTree
	var stats_manager := tree.root.get_node_or_null("StatsManager") if tree != null else null
	if stats_manager == null:
		return ContextScript.new() as ItemEffectContext
	return ContextScript.new(stats_manager.get("services") as StatsServicesPort,
		Callable(stats_manager, "check_status")) as ItemEffectContext
