class_name CombatBoardContext
extends RefCounted

## Borde que consumen las acciones pendientes. La escena concreta queda detrás
## de este adaptador: las acciones reciben fachadas y señales, no un MapArea.

signal player_anim_finished
signal enemy_anim_finished
signal enemy_reached_target

const WORLD_W := CombatMapStateAdapter.WORLD_W
const WORLD_H := CombatMapStateAdapter.WORLD_H
const MIN_SEPARATION := CombatMapStateAdapter.MIN_SEPARATION
const CLICK_MARGIN := CombatMapStateAdapter.CLICK_MARGIN

var queries: CombatMapQueries
var actors: CombatMapActors
var selection: CombatMapSelectionPort
var placement: CombatMapPlacementPort
var effects: CombatMapEffectsPort
var obstacles: CombatMapObstaclePort
var push: CombatMapPushPort
var presentation: CombatMapPresentation
var movement: CombatMapMovementPort
var terrain: CombatMapTerrainPort
## Estado espacial explícito del tablero. Los consumidores nuevos deberían
## consultarlo directamente en vez de depender de aliases de posición.
var state: CombatMapStateAdapter

func _init(p_state: CombatMapStateAdapter, p_queries: CombatMapQueries,
		p_actors: CombatMapActors, p_selection: CombatMapSelectionPort,
		p_placement: CombatMapPlacementPort, p_effects: CombatMapEffectsPort,
		p_obstacles: CombatMapObstaclePort, p_push: CombatMapPushPort,
		p_presentation: CombatMapPresentation, p_movement: CombatMapMovementPort,
		p_terrain: CombatMapTerrainPort, signal_source: Object = null) -> void:
	state = p_state
	queries = p_queries
	actors = p_actors
	selection = p_selection
	placement = p_placement
	effects = p_effects
	obstacles = p_obstacles
	push = p_push
	presentation = p_presentation
	movement = p_movement
	terrain = p_terrain
	if signal_source != null:
		if signal_source.has_signal("player_anim_finished"):
			signal_source.connect("player_anim_finished", _on_player_anim_finished)
		if signal_source.has_signal("enemy_anim_finished"):
			signal_source.connect("enemy_anim_finished", _on_enemy_anim_finished)
		if signal_source.has_signal("enemy_reached_target"):
			signal_source.connect("enemy_reached_target", _on_enemy_reached_target)

func _on_player_anim_finished() -> void: player_anim_finished.emit()
func _on_enemy_anim_finished() -> void: enemy_anim_finished.emit()
func _on_enemy_reached_target() -> void: enemy_reached_target.emit()
