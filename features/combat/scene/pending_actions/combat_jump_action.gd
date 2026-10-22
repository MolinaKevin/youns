class_name CombatJumpAction
extends CombatPendingAction

## Carta "rock_jump": elegir una piedra al alcance (fase 0) y después dónde
## aterrizar (fase 1).

var phase: int = 0
var rock_pos: Vector2 = Vector2(-1.0, -1.0)

func start(p_index: int, p_card: CardActionLine) -> bool:
	var rocks: Array[Dictionary] = host.map_area.get_rocks_in_range(host.map_area.player_pos, host._w(p_card.primary_range_cells()))
	if rocks.is_empty():
		host.log_requested.emit("%s: no hay piedras al alcance." % p_card.name)
		host.card_preview_hide_requested.emit()
		return false
	index = p_index
	phase = 0
	card = p_card
	host.map_area.start_rock_jump_selection(host._w(p_card.primary_range_cells()))
	host.log_requested.emit("Seleccioná una piedra dentro de %s módulos." % p_card.primary_module_label())
	return true

func on_tile_selected(pos: Vector2) -> void:
	if phase == 0:
		var rock: Dictionary = host.map_area.get_rock_near(pos)
		if rock.is_empty():
			return
		rock_pos = rock["pos"]
		phase = 1
		host.map_area.start_jump_landing_selection(rock_pos, host._w(card.cast_range_cells()))
		host.log_requested.emit("Piedra en (%.1f, %.1f). Elegí dónde aterrizar." % [rock_pos.x, rock_pos.y])
		return
	if rock_pos.distance_to(pos) > host._w(card.cast_range_cells()):
		return
	if not host.map_area.can_jump_land_at(pos):
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(landing_pos: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]

	var sep: Vector2 = landing_pos - host.map_area.enemy_pos
	if sep.length() < host.map_area.MIN_SEPARATION:
		landing_pos = host.map_area.enemy_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(host.map_area.MIN_SEPARATION, 0.0)) * host.map_area.MIN_SEPARATION

	host.map_area.land_player_from_jump(landing_pos)

	var hit_enemy: bool = host.map_area.is_enemy_near_pos(landing_pos, 1.5)

	_spend_card()

	if hit_enemy:
		host.log_requested.emit("¡%s! Caíste sobre el enemigo — %d de daño!" % [played_card.name, played_card.damage])
		await host._deal_damage_to_enemy.call(played_card.damage, false, played_card.damage_type)
	else:
		host.log_requested.emit("%s: aterrizaste en (%.1f, %.1f)." % [played_card.name, landing_pos.x, landing_pos.y])

	_finish()

func clear() -> void:
	index = -1
	phase = 0
	rock_pos = Vector2(-1.0, -1.0)
	card = null
	host.map_area.clear_rock_jump_selection()
