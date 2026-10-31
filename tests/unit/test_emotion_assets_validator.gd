extends GutTest

const BUBBLE_FRAMES_PATH := "res://assets/emotions/bubble_frames.tres"
const ICON_FRAMES_PATH := "res://assets/emotions/emotion_frames.tres"


func test_bubble_frames_tienen_las_animaciones_requeridas() -> void:
	var frames := TypedResourceLoader.sprite_frames(BUBBLE_FRAMES_PATH)
	assert_eq(_validator().missing_animations(frames, PackedStringArray(["idle", "pop"])), PackedStringArray())


func test_iconos_de_emocion_tienen_frames_para_todas_las_reglas() -> void:
	var frames := TypedResourceLoader.sprite_frames(ICON_FRAMES_PATH)
	assert_eq(_validator().missing_animations(frames, PackedStringArray(["bathroom", "hungry", "tired", "sick", "stressed", "bored", "sad", "sleep", "evolving"])), PackedStringArray())


func test_animacion_vacia_se_considera_faltante() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("hungry")
	assert_eq(_validator().missing_animations(frames, PackedStringArray(["hungry"])), PackedStringArray(["hungry"]))


func _validator() -> EmotionAssetsValidator:
	return EmotionAssetsValidator.new()
