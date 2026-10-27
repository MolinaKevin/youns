extends GutTest

var _save: PlayerSaveData
var _hours := 12.0
var _notifications := 0
var _context: CareSessionContext


func before_each() -> void:
	_save = PlayerSaveData.new()
	_hours = 12.0
	_notifications = 0
	_context = CareSessionContext.new(
		func() -> PlayerSaveData: return _save,
		func() -> YounData: return null,
		func() -> float: return _hours,
		func() -> void: _notifications += 1,
	)


func test_care_service_modifica_el_guardado_provisto_por_el_contexto() -> void:
	var service := CareStatsService.new(_context, func(): pass, func(_emotion: String): pass, func(_emotion: String): pass, func(_emotion: String): return null, func(): pass)
	_save.hambre = 10

	service.add_stat("hambre", 7)

	assert_eq(_save.hambre, 17)


func test_care_service_notifica_por_el_contexto() -> void:
	var service := CareStatsService.new(_context, func(): pass, func(_emotion: String): pass, func(_emotion: String): pass, func(_emotion: String): return null, func(): pass)

	service.set_discipline(55)

	assert_eq(_save.discipline, 55)
	assert_eq(_notifications, 1)


func test_emotion_service_usa_reloj_y_guardado_del_contexto() -> void:
	var service := EmotionService.new(_context, func(_rule): pass, func(): pass, func(): pass)

	service.show("sick")

	assert_true(_save.enfermo)
	assert_eq(service.active_states["sick"]["hour"], _hours)
