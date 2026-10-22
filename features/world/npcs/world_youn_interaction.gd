class_name WorldYounInteraction
extends RefCounted

## Cercanía y tecla de interactuar de WorldYoun: decide cuándo mostrar el
## prompt "[E]" y cuándo arrancar el encuentro (host._begin_encounter()). No
## sabe nada de diálogo ni combate — `host` es el WorldYoun dueño exclusivo
## de esta instancia.

var host: WorldYoun
var near := false

func _init(p_host: WorldYoun) -> void:
	host = p_host

func update_prompt_visibility() -> void:
	host.prompt.visible = host.requires_interact and host.active and near and not host._engaging_combat

## Lo llama host.set_active() cuando la zona dueña oculta/deshabilita al Youn.
func set_active(value: bool) -> void:
	if not value:
		near = false
		update_prompt_visibility()

func on_touch_area_body_entered(body: Node3D) -> void:
	if body != host._player or host._engaging_combat or not host.active:
		return
	if host.requires_interact:
		near = true
		update_prompt_visibility()
	else:
		host._begin_encounter()

func on_touch_area_body_exited(body: Node3D) -> void:
	if body != host._player:
		return
	near = false
	update_prompt_visibility()

## Consume el input de interactuar y arranca el encuentro si corresponde.
func handle_interact_input(event: InputEvent) -> void:
	if not host.requires_interact or not host.active or not near or host._engaging_combat or Dialogue.is_busy():
		return
	if not InputPresses.is_interact_pressed(event):
		return
	host.get_viewport().set_input_as_handled()
	host._begin_encounter()
