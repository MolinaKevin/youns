class_name YounSleepEvents
extends RefCounted

## Estado y reglas de la noche. No conoce escenas: recibe el Youn actual y
## aplica consecuencias mediante los servicios de cuidado.

var _penalty_applied := false
var _was_in_sleep_range := false
var _slept_this_cycle := false
var _tracking_initialized := false
var _sick_sleep_count := 0


func mark_player_slept() -> void:
	_slept_this_cycle = true
	var save := PlayerSessionAccess.save()
	if save != null and save.enfermo:
		_sick_sleep_count += 1
		if _sick_sleep_count >= 2:
			_sick_sleep_count = 0
			StatsManager.services.care().set_sick(false)
			StatsManager.services.care().add_care_mistake(1)


func on_clock_changed(hour: float, youn: CharacterBody3D) -> void:
	if not is_instance_valid(youn) or youn.youn_data == null:
		return
	var data: YounData = youn.youn_data
	var in_sleep := _hour_in_range(hour, data.sleep_hour, data.wake_hour)
	if not in_sleep:
		_penalty_applied = false
	elif not _penalty_applied and _hour_in_range(hour, (data.sleep_hour + 1) % 24, data.wake_hour):
		_penalty_applied = true
		StatsManager.services.care().add_care_mistake(1)
	if not _tracking_initialized:
		_was_in_sleep_range = in_sleep
		_tracking_initialized = true
		return
	if in_sleep and not _was_in_sleep_range:
		_slept_this_cycle = false
	if not in_sleep and _was_in_sleep_range and not _slept_this_cycle:
		StatsManager.services.care().add_stat("salud", -20)
		var save := PlayerSessionAccess.save()
		if save != null and save.energia < 20:
			StatsManager.services.care().set_sick(true)
	_was_in_sleep_range = in_sleep


func _hour_in_range(hour: float, from_h: int, to_h: int) -> bool:
	return hour >= float(from_h) or hour < float(to_h) if from_h > to_h else hour >= float(from_h) and hour < float(to_h)
