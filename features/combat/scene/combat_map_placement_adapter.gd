class_name CombatMapPlacementAdapter
extends CombatMapPlacementPort

## Adaptador de colocación construido sobre trampas, granadas y charcos.
var _trap_system: TrapSystem
var _grenade_system: GrenadeSystem
var _puddle_system: PuddleSystem

func _init(trap_system: TrapSystem, grenade_system: GrenadeSystem, puddle_system: PuddleSystem) -> void:
	_trap_system = trap_system
	_grenade_system = grenade_system
	_puddle_system = puddle_system
	traps = CombatMapTrapPlacementAdapter.new(self)
	grenades = CombatMapGrenadePlacementAdapter.new(self)
	puddles = CombatMapPuddlePlacementAdapter.new(self)

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
