class_name CombatActorView
extends Node3D

const PlaceholderModel := preload("res://features/world/party/placeholder_model.gd")

## Vista 3D de un personaje de combate (jugador o enemigo): arma el cuerpo a
## partir de un YounData (una malla por animación) y cambia de animación por
## nombre. Reemplaza lo que antes era el mismo código escrito dos veces en
## map_area.gd (una copia para el jugador, otra para el enemigo) — ahora es
## una sola clase instanciada dos veces (ver MapArea._setup_actors()).
##
## Es también el nodo de posición/rotación del personaje: MapArea mueve este
## nodo directamente en su _process() (antes movía _player_body/_enemy_body).
##
## "Prioritaria" (`priority_anims`): una animación que no se puede cortar ni
## hacer loop (ataque/daño/morir) — cuando termina emite `anim_finished`, y si
## se pide una que no existe en el cuerpo actual, también avisa (como si
## hubiera terminado al toque) para no trabar a quien espera el aviso.

signal anim_finished

## Claves de scene_idle/scene_walk/... que arma esta vista (el jugador tiene
## "range" y "die" además de las que comparte con el enemigo).
@export var anim_keys: Array[String] = ["idle", "walk", "run", "attack", "damage"]
## Animaciones que no hacen loop y avisan (anim_finished) al terminar.
@export var priority_anims: Array[String] = []
## Si una animación prioritaria ya está sonando y se vuelve a pedir la misma,
## la vuelve a arrancar en vez de ignorarla (lo necesita el enemigo: varios
## golpes seguidos tienen que replayear "damage" cada vez; el jugador no).
@export var replay_priority_on_repeat := false
## Si no hay cuerpo armado, usa siempre el modelo de primitivas (el jugador).
## Si es false (el enemigo), el de primitivas solo se usa cuando tampoco hay
## `data.mesh` — si lo hay, se prefiere `fallback_mesh` en su lugar.
@export var always_use_placeholder_fallback := true

## Si no hay mallas animadas y el Youn tiene `mesh` (sin animar), usa esta
## malla de reserva en vez del modelo de primitivas. Null = no hay reserva
## (el jugador no la necesita, siempre tiene primitivas de reserva).
var fallback_mesh: MeshInstance3D

var bodies: Dictionary = {}
var current_anim: String = ""


func setup(data: YounData) -> void:
	if not data:
		return
	if fallback_mesh:
		fallback_mesh.visible = false
	for child in get_children():
		child.queue_free()
	bodies.clear()
	current_anim = ""

	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for key in anim_keys:
		var packed: PackedScene = data.get("scene_" + key)
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = 0.0
		body.rotation.y = data.mesh_rotation_y
		body.visible = false
		if mat:
			for mesh in Node3DSearch.find_meshes(body):
				mesh.material_override = mat
		add_child(body)
		bodies[key] = body

	if bodies.is_empty() and (always_use_placeholder_fallback or data.mesh == null):
		var placeholder := PlaceholderModel.build(data)
		placeholder.visible = false
		add_child(placeholder)
		bodies["idle"] = placeholder
	if bodies.is_empty() and data.mesh and fallback_mesh:
		fallback_mesh.mesh  = data.mesh
		fallback_mesh.scale = Vector3.ONE * data.mesh_scale
		fallback_mesh.visible = true
	else:
		play("idle")


func play(anim_key: String) -> void:
	var is_priority := anim_key in priority_anims
	if bodies.is_empty():
		if is_priority:
			anim_finished.emit.call_deferred()
		return
	var target := anim_key if anim_key in bodies else "idle"
	if is_priority and target != anim_key:
		anim_finished.emit.call_deferred()
		return
	if current_anim == target and not (is_priority and replay_priority_on_repeat):
		return
	if current_anim in bodies:
		bodies[current_anim].visible = false
	current_anim = target
	if target not in bodies:
		if is_priority:
			anim_finished.emit.call_deferred()
		return
	var body: Node3D = bodies[target]
	body.visible = true
	var anim_player := Node3DSearch.find_anim_player(body)
	if anim_player:
		var list := anim_player.get_animation_list()
		if not list.is_empty():
			var anim := anim_player.get_animation(list[0])
			if anim:
				anim.loop_mode = Animation.LOOP_NONE if is_priority else Animation.LOOP_LINEAR
			if is_priority:
				anim_player.animation_finished.connect(
					func(_n: StringName) -> void: anim_finished.emit(),
					CONNECT_ONE_SHOT
				)
			anim_player.play(list[0])
		elif is_priority:
			anim_finished.emit.call_deferred()
	elif is_priority:
		anim_finished.emit.call_deferred()


