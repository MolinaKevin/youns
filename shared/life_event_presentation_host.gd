class_name LifeEventPresentationHost
extends RefCounted

## Borde de presentación para las cinemáticas de vida. El autoload conserva
## las reglas y secuencias; este host concentra la dependencia del mundo vivo.

static func from_runtime() -> LifeEventPresentationHost:
	return LifeEventPresentationHost.new()

func world_ready(lighting: WorldLighting) -> bool:
	return ZoneManager.is_world_initialized() and is_instance_valid(lighting)

func zone_or(fallback: Node) -> Node:
	return ZoneManager.get_current_zone_node() if ZoneManager.get_current_zone_node() != null else fallback

func youn() -> CharacterBody3D:
	return PartyManager.youn

func player() -> CharacterBody3D:
	return PartyManager.player

func has_camera(viewport: Viewport) -> bool:
	return viewport.get_camera_3d() != null

func freeze_party() -> void:
	PartyManager.freeze_camera()
	PartyManager.freeze_actors()

func restore_party() -> void:
	PartyManager.unfreeze_camera()
	PartyManager.unfreeze_actors()

func set_world_visible(visible: bool) -> void:
	ZoneManager.set_world_visible(visible)

func set_party_visible(visible: bool) -> void:
	PartyManager.set_party_visible(visible)

func set_clock_paused(paused: bool) -> void:
	GlobalHUD.set_clock_paused(paused)

func hide_hud() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_youns_status_visible(false)

func restore_hud() -> void:
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
