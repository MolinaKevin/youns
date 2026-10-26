class_name CombatMapInteractions
extends RefCounted

## Coordina los modos de colocación y sus previews de hover. Targeting sólo
## pregunta si hay una interacción activa, sin conocer los sistemas concretos.
var trap_system: TrapSystem
var map: MapArea
var grenade_system: GrenadeSystem
var rock_jump_system: RockJumpSystem
var puddle_system: PuddleSystem
var overwatch_system: CombatOverwatchSystem
var push_system: CombatPushSystem
var module_system: ModuleSystem
var spell_system: CombatSpellSystem
var tree_system: TreeSystem
var targeting: CombatTargeting
var presentation: CombatMapPresentation

func has_active_placement() -> bool:
	return trap_system.is_placing() or grenade_system.is_active() \
		or rock_jump_system.is_active() or puddle_system.is_placing() \
		or overwatch_system.selection_active

func update_hover_previews(pos: Vector2) -> void:
	puddle_system.update_hover_preview(pos)
	trap_system.update_hover_preview(pos)
	overwatch_system.update_hover(pos)

func start_move_selection(reach: float) -> void:
	targeting.start_move_selection(reach)

func clear_move_selection() -> void:
	targeting.clear_move_selection()

func start_attack_selection(reach: float) -> void:
	targeting.start_attack_selection(reach)

func clear_attack_selection() -> void:
	targeting.clear_attack_selection()

func start_trap_placement(reach: float, radius: float = 1.0, preview_los := true) -> void:
	trap_system.start_trap_placement(reach, radius, preview_los)

func clear_trap_placement() -> void:
	trap_system.clear_trap_placement()

func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void:
	trap_system.place_trap(pos, radius, damage, card_name)

## Trampas que pisa una unidad al comenzar o terminar un movimiento.
func trigger_traps(pos: Vector2, contact_margin: float = 0.0) -> int:
	return trap_system.check_and_trigger_traps(pos, contact_margin)

func trigger_traps_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	return trap_system.check_traps_along_segment(from, to, contact_margin)

func grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2:
	return grenade_system.calculate_landing(from, target, bounce)

func show_grenade_preview(landing: Vector2, radius: float) -> void:
	grenade_system.show_preview(landing, radius)

func clear_grenade_preview() -> void:
	grenade_system.clear_preview()

func is_enemy_in_explosion(center: Vector2, radius: float) -> bool:
	return grenade_system.is_enemy_in_explosion(center, radius)

func start_rock_jump_selection(reach: float) -> void:
	rock_jump_system.start_rock_jump_selection(reach)

func clear_rock_jump_selection() -> void:
	rock_jump_system.clear_rock_jump_selection()

func rocks_in_range(origin: Vector2, reach: float) -> Array[Dictionary]:
	return rock_jump_system.get_rocks_in_range(origin, reach)

func rock_near(pos: Vector2) -> Dictionary:
	return rock_jump_system.get_rock_near(pos)

func start_jump_landing_selection(rock_pos: Vector2, reach: float) -> void:
	rock_jump_system.start_jump_landing_selection(rock_pos, reach)

func is_enemy_near(pos: Vector2, radius: float) -> bool:
	return rock_jump_system.is_enemy_near_pos(pos, radius)

func can_jump_land_at(pos: Vector2) -> bool:
	return not map.terrain.is_tile_obstructed(pos, 0)

## Parpadeo y caída de árbol comparten la misma regla de destino libre. La
## exponen las interacciones para que los sistemas del tablero no dependan de
## los atajos heredados de MapArea.
func can_blink_to(pos: Vector2) -> bool:
	return map.terrain.can_blink_to(pos)

func is_enemy_in_circle(center: Vector2, radius: float) -> bool:
	return map.queries.is_enemy_in_circle(center, radius)

func is_player_in_circle(center: Vector2, radius: float) -> bool:
	return map.queries.is_player_in_circle(center, radius)

func land_player_from_jump(pos: Vector2) -> void:
	map.player_pos = pos
	map.player_elevation = map.terrain.elevation_at(pos)
	map.actors.sync_targets()

func start_puddle_placement(reach: float, effect: String, radius: float) -> void:
	puddle_system.start_puddle_placement(reach, effect, radius)

func clear_puddle_placement() -> void:
	puddle_system.clear_puddle_placement()

func place_puddle(pos: Vector2, radius: float, effect: String, turns: int, damage: int) -> void:
	puddle_system.place_puddle(pos, radius, effect, turns, damage)

func tick_puddles() -> void:
	puddle_system.tick_puddles()

func puddle_at(pos: Vector2) -> Dictionary:
	return puddle_system.get_puddle_at(pos)

## Snapshot de lectura para UI y tests; PuddleSystem conserva el estado mutable.
func puddles() -> Array[Dictionary]:
	return puddle_system.zones.duplicate(true)

func puddle_visual_count() -> int:
	return puddle_system.visuals.size()

func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary:
	return puddle_system.move_puddle(zone, to)

func convert_puddles(center: Vector2, radius: float, from_effects: Array, to_effect: String) -> int:
	return puddle_system.convert_puddles(center, radius, from_effects, to_effect)

func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array:
	return puddle_system.puddles_on_segment(from, to, effects)

func puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return puddle_system.get_puddle_damage_along(from, to, contact_margin)

func puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return puddle_system.get_puddle_effects_along(from, to, contact_margin)

## Efectos de tablero comunes para desplazamientos forzados. Centralizarlo
## acá evita que PlayerActions tenga que conocer TrapSystem y PuddleSystem.
func zone_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	var effects := puddle_system.get_puddle_effects_along(from, to, contact_margin)
	effects["trap_damage"] = trigger_traps_along(from, to, contact_margin)
	return effects

