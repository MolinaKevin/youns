class_name Youn3D
extends CharacterBody3D

## Compañero del jugador en el mundo exterior. Ensambla y expone la API
## pública; el seguimiento/recuperación vive en YounFollowMovement y el
## modelo/animación en YounAppearance (cada uno con este nodo como único
## punto de acceso). La burbuja de emociones (EmotionBubble) carga sus
## propios SpriteFrames y sólo se la ensambla como hijo acá.

@export var youn_data: YounData

## Bloquea el seguimiento horizontal sin tocar set_physics_process(), así la
## gravedad sigue actuando (p.ej. cutscenes donde el Youn tiene que caer).
var movement_locked := false

var _appearance: YounAppearance
var _movement: YounFollowMovement
var _emotion_bubble: AnimatedSprite3D = null


func _ready() -> void:
	_appearance = YounAppearance.new(self)
	_movement = YounFollowMovement.new(self)
	_setup_emotion_bubble()
	if youn_data:
		_appearance.load_model(youn_data)


func load_youn(data: YounData) -> void:
	youn_data = data
	_appearance.load_model(data)
	if _emotion_bubble:
		_emotion_bubble.update_height()


func _physics_process(delta: float) -> void:
	_movement.tick(delta)


func play_anim(anim_key: String) -> void:
	_appearance.switch_anim(anim_key)


func get_current_anim() -> String:
	return _appearance.current_anim()


func show_emotion(state_name: String) -> void:
	if _emotion_bubble:
		_emotion_bubble.show_emotion(state_name)


func get_active_emotions() -> Array[String]:
	if _emotion_bubble:
		return _emotion_bubble.get_active_emotions()
	return []


# ── Emotion bubble ────────────────────────────────────────────────────────────

## La burbuja carga y hornea sus propios SpriteFrames en su _ready() (ver
## emotion_bubble.gd); acá sólo se arma el nodo si party.tscn no lo trae.
func _setup_emotion_bubble() -> void:
	var bubble := get_node_or_null("EmotionBubble") as AnimatedSprite3D
	if bubble == null:
		bubble = AnimatedSprite3D.new()
		bubble.set_script(preload("res://features/world/party/emotion_bubble.gd"))
		bubble.name = "EmotionBubble"
		add_child(bubble)
	_emotion_bubble = bubble
