extends RefCounted

## Escena corta del jugador con su Youn (menú rápido: premiar, castigar, negar,
## jugar): el jugador se da vuelta hacia el Youn, el Youn se acerca, el jugador
## hace la animación y recién ahí vuelve el control. Uso:
##   await YounInteraction.run("happy")

## A qué distancia del jugador se para el Youn.
const MEET_DISTANCE := 1.4
const YOUN_SPEED := 2.5
const TURN_TIME := 0.3
## Pausa con los dos mirándose antes de la animación.
const FACE_PAUSE := 0.3

static var running := false


static func run(action_anim: String) -> void:
	var player := PartyManager.player
	var youn := PartyManager.youn
	if running or not is_instance_valid(player) or not is_instance_valid(youn):
		return
	running = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	youn.set_physics_process(false)
	youn.velocity = Vector3.ZERO
	player.set_anim_base("idle")

	# 1. El jugador se da vuelta hacia el Youn.
	var to_youn := youn.global_position - player.global_position
	to_youn.y = 0.0
	var dir := to_youn.normalized() if to_youn.length() > 0.05 \
		else Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	var rot_from := player.rotation.y
	var rot_to := atan2(dir.x, dir.z)
	var tw := player.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void: player.rotation.y = lerp_angle(rot_from, rot_to, t),
		0.0, 1.0, TURN_TIME)
	await tw.finished

	# 2. El Youn se acerca y queda mirándolo.
	var meet := player.global_position + dir * MEET_DISTANCE
	meet.y = youn.global_position.y
	var dist := Vector2(meet.x - youn.global_position.x, meet.z - youn.global_position.z).length()
	if dist > 0.1:
		_face_toward(youn, meet)
		youn.play_anim("walk")
		tw = youn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(youn, "global_position", meet, clampf(dist / YOUN_SPEED, 0.2, 3.0))
		await tw.finished
	youn.play_anim("idle")
	_face_toward(youn, player.global_position)
	await player.get_tree().create_timer(FACE_PAUSE, false).timeout

	# 3. La animación del jugador.
	var length: float = player.play_action(action_anim)
	await player.get_tree().create_timer(length, false).timeout
	player.stop_action()

	player.set_physics_process(true)
	youn.set_physics_process(true)
	running = false


static func _face_toward(node: Node3D, target: Vector3) -> void:
	var d := target - node.global_position
	d.y = 0.0
	if d.length() > 0.05:
		node.rotation.y = atan2(d.x, d.z)
