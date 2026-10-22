class_name CombatAttackAction
extends CombatPendingAction

## melee_attack y range_attack. El click no valida nada (eso pasa recién al
## confirmar, en execute()) — mismo comportamiento que grenade y trap.

var range_cells: int = 0

func start(p_index: int, p_card: CardActionLine, range_override: int = 0) -> void:
	index = p_index
	card = p_card
	var base_range := range_override if range_override > 0 else card.primary_range_cells()
	if host.state.player_blinded_turns > 0:
		base_range = mini(base_range, CardActionLine.cells_for_modules(CombatPlayerActions.BLINDED_RANGE_MODULES))
		host.log_requested.emit("¡Estás cegado! Rango reducido a %d módulos." % CombatPlayerActions.BLINDED_RANGE_MODULES)
	range_cells = base_range
	host.map_area.start_attack_selection(host._w(range_cells))
	if card.pattern != null:
		host.map_area.show_card_pattern_preview(card.pattern, host.map_area.player_pos, host.map_area.enemy_pos - host.map_area.player_pos, host._w(range_cells))

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(_cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var in_pattern: bool = host.map_area.is_enemy_in_card_pattern(played_card.pattern, host.map_area.player_pos, host.map_area.enemy_pos - host.map_area.player_pos, host._w(range_cells)) if played_card.pattern != null else host.map_area.is_enemy_in_attack_range(host._w(range_cells))
	if not in_pattern:
		host.log_requested.emit("%s: el enemigo está fuera de rango." % played_card.name)
		clear()
		return
	var damage: int = played_card.damage
	var damage_type: String = played_card.damage_type
	var enchant_status := ""
	if host.state.player_enchant_damage > 0 and damage_type == CombatState.FISICO:
		# Encantar arma: este golpe es mágico, pega más y aplica su estado.
		damage += host.state.player_enchant_damage
		damage_type = CombatState.MAGICO
		enchant_status = host.state.player_enchant_status
		host.state.player_enchant_damage = 0
		host.state.player_enchant_status = ""
		host.log_requested.emit("¡El arma encantada brilla!")
	host.log_requested.emit("%s: %d de daño." % [played_card.name, damage])
	# La acción se gasta antes de la animación: durante el await el jugador puede
	# elegir otra mitad o terminar el turno y state.turn_actions cambia.
	_spend_card()
	host.hand_refresh_requested.emit()
	await host._deal_damage_to_enemy.call(damage, false, damage_type)
	if enchant_status != "" and host.state.enemy_hp > 0:
		host._apply_spell_status(enchant_status, 3)
	host.ui_update_requested.emit()
	host._check_combat_end.call()

func clear() -> void:
	index = -1
	card = null
	range_cells = 0
	host.map_area.clear_attack_selection()
