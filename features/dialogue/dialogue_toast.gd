class_name DialogueToast
extends RefCounted

## Notificación flotante no-modal (no pausa el juego) con el mismo panel/
## borde que la caja de diálogo; se desvanece sola después de `duration`
## segundos. `host` es el autoload Dialogue, dueño exclusivo de esta
## instancia. Sin tipo propio porque los autoloads de este proyecto no
## declaran class_name.

var host
var _tween: Tween

func _init(p_host) -> void:
	host = p_host

func show_text(text: String, duration: float = 2.5) -> void:
	host._toast_label.text = text
	host._toast_label.modulate.a = 1.0
	host._toast.show()
	if _tween:
		_tween.kill()
	_tween = host.create_tween()
	_tween.tween_interval(duration - 0.6)
	_tween.tween_property(host._toast_label, "modulate:a", 0.0, 0.6)
	_tween.tween_callback(host._toast.hide)
