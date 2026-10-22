class_name CombatActorPresentation
extends RefCounted

## Construye las vistas de los actores y su UI flotante; no decide movimiento.
const DEFAULT_HEAD_HEIGHT := 1.6
const STATUS_LABEL_GAP := 0.35
const ActorViewScript := preload("res://features/combat/scene/combat_actor_view.gd")
var map: Node
var player_head_height := DEFAULT_HEAD_HEIGHT
var enemy_head_height := DEFAULT_HEAD_HEIGHT
var player_status_label: Label3D
var enemy_status_label: Label3D

func setup_actors() -> void:
	var player_view: CombatActorView = ActorViewScript.new()
	player_view.anim_keys = ["idle", "walk", "run", "attack", "range", "damage", "die"]
	player_view.priority_anims = map._PRIORITY_ANIMS
	player_view.anim_finished.connect(func(): map.player_anim_finished.emit())
	map._player_view = player_view
	map.add_child(player_view)
	var enemy_view: CombatActorView = ActorViewScript.new()
	enemy_view.anim_keys = ["idle", "walk", "run", "attack", "damage"]
	enemy_view.priority_anims = map._ENEMY_PRIORITY_ANIMS
	enemy_view.replay_priority_on_repeat = true
	enemy_view.always_use_placeholder_fallback = false
	enemy_view.anim_finished.connect(func(): map.enemy_anim_finished.emit())
	var fallback := MeshInstance3D.new()
	var capsule := CapsuleMesh.new(); capsule.radius = 0.4; capsule.height = 1.2
	fallback.mesh = capsule
	enemy_view.fallback_mesh = fallback
	enemy_view.add_child(fallback)
	map._enemy_view = enemy_view
	map.add_child(enemy_view)
	map._player_target = Vector3(map.player_pos.x, 0.0, map.player_pos.y)
	map._enemy_target = Vector3(map.enemy_pos.x, 0.0, map.enemy_pos.y)
	map._player_view.position = map._player_target
	map._enemy_view.position = map._enemy_target

func setup_player(data: YounData) -> void:
	if not data: return
	map._player_shadow_radius = data.combat_footprint_radius()
	player_head_height = _head_height(data)
	map._player_rotate_speed = data.rotate_speed
	map._player_view.setup(data)

func setup_enemy(data: YounData) -> void:
	if not data: return
	map._enemy_shadow_radius = data.combat_footprint_radius()
	enemy_head_height = _head_height(data)
	map._enemy_rotate_speed = data.rotate_speed
	map._enemy_view.setup(data)

func set_status_texts(player_text: String, enemy_text: String) -> void:
	if player_status_label == null:
		player_status_label = _make_label(Color(0.75, 0.95, 1.0))
		enemy_status_label = _make_label(Color(1.0, 0.85, 0.75))
	player_status_label.text = player_text; enemy_status_label.text = enemy_text
	place_status_labels()

func place_status_labels() -> void:
	if player_status_label == null or map._player_view == null or map._enemy_view == null: return
	player_status_label.position = map._player_view.position + Vector3(0.0, player_head_height + STATUS_LABEL_GAP, 0.0)
	enemy_status_label.position = map._enemy_view.position + Vector3(0.0, enemy_head_height + STATUS_LABEL_GAP, 0.0)

func _make_label(color: Color) -> Label3D:
	var label := Label3D.new(); label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true
	label.font_size = 40; label.outline_size = 10; label.modulate = color; label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.width = 520.0; label.pixel_size = 0.004
	map.add_child(label)
	return label

static func _head_height(data: YounData) -> float:
	var height := data.body_height * data.mesh_scale + data.mesh_y_offset
	return height if height > 0.3 else DEFAULT_HEAD_HEIGHT
