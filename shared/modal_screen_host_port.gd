class_name ModalScreenHostPort
extends RefCounted

## Contrato de las pantallas modales y de las transiciones de mundo. Aísla a
## esos flujos de los autoloads concretos y permite dobles pequeños en tests.

func set_clock_visible(_visible: bool) -> void: pass
func clock_visible() -> bool: return false
func set_clock_paused(_paused: bool) -> void: pass
func clock_paused() -> bool: return false
func set_youns_status_visible(_visible: bool) -> void: pass
func youns_status_visible() -> bool: return false
func set_world_visible(_visible: bool) -> void: pass
func set_party_visible(_visible: bool) -> void: pass
