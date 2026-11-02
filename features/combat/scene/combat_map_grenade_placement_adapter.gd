class_name CombatMapGrenadePlacementAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func grenade_landing(from: Vector2, target: Vector2, bounce: float) -> Vector2: return source.grenade_landing(from, target, bounce)
func show_grenade_preview(landing: Vector2, radius: float) -> void: source.show_grenade_preview(landing, radius)
func clear_grenade_preview() -> void: source.clear_grenade_preview()
func is_enemy_in_explosion(center: Vector2, radius: float) -> bool: return source.is_enemy_in_explosion(center, radius)
