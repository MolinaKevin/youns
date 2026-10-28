class_name CombatMapTerrainMutationPort
extends RefCounted

func add_obstacle(_obstacle: Dictionary) -> void: pass
func remove_obstacle(_obstacle: Dictionary) -> void: pass
func obstacles_changed() -> void: pass
func warm_caches(_first_radius: float, _second_radius: float) -> void: pass
