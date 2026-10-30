class_name CombatMapScenePort
extends RefCounted

## Operaciones de composición de la escena de combate. No forma parte de las
## reglas del tablero: sólo conecta actores, UI flotante y entrada.
@warning_ignore("unused_signal")
signal position_selected(pos: Vector2)
@warning_ignore("unused_signal")
signal player_knocked_off_tree(burning: bool)
@warning_ignore("unused_signal")
signal player_anim_finished
@warning_ignore("unused_signal")
signal enemy_anim_finished
@warning_ignore("unused_signal")
signal enemy_reached_target

var actors: CombatMapSceneActorsPort = CombatMapSceneActorsPort.new()
var presentation: CombatMapScenePresentationPort = CombatMapScenePresentationPort.new()
var input: CombatMapSceneInputPort = CombatMapSceneInputPort.new()
