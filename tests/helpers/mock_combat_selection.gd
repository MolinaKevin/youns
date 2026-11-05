class_name MockCombatSelection
extends CombatMapSelectionPort

var owner

class Targeting extends CombatMapSelectionTargetingPort:
	var owner
	func _init() -> void:
		hover = CombatMapSelectionHoverAdapter.new(self)
		modes = CombatMapSelectionModesTargetingAdapter.new(self)
		queries = CombatMapTargetQueriesAdapter.new(self)
	func start_move_selection(_reach: float) -> void: owner.start_move_selection_calls += 1
	func clear_move_selection() -> void: pass
	func start_attack_selection(_reach: float) -> void: pass
	func clear_attack_selection() -> void: pass
	func is_click_on_enemy(_pos: Vector2) -> bool: return true
	func is_click_on_player(_pos: Vector2) -> bool: return true

class Actions extends CombatMapSelectionActionsPort:
	var owner
	func _init() -> void:
		modes = CombatMapSelectionModesAdapter.new(self)
		overwatch = CombatMapOverwatchSelectionAdapter.new(self)
	func start_rock_jump_selection(_reach: float) -> void: pass
	func clear_rock_jump_selection() -> void: pass
	func start_jump_landing_selection(_rock_pos: Vector2, _reach: float) -> void: pass
	func start_puddle_hop_landing(_pos: Vector2, _reach: float) -> void: pass
	func start_module_selection(_reach: float) -> void: pass
	func clear_module_selection() -> void: pass
	func start_collapse_selection(_reach: float) -> void: pass
	func start_module_throw_target(_reach: float) -> void: pass
	func start_spell_selection(_reach: float) -> void: pass
	func clear_spell_selection() -> void: pass
	func start_overwatch_selection(_reach: float, _angle: float) -> void: pass
	func clear_overwatch_selection() -> void: pass
	func place_overwatch(_origin: Vector2, _direction: Vector2, _reach: float, _angle: float) -> void: pass
	func clear_overwatch_zone() -> void: owner.clear_overwatch_zone_calls += 1
	func segment_is_in_overwatch_cone(_from: Vector2, _to: Vector2, _origin: Vector2, _direction: Vector2, _cone_range: float, _half_angle_deg: float) -> bool: return owner.overwatch_cone_hit

func _init() -> void:
	targeting = Targeting.new()
	targeting.owner = owner
	actions = Actions.new()
	actions.owner = owner

