class_name DialogueToast
extends RefCounted

## Notificación flotante no-modal (no pausa el juego) con el mismo panel/
## borde que la caja de diálogo; se desvanece sola después de `duration`
## segundos. `host` es el autoload Dialogue, dueño exclusivo de esta
## instancia. Sin tipo propio porque los autoloads de este proyecto no
## declaran class_name.

var host
var _tween: Tween
var _pending: Array[Dictionary] = []
var _showing := false

func _init(p_host) -> void:
	host = p_host

func show_text(text: String, duration: float = 2.5) -> void:
	_pending.append({"text": text, "duration": duration})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _pending.is_empty():
		_showing = false
		return
	_showing = true
	var notice: Dictionary = _pending.pop_front()
	var text := str(notice["text"])
	var duration := float(notice["duration"])
	host.show_toast_panel(text)
	if _tween:
		_tween.kill()
	_tween = host.create_tween()
	_tween.tween_interval(maxf(0.0, duration - 0.6))
	_tween.tween_method(host.set_toast_alpha, 1.0, 0.0, 0.6)
	_tween.tween_callback(_finish_current)


func _finish_current() -> void:
	host.hide_toast_panel()
	_showing = false
	_show_next()
