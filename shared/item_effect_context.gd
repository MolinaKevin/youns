class_name ItemEffectContext
extends RefCounted

## Servicios que necesita un ItemEffect para mutar una partida. Los recursos de
## datos no conocen los autoloads: la sesión les entrega este contexto al usar
## un ítem.

var _services: StatsServicesPort
var _check_status: Callable

func _init(services: StatsServicesPort = null, check_status: Callable = Callable()) -> void:
	_services = services
	_check_status = check_status

func add_stat(key: String, delta: int) -> void:
	_services.care().add_stat(key, delta)

func set_stat(key: String, value: int) -> void:
	_services.care().set_stat(key, value)

func set_weight(value: float) -> void:
	_services.care().set_weight(value)

func set_sick(value: bool) -> void:
	_services.care().set_sick(value)

func finish_meal() -> void:
	_services.care().on_meal_eaten()

func show_emotion(emotion_name: String) -> void:
	_services.emotions().show(emotion_name)

func start_evolution(youn_data_path: String) -> void:
	_services.life().start_evolution(youn_data_path)

func check_status() -> void:
	if _check_status.is_valid():
		_check_status.call()
