class_name CombatMapScenePort
extends RefCounted

## Operaciones de composición de la escena de combate. No forma parte de las
## reglas del tablero: sólo conecta actores, UI flotante y entrada.
signal position_selected(pos: Vector2)
signal player_knocked_off_tree(burning: bool)
signal player_anim_finished
signal enemy_anim_finished
signal enemy_reached_target

var actors: CombatMapSceneActorsPort = CombatMapSceneActorsPort.new()
var presentation: CombatMapScenePresentationPort = CombatMapScenePresentationPort.new()
var input: CombatMapSceneInputPort = CombatMapSceneInputPort.new()
