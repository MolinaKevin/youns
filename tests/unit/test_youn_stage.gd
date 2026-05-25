extends GutTest

# Testea que el juego puede conocer la etapa del Youn activo.
# Etapas válidas: "bebe", "nino", "adolescente", "campeon", "ultimate"


# ── YounData.stage ────────────────────────────────────────────────────────────

func test_youn_data_stage_por_defecto_es_bebe() -> void:
	var y := YounData.new()
	assert_eq(y.stage, "bebe")


func test_youn_data_stage_se_puede_setear() -> void:
	var y := YounData.new()
	y.stage = "campeon"
	assert_eq(y.stage, "campeon")


func test_pombero_es_adolescente() -> void:
	var pombero := load("res://data/youns/pombero.tres") as YounData
	assert_eq(pombero.stage, "adolescente")


func test_nguruvilu_es_adolescente() -> void:
	var nguruvilu := load("res://data/youns/nguruvilu.tres") as YounData
	assert_eq(nguruvilu.stage, "adolescente")


# ── YounData.get_active_stage ─────────────────────────────────────────────────

func test_get_active_stage_sin_youn_activo_retorna_bebe() -> void:
	var save := PlayerSaveData.new()
	assert_eq(YounData.get_active_stage(save), "bebe")


func test_get_active_stage_con_pombero_retorna_adolescente() -> void:
	var save := PlayerSaveData.new()
	save.current_youn_path = "res://data/youns/pombero.tres"
	assert_eq(YounData.get_active_stage(save), "adolescente")


func test_get_active_stage_con_nguruvilu_retorna_adolescente() -> void:
	var save := PlayerSaveData.new()
	save.current_youn_path = "res://data/youns/nguruvilu.tres"
	assert_eq(YounData.get_active_stage(save), "adolescente")


func test_get_active_stage_con_path_invalido_retorna_bebe() -> void:
	var save := PlayerSaveData.new()
	save.current_youn_path = "res://data/youns/no_existe.tres"
	assert_eq(YounData.get_active_stage(save), "bebe")


# ── LocalizationState.youn_stage_name ─────────────────────────────────────────

func test_youn_stage_name_adolescente_en_espanol() -> void:
	LocalizationState.set_language("es")
	assert_eq(LocalizationState.youn_stage_name("adolescente"), "Adolescente")


func test_youn_stage_name_adolescente_en_ingles() -> void:
	LocalizationState.set_language("en")
	assert_eq(LocalizationState.youn_stage_name("adolescente"), "Rookie")


func test_youn_stage_name_bebe_en_espanol() -> void:
	LocalizationState.set_language("es")
	assert_eq(LocalizationState.youn_stage_name("bebe"), "Bebé")


func test_youn_stage_name_campeon_en_espanol() -> void:
	LocalizationState.set_language("es")
	assert_eq(LocalizationState.youn_stage_name("campeon"), "Campeón")


func test_youn_stage_name_clave_inexistente_retorna_la_clave() -> void:
	LocalizationState.set_language("es")
	assert_eq(LocalizationState.youn_stage_name("desconocido"), "desconocido")
