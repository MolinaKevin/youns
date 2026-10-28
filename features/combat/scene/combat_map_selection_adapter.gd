class_name CombatMapSelectionAdapter
extends CombatMapSelectionPort

## Adaptador de selección y previews construido sobre los sistemas concretos.
## Mantiene fuera del contrato la coordinación entre sistemas concretos.
var _map: CombatMapArea
var _targeting: CombatTargeting
var _presentation: CombatMapPresentation
var _trap_system: TrapSystem
var _grenade_system: GrenadeSystem
var _rock_jump_system: RockJumpSystem
var _puddle_system: PuddleSystem
var _overwatch_system: CombatOverwatchSystem
var _push_system: CombatPushSystem
var _module_system: ModuleSystem
var _spell_system: CombatSpellSystem

func _init(map: CombatMapArea, targeting: CombatTargeting, presentation: CombatMapPresentation,
		trap_system: TrapSystem, grenade_system: GrenadeSystem, rock_jump_system: RockJumpSystem,
		puddle_system: PuddleSystem, overwatch_system: CombatOverwatchSystem,
		push_system: CombatPushSystem, module_system: ModuleSystem, spell_system: CombatSpellSystem) -> void:
	_map = map
	_targeting = targeting
	_presentation = presentation
	_trap_system = trap_system
	_grenade_system = grenade_system
	_rock_jump_system = rock_jump_system
	_puddle_system = puddle_system
	_overwatch_system = overwatch_system
	_push_system = push_system
	_module_system = module_system
	_spell_system = spell_system
	self.targeting = CombatMapSelectionTargetingAdapter.new(self)
	self.actions = CombatMapSelectionActionsAdapter.new(self)
	self.actions.modes = CombatMapSelectionModesAdapter.new(self.actions)
	self.actions.overwatch = CombatMapOverwatchSelectionAdapter.new(self.actions)

func has_active_placement() -> bool:
	return _trap_system.is_placing() or _grenade_system.is_active() \
		or _rock_jump_system.is_active() or _puddle_system.is_placing() \
		or _overwatch_system.selection_active

func update_hover_previews(pos: Vector2) -> void:
	_puddle_system.update_hover_preview(pos)
	_trap_system.update_hover_preview(pos)
	_overwatch_system.update_hover(pos)

func update_hover(pos: Vector2) -> void: _targeting.update_hover(pos)
func clear_hover() -> void: _targeting.clear_hover()

func start_move_selection(reach: float) -> void: _targeting.start_move_selection(reach)
func clear_move_selection() -> void: _targeting.clear_move_selection()
func start_attack_selection(reach: float) -> void: _targeting.start_attack_selection(reach)
func clear_attack_selection() -> void: _targeting.clear_attack_selection()
func is_click_on_enemy(pos: Vector2) -> bool: return _targeting.is_click_on_enemy(pos)
func is_click_on_player(pos: Vector2) -> bool: return _targeting.is_click_on_player(pos)
func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	return _targeting.is_enemy_in_card_pattern(pattern, origin, direction, primary)

func start_trap_placement(reach: float, radius: float = 1.0, preview_los: bool = true) -> void: _trap_system.start_trap_placement(reach, radius, preview_los)
func clear_trap_placement() -> void: _trap_system.clear_trap_placement()
func place_trap(pos: Vector2, radius: float, damage: int, card_name: String) -> void: _trap_system.place_trap(pos, radius, damage, card_name)
func grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2: return _grenade_system.calculate_landing(from, target, bounce)
func show_grenade_preview(landing: Vector2, radius: float) -> void: _grenade_system.show_preview(landing, radius)
func clear_grenade_preview() -> void: _grenade_system.clear_preview()
func is_enemy_in_explosion(center: Vector2, radius: float) -> bool: return _grenade_system.is_enemy_in_explosion(center, radius)
func start_puddle_placement(reach: float, effect: String, radius: float) -> void: _puddle_system.start_puddle_placement(reach, effect, radius)
func clear_puddle_placement() -> void: _puddle_system.clear_puddle_placement()
func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void: _puddle_system.place_puddle(pos, radius, effect, turns, damage)

func start_rock_jump_selection(reach: float) -> void: _rock_jump_system.start_rock_jump_selection(reach)
func clear_rock_jump_selection() -> void: _rock_jump_system.clear_rock_jump_selection()
func start_jump_landing_selection(rock_pos: Vector2, reach: float) -> void: _rock_jump_system.start_jump_landing_selection(rock_pos, reach)
func start_puddle_hop_landing(pos: Vector2, reach: float) -> void: _presentation.combat_preview.show_range_at(pos, reach)

func start_overwatch_selection(reach: float, half_angle: float) -> void: _overwatch_system.start_selection(reach, half_angle)
func clear_overwatch_selection() -> void: _overwatch_system.clear_selection()
func place_overwatch(origin: Vector2, direction: Vector2, reach: float, half_angle: float) -> void: _overwatch_system.place(origin, direction, reach, half_angle)
func clear_overwatch_zone() -> void: _overwatch_system.clear_zone()
func segment_is_in_overwatch_cone(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	return _overwatch_system.segment_crosses_cone(from, to, origin, direction, cone_range, half_angle_deg)

func start_push_enemy_selection(reach: float) -> void: _push_system.start_enemy_selection(reach)
func start_anchor_selection(reach: float, origin: Vector2) -> void: _presentation.combat_preview.show_range_at(origin, reach)
func start_push_cone(reach: float) -> void: _push_system.start_enemy_cone(reach)
func clear_push_selection() -> void: _push_system.clear_selection()
func start_module_selection(reach: float) -> void: _module_system.start_module_selection(reach)
func clear_module_selection() -> void: _module_system.clear_module_selection()
func start_collapse_selection(reach: float) -> void: _module_system.start_collapse_selection(reach)
func start_module_throw_target(reach: float) -> void: _module_system.start_module_throw_target(reach)
func start_module_push_cone(pos: Vector2, reach: float, half_angle: float) -> void: _push_system.start_module_cone(pos, reach, half_angle)
func start_spell_selection(reach: float) -> void: _spell_system.start_selection(reach)
func clear_spell_selection() -> void: _spell_system.clear_selection()
