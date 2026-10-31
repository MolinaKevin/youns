class_name WorldSessionCoordinator
extends RefCounted

## Reglas de una sesión de mundo que no necesitan conocer la escena: volver de
## combate y aplicar las consecuencias de dormir. GameWorld conserva sólo la
## composición visual y las entradas de usuario.

func restore_after_combat(context: WorldCombatContext, player: CharacterBody3D, youn: CharacterBody3D, tree: SceneTree, care: CareStatsService, save: PlayerSaveData) -> bool:
	if not context.active:
		return false
	var pos := context.return_position
	player.global_position = pos
	player.velocity = Vector3.ZERO
	youn.global_position = pos + Vector3(1.5, 0, 1.5)
	youn.velocity = Vector3.ZERO
	context.resolve_victory(tree)
	care.add_stat("hambre", 30)
	if save != null and save.bathroom_pending_after_combat:
		save.bathroom_pending_after_combat = false
		care.apply_bathroom_accident()
	return true

func finish_sleep(start_hour: float, end_hour: float, care: CareStatsService, emotions: EmotionService) -> void:
	care.add_stat("hambre", 20)
	emotions.on_wake_up(maxf(0.0, end_hour - start_hour))