func puddle_effects_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return owner.puddle_effects_result
func zone_effects_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return owner.puddle_effects_result
func puddle_damage_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> Dictionary: return owner.puddle_damage_result
func is_tree_near(_pos: Vector2, _reach: float) -> bool: return false
func start_move_selection(_reach: float) -> void: owner.start_move_selection_calls += 1
func clear_move_selection() -> void: pass
func start_attack_selection(_reach: float) -> void: pass
func clear_attack_selection() -> void: pass
func start_trap_placement(_reach: float, _radius := 1.0, _preview_los := true) -> void: pass
func clear_trap_placement() -> void: pass
func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void: owner.place_trap_calls.append({"pos": pos, "radius": radius, "damage": damage, "name": card_name})
func trigger_traps(_pos: Vector2, _contact_margin := 0.0) -> int: return 0
func trigger_traps_along(_from: Vector2, _to: Vector2, _contact_margin := 0.0) -> int: return 0
func grenade_landing(_from: Vector2, target: Vector2, _bounce: float) -> Vector2: return target
func show_grenade_preview(_landing: Vector2, _radius: float) -> void: pass
func clear_grenade_preview() -> void: pass
func is_enemy_in_explosion(_center: Vector2, _radius: float) -> bool: return true
func start_rock_jump_selection(_reach: float) -> void: pass
func clear_rock_jump_selection() -> void: pass
func rocks_in_range(_origin: Vector2, _reach: float) -> Array[Dictionary]: return [{"pos": Vector2(5.0, 0.0)}]
func rock_near(pos: Vector2) -> Dictionary: return {"pos": pos}
func start_jump_landing_selection(_rock_pos: Vector2, _reach: float) -> void: pass
func can_jump_land_at(_pos: Vector2) -> bool: return true
func land_player_from_jump(pos: Vector2) -> void: owner.player_pos = pos
func is_enemy_near(pos: Vector2, radius: float) -> bool: return pos.distance_to(owner.enemy_pos) <= radius
func start_puddle_placement(_reach: float, _effect: String, _radius: float) -> void: pass
func clear_puddle_placement() -> void: pass
func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void: owner.place_puddle_calls.append({"pos": pos, "radius": radius, "effect": effect, "turns": turns, "damage": damage})
func tick_puddles() -> void: pass
func puddle_at(_pos: Vector2) -> Dictionary: return {}
func start_puddle_hop_landing(_pos: Vector2, _reach: float) -> void: pass
func start_overwatch_selection(_reach: float, _angle: float) -> void: pass
func clear_overwatch_selection() -> void: pass
func place_overwatch(_origin: Vector2, _direction: Vector2, _reach: float, _angle: float) -> void: pass
func clear_overwatch_zone() -> void: owner.clear_overwatch_zone_calls += 1
func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> bool: return owner.overwatch_cone_hit
func start_push_enemy_selection(_reach: float) -> void: pass
func start_anchor_selection(_reach: float, _origin: Vector2) -> void: pass
func start_push_cone(_reach: float) -> void: pass
func clear_push_selection() -> void: pass
func is_pos_in_push_cone(_pos: Vector2, _reach: float) -> bool: return true
func calculate_push_landing(target: Vector2, _reach: float) -> Vector2: return target
func calculate_drag_landing(target: Vector2, _reach: float) -> Vector2: return target
func push_enemy_to(pos: Vector2) -> void:
	owner.push_enemy_to_calls.append(pos)
	owner.enemy_pos = pos
	owner.enemy_reached_target.emit.call_deferred()
func start_module_selection(_reach: float) -> void: pass
func clear_module_selection() -> void: pass
func start_collapse_selection(_reach: float) -> void: pass
func start_module_throw_target(_reach: float) -> void: pass
func start_module_push_cone(_pos: Vector2, _reach: float, _angle: float) -> void: pass
func is_pos_in_module_cone(_origin: Vector2, _pos: Vector2, _reach: float, _angle: float) -> bool: return true
func module_at(_pos: Vector2) -> Dictionary: return {}
func obstacle_gap(_obstacle: Dictionary) -> float: return 0.0
func break_modules(obstacle: Dictionary, count: int) -> int: owner.break_modules_calls.append({"obs": obstacle, "count": count}); return count
func build_modules(pos: Vector2, count: int) -> int: owner.build_modules_calls.append({"pos": pos, "count": count}); return count
func slide_module(_obstacle: Dictionary, _direction: Vector2, _distance: float) -> Dictionary: return {"hit": "", "tree": {}}
func throw_module(_obstacle: Dictionary, _target: Vector2) -> Dictionary: return {"enemy": false, "player": false}
func collapse_modules_on_enemy() -> int: return 0
func start_spell_selection(_reach: float) -> void: pass
func clear_spell_selection() -> void: pass
func place_delayed_zone(pos: Vector2, radius: float, damage: int, _name: String, rounds: int = 1, effect: String = "", duration: int = 0) -> void: owner.place_delayed_zone_calls.append({"pos": pos, "radius": radius, "damage": damage, "delay": rounds, "effect": effect, "duration": duration})
func blink_player_to(pos: Vector2) -> void: owner.blink_calls.append(pos)
func tree_at(_pos: Vector2) -> Dictionary: return {}
func can_drop_at(_pos: Vector2) -> bool: return true
func is_tree_burning(_tree: Dictionary) -> bool: return false
func tick_trees() -> void: pass
func is_click_on_enemy(_pos: Vector2) -> bool: return true
func is_click_on_player(_pos: Vector2) -> bool: return true
func is_enemy_in_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> bool: return true
