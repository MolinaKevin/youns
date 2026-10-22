class_name InputPresses
extends RefCounted

## "Apretó la tecla/botón recién ahora" (no autorepetición al mantenerla
## apretada): el mismo chequeo estaba copiado en más de media docena de
## scripts de mundo/menús para menu_toggle, ui_cancel e interact.
static func is_action_pressed_once(event: InputEvent, action: String) -> bool:
	if not event.is_action_pressed(action):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

static func is_menu_pressed(event: InputEvent) -> bool:
	return is_action_pressed_once(event, "menu_toggle")

static func is_cancel_pressed(event: InputEvent) -> bool:
	return is_action_pressed_once(event, "ui_cancel")

static func is_interact_pressed(event: InputEvent) -> bool:
	return is_action_pressed_once(event, "interact")
