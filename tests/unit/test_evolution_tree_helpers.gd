extends GutTest

const EvolutionFocusNavScript := preload("res://features/world/evolution/evolution_focus_nav.gd")
const EvolutionDetailOverlayScript := preload("res://features/world/evolution/evolution_detail_overlay.gd")


class NavigationHost extends Control:
	var buttons: Array[Button] = []
	var current: Button

	func current_evolution_node() -> Button:
		return current

	func evolution_node_buttons() -> Array[Button]:
		return buttons


class DetailHost extends Control:
	const PANEL_BG := Color(0.05, 0.1, 0.15)
	const KNOWN := Color(0.35, 0.85, 1.0)
	const CURRENT := Color(1.0, 0.85, 0.35)
	const HIDDEN := Color(0.3, 0.33, 0.36)
	const Intelligences := preload("res://data/youns/intelligences.gd")

	var focus_was_restored := false

	func is_current_youn(_data: YounData) -> bool:
		return false

	func restore_tree_focus() -> void:
		focus_was_restored = true


func test_navegacion_inicial_usa_el_youn_actual_del_host() -> void:
	var host := NavigationHost.new()
	add_child_autofree(host)
	var alternate := Button.new()
	var current := Button.new()
	host.add_child(alternate)
	host.add_child(current)
	host.buttons = [alternate, current]
	host.current = current
	var navigation := EvolutionFocusNavScript.new(host)

	navigation.focus_initial()

	assert_true(current.has_focus())


func test_cerrar_detalle_restaura_el_foco_mediante_la_api_del_host() -> void:
	var host := DetailHost.new()
	add_child_autofree(host)
	var detail := EvolutionDetailOverlayScript.new(host)
	detail.build()
	detail.overlay.visible = true

	detail.close_overlay()

	assert_false(detail.overlay.visible)
	assert_true(host.focus_was_restored)