func start_puddle_hop_landing(pos: Vector2, reach: float) -> void:
	presentation.show_range_at(pos, reach)

func start_overwatch_selection(reach: float, half_angle: float) -> void:
	overwatch_system.start_selection(reach, half_angle)

func clear_overwatch_selection() -> void:
	overwatch_system.clear_selection()

func place_overwatch(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> void:
	overwatch_system.place(origin, direction, reach, half_angle)

func clear_overwatch_zone() -> void:
	overwatch_system.clear_zone()

func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	return overwatch_system.segment_crosses_cone(from, to, origin, direction, cone_range, half_angle_deg)

func start_push_enemy_selection(reach: float) -> void:
	push_system.start_enemy_selection(reach)

func start_anchor_selection(reach: float, origin: Vector2) -> void:
	presentation.show_range_at(origin, reach)

func start_push_cone(reach: float) -> void:
	push_system.start_enemy_cone(reach)

func clear_push_selection() -> void:
	push_system.clear_selection()

func is_pos_in_push_cone(pos: Vector2, reach: float) -> bool:
	return push_system.is_pos_in_enemy_cone(pos, reach)

func calculate_push_landing(target: Vector2, reach: float) -> Vector2:
	return push_system.calculate_push_landing(target, reach)

func calculate_drag_landing(target: Vector2, distance: float) -> Vector2:
	return push_system.calculate_drag_landing(target, distance)

func push_enemy_to(landing: Vector2) -> void:
	push_system.push_enemy_to(landing)

func start_module_selection(reach: float) -> void:
	module_system.start_module_selection(reach)

func clear_module_selection() -> void:
	module_system.clear_module_selection()

func start_collapse_selection(reach: float) -> void:
	module_system.start_collapse_selection(reach)

func start_module_throw_target(reach: float) -> void:
	module_system.start_module_throw_target(reach)

func start_module_push_cone(pos: Vector2, reach: float, half_angle: float) -> void:
	push_system.start_module_cone(pos, reach, half_angle)

func is_pos_in_module_cone(origin: Vector2, pos: Vector2, reach: float, half_angle: float) -> bool:
	return push_system.is_pos_in_module_cone(origin, pos, reach, half_angle)

func module_at(pos: Vector2) -> Dictionary:
	return module_system.get_module_at(pos)

func obstacle_gap(obstacle: Dictionary) -> float:
	return module_system.obstacle_gap(obstacle)

func break_modules(obstacle: Dictionary, count: int) -> int:
	return module_system.break_modules(obstacle, count)

func build_modules(pos: Vector2, count: int) -> int:
	return module_system.build_modules(pos, count)

func slide_module(obstacle: Dictionary, direction: Vector2, distance: float) -> Dictionary:
	return module_system.slide_module(obstacle, direction, distance)

func throw_module(obstacle: Dictionary, target: Vector2) -> Dictionary:
	return module_system.throw_module(obstacle, target)

func collapse_modules_on_enemy() -> int:
	return module_system.collapse_modules_on_enemy()

func start_spell_selection(reach: float) -> void:
	spell_system.start_selection(reach)

func clear_spell_selection() -> void:
	spell_system.clear_selection()

func place_delayed_zone(pos: Vector2, radius: float, damage: int, name: String, rounds: int, effect: String, puddle_turns: int) -> void:
	spell_system.place_delayed_zone(pos, radius, damage, name, rounds, effect, puddle_turns)

func resolve_delayed_zones() -> Array:
	return spell_system.resolve_delayed_zones()

func blink_player_to(pos: Vector2) -> void:
	map.player_pos = pos
	map.player_elevation = map.terrain.elevation_at(pos)
	map.actors.sync_targets()

func tree_at(pos: Vector2) -> Dictionary:
	return tree_system.get_tree_at(pos)

func can_drop_at(pos: Vector2) -> bool:
	return tree_system.can_drop_at(pos)

func is_tree_burning(tree: Dictionary) -> bool:
	return TreeSystem.is_tree_burning(tree)

func is_tree_near(pos: Vector2, reach: float) -> bool:
	return tree_system.is_tree_near(pos, reach)

func climb_tree(tree: Dictionary, landing: Vector2) -> void:
	tree_system.climb_tree(tree, landing)

func drop_from_tree(landing: Vector2) -> bool:
	return tree_system.drop_from_tree(landing)

func fell_tree(tree: Dictionary, direction: Vector2) -> Dictionary:
	return tree_system.fell_tree(tree, direction)

func ignite_trees_in_circle(center: Vector2, radius: float) -> int:
	return tree_system.ignite_trees_in_circle(center, radius)

func ignite_trees_in_cone(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> int:
	return tree_system.ignite_trees_in_cone(origin, direction, reach, half_angle)

func extinguish_trees_in_circle(center: Vector2, radius: float) -> int:
	return tree_system.extinguish_trees_in_circle(center, radius)

func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary:
	return tree_system.first_tree_on_segment(from, to)

func tick_trees() -> void:
	tree_system.tick_trees()

func is_player_in_tree(tree: Dictionary) -> bool:
	return tree_system.is_player_in_this_tree(tree)

func is_click_on_enemy(pos: Vector2) -> bool:
	return targeting.is_click_on_enemy(pos)

func is_click_on_player(pos: Vector2) -> bool:
	return targeting.is_click_on_player(pos)

func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	return targeting.is_enemy_in_card_pattern(pattern, origin, direction, primary)
