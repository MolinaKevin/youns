class_name EvolutionFocusNav
extends RefCounted

## Navegación direccional (flechas) entre los botones del árbol de
## evoluciones: busca, en la dirección pedida, el botón habilitado más
## cercano "hacia adelante" (favorece la distancia en esa dirección sobre el
## desvío lateral). `host` es la pantalla (EvolutionTreeScreen) dueña
## exclusiva de esta instancia.

var host
var focused: Button

func _init(p_host) -> void:
	host = p_host

func focus_initial() -> void:
	var current := host._nodes.get(host._current_path) as Button
	if current != null and not current.disabled:
		current.grab_focus()
		return
	for node in host._nodes.values():
		var button := node as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return

func on_node_focused(button: Button) -> void:
	focused = button

func move(direction: Vector2) -> void:
	if focused == null:
		focus_initial()
		return
	var origin := focused.get_global_rect().get_center()
	var best: Button = null
	var best_score := INF
	for node in host._nodes.values():
		var candidate := node as Button
		if candidate == null or candidate.disabled or candidate == focused:
			continue
		var delta := candidate.get_global_rect().get_center() - origin
		var primary := delta.dot(direction)
		if primary <= 0.0:
			continue
		var lateral: float = absf(delta.dot(Vector2(-direction.y, direction.x)))
		var score := primary + lateral * 2.0
		if score < best_score:
			best_score = score
			best = candidate
	if best != null:
		best.grab_focus()
