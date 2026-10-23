class_name WorldYoun
extends CharacterBody3D

## Youn parado en el mundo: salvaje que patrulla/persigue/pelea, NPC que solo
## habla, o cualquier combinación — todo con el mismo nodo, configurando datos:
##   - youn_data: de acá sale el modelo (scene_idle/walk/run) y, si no se
##     pisan con los overrides de abajo, el radio de patrulla/detección.
##   - conversation: vacío = sin diálogo (tocarlo/interactuar va directo al
##     combate). Con diálogo, se reproduce antes; si tiene choices, se abre un
##     menú (ver NpcChoice.starts_combat); si no, decide `starts_combat`.
##   - requires_interact: false = tocarlo dispara todo (como un salvaje).
##     true = hace falta [E] estando cerca (como un NPC).
##   - wander_radius_override / detect_range_override: -1 = usar el valor de
##     youn_data. 0 = quieto / nunca persigue, sin tocar el .tres del personaje.

const GRAVITY := 20.0
const DROP_SCENE := preload("res://features/world/items/world_drop.tscn")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")

@export var youn_data: YounData
@export var world_enemy_id := ""
@export var active := true

@export_group("Diálogo / encuentro")
@export var conversation: NpcDialogue = null
## Si no hay choices (o no hay conversation), decide si al terminar pelea.
@export var starts_combat := true
@export var requires_interact := false
## -1 = usar collision_radius + 0.35 (el bump tradicional de los salvajes).
@export var interact_radius := -1.0

@export_group("Movimiento (-1 = usar youn_data)")
@export var wander_radius_override := -1.0
@export var detect_range_override := -1.0

@onready var body_root: Node3D = $Body
@onready var collision: CollisionShape3D = $Collision
@onready var touch_area: Area3D = $TouchArea
@onready var touch_shape: CollisionShape3D = $TouchArea/TouchCollision
@onready var popup_layer: CanvasLayer = $PopupLayer
@onready var popup_panel: Panel = $PopupLayer/Popup
@onready var popup_label: Label = $PopupLayer/Popup/Margin/Label
@onready var prompt: Label3D = $Prompt

var _ai: WorldYounAi
var _appearance: WorldYounAppearance
var _interaction: WorldYounInteraction
var _conversation: WorldYounConversation
var _combat_handoff: WorldYounCombatHandoff
var _player: CharacterBody3D
var _engaging_combat := false

func _ready() -> void:
	add_to_group("world_enemy")
	# Los NPC/Youns salvajes caminan sobre el mismo suelo y obstáculos que el
	# jugador. Los colliders exclusivos de cámara no deben frenarlos ni servir
	# como superficie para colocarlos al cargar una zona.
	collision_mask = CollisionLayers.ACTOR_WORLD_MASK
	if world_enemy_id == "":
		world_enemy_id = name
	_player = PartyManager.player
	_appearance = WorldYounAppearance.new(self)
	_setup()
	_snap_to_ground()
	_ai = WorldYounAi.new(self)
	_ai.flee_finished.connect(_on_flee_finished)
	_interaction = WorldYounInteraction.new(self)
	touch_area.body_entered.connect(_interaction.on_touch_area_body_entered)
	touch_area.body_exited.connect(_interaction.on_touch_area_body_exited)
	_conversation = WorldYounConversation.new(self)
	_combat_handoff = WorldYounCombatHandoff.new(self)
	prompt.visible = false
	LocalizationState.language_changed.connect(_apply_localized_text)
	_apply_localized_text()
	_ai.start_idle()

func _apply_localized_text(_language: String = "") -> void:
	prompt.text = LocalizationState.t("world.prompt.talk")

func _setup() -> void:
	if youn_data == null:
		return
	_appearance.setup()

	var cap := CapsuleShape3D.new()
	cap.radius = youn_data.collision_radius
	cap.height = youn_data.collision_height
	collision.shape = cap
	collision.position.y = youn_data.collision_height * 0.5

	var sphere := SphereShape3D.new()
	sphere.radius = interact_radius if interact_radius >= 0.0 else youn_data.collision_radius + 0.35
	touch_shape.shape = sphere

	popup_label.text = LocalizationState.t("world.enemy.intercepted", [youn_data.youn_name])

func _switch_anim(key: String) -> void:
	_appearance.switch_anim(key)

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_ai.tick(delta)
	move_and_slide()

func _on_flee_finished() -> void:
	_spawn_drop()
	queue_free()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _snap_to_ground() -> void:
	var start := global_position + Vector3.UP * 8.0
	var finish := global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(start, finish, CollisionLayers.ACTOR_WORLD_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = hit.position.y + youn_data.collision_height * 0.5

## Lo llama la zona dueña (ej. para ocultar/deshabilitar según progreso).
func set_active(value: bool) -> void:
	active = value
	_interaction.set_active(value)

func _unhandled_input(event: InputEvent) -> void:
	if _combat_handoff.handle_input(event):
		return
	_interaction.handle_interact_input(event)

func _begin_encounter() -> void:
	if _engaging_combat:
		return
	if conversation != null:
		_conversation.play()
	else:
		_combat_handoff.engage()

# ── Combate ───────────────────────────────────────────────────────────────────

func handle_player_victory(return_position: Vector3) -> void:
	_player = PartyManager.player
	set_physics_process(true)
	visible = true
	_engaging_combat = true
	touch_area.monitoring = false
	collision.disabled = true
	_ai.start_flee(return_position)

func _spawn_drop() -> void:
	var drop := DROP_SCENE.instantiate()
	drop.position = global_position + Vector3(0, 0.2, 0)
	drop.item_name = youn_data.loot_item_name
	drop.gold_amount = youn_data.loot_gold
	get_parent().add_child(drop)
