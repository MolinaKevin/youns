class_name GameClock
extends RefCounted

## Reloj puro de la sesión. No conoce guardado, sueño, stats ni escenas: sólo
## conserva la fecha, avanza el tiempo y avisa los ticks que efectivamente
## transcurrieron.

signal clock_changed(current_hour: float, current_day: int)
signal twenty_min_ticked
signal paused_changed(paused: bool)

const HOURS_PER_DAY := 24.0
const TICKS_PER_HOUR := 3.0

var current_day := 1
var time_of_day_hours := 8.0
var paused := false

var _last_total_twenty_min_tick: int = 0


func _init() -> void:
	discard_pending_ticks()


## Avance del reloj de tiempo real. Los ticks intermedios se emiten en esta
## misma llamada, después de notificar la nueva hora.
func advance_real_seconds(delta: float, day_duration_seconds: float) -> void:
	if paused or day_duration_seconds <= 0.0:
		return
	advance_hours(delta * HOURS_PER_DAY / day_duration_seconds)


## Avanza horas de juego y aplica los ticks de veinte minutos correspondientes.
func advance_hours(hours: float) -> void:
	_apply_hours(hours)
	clock_changed.emit(time_of_day_hours, current_day)
	_emit_pending_ticks()


## Salta horas sin emitir ticks. Lo usa el sueño, que tiene sus propias reglas
## de recuperación y explícitamente no aplica desgaste nocturno acumulado.
func skip_hours(hours: float, notify: bool = true) -> void:
	_apply_hours(hours)
	discard_pending_ticks()
	if notify:
		clock_changed.emit(time_of_day_hours, current_day)


## Salta hasta la próxima aparición de esa hora y devuelve cuántas horas se
## omitieron. Si ya se pasó, la llegada es al día siguiente.
func skip_to_next_hour(hour: int, notify: bool = true) -> int:
	var target := clampi(hour, 0, int(HOURS_PER_DAY) - 1)
	var skipped := float(target) - time_of_day_hours
	if skipped <= 0.0:
		skipped += HOURS_PER_DAY
	skip_hours(skipped, notify)
	return roundi(skipped)


## Fija el reloj para cargar una partida. No genera ticks de un tiempo que no
## fue jugado; la notificación permite refrescar iluminación y HUD.
func set_time(day: int, hour: float, notify: bool = true) -> void:
	current_day = maxi(1, day)
	time_of_day_hours = hour
	_normalize_time()
	discard_pending_ticks()
	if notify:
		clock_changed.emit(time_of_day_hours, current_day)


func notify_clock_changed() -> void:
	clock_changed.emit(time_of_day_hours, current_day)


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	paused_changed.emit(paused)


func get_total_hours() -> float:
	return current_day * HOURS_PER_DAY + time_of_day_hours


func discard_pending_ticks() -> void:
	_last_total_twenty_min_tick = int(get_total_hours() * TICKS_PER_HOUR)


func _apply_hours(hours: float) -> void:
	time_of_day_hours += hours
	_normalize_time()


func _normalize_time() -> void:
	while time_of_day_hours >= HOURS_PER_DAY:
		time_of_day_hours -= HOURS_PER_DAY
		current_day += 1
	while time_of_day_hours < 0.0:
		time_of_day_hours += HOURS_PER_DAY
		current_day = maxi(1, current_day - 1)


func _emit_pending_ticks() -> void:
	var current_twenty_tick := int(get_total_hours() * TICKS_PER_HOUR)
	while _last_total_twenty_min_tick < current_twenty_tick:
		_last_total_twenty_min_tick += 1
		twenty_min_ticked.emit()
