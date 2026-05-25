extends GutTest


func _make_frames(animations: Array[String]) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for anim in animations:
		sf.add_animation(anim)
	return sf


# ── sin emociones ─────────────────────────────────────────────────────────────

func test_vacio_sin_active_states() -> void:
	var result := EmotionDisplayQueue.build({}, false, _make_frames([]))
	assert_eq(result.size(), 0)


func test_vacio_con_sprite_frames_null() -> void:
	var result := EmotionDisplayQueue.build({"hungry": {}}, false, null)
	assert_eq(result.size(), 0)


# ── emociones normales ────────────────────────────────────────────────────────

func test_incluye_emocion_con_animacion() -> void:
	var sf := _make_frames(["hungry"])
	var result := EmotionDisplayQueue.build({"hungry": {}}, false, sf)
	assert_true("hungry" in result)


func test_no_incluye_emocion_sin_animacion() -> void:
	var sf := _make_frames([])
	var result := EmotionDisplayQueue.build({"hungry": {}}, false, sf)
	assert_eq(result.size(), 0)


func test_incluye_multiples_emociones() -> void:
	var sf := _make_frames(["hungry", "tired", "sad"])
	var result := EmotionDisplayQueue.build({"hungry": {}, "tired": {}, "sad": {}}, false, sf)
	assert_eq(result.size(), 3)


# ── emociones bloqueadas ──────────────────────────────────────────────────────

func test_bloqueo_excluye_todas_las_emociones() -> void:
	var sf := _make_frames(["hungry", "tired"])
	var result := EmotionDisplayQueue.build({"hungry": {}, "tired": {}}, true, sf)
	assert_eq(result.size(), 0)


func test_bloqueo_permite_evolving() -> void:
	var sf := _make_frames(["evolving"])
	var result := EmotionDisplayQueue.build({"evolving": {}}, true, sf)
	assert_true("evolving" in result)


func test_bloqueo_excluye_resto_pero_permite_evolving() -> void:
	var sf := _make_frames(["hungry", "evolving"])
	var result := EmotionDisplayQueue.build({"hungry": {}, "evolving": {}}, true, sf)
	assert_eq(result.size(), 1)
	assert_true("evolving" in result)


func test_sin_bloqueo_evolving_se_incluye_normalmente() -> void:
	var sf := _make_frames(["hungry", "evolving"])
	var result := EmotionDisplayQueue.build({"hungry": {}, "evolving": {}}, false, sf)
	assert_eq(result.size(), 2)
