class_name CombatEnemyAI
extends RefCounted

const ENEMY_MOVE_RANGE := 20
const ENEMY_MELEE_RANGE := 2
const ENEMY_MELEE_DAMAGE := 7

var state
var combat: Node

func setup(p_combat: Node, p_state) -> void:
	combat = p_combat
	state = p_state

func take_turn() -> void:
	var trap_dmg: int = combat.map_area.check_and_trigger_traps(combat.map_area.enemy_pos, combat.map_area.enemy_shape)
	if trap_dmg > 0:
		combat.deal_damage_to_enemy(trap_dmg)
		combat.log_message("Enemy triggered a trap! %d damage." % trap_dmg)
		if combat.check_combat_end():
			return

	match state.enemy_intent["type"]:
		"attack":
			if combat.map_area.is_player_in_melee_range():
				combat.deal_damage_to_player(state.enemy_intent["value"])
				combat.log_message("Enemy attacks for %d." % state.enemy_intent["value"])
			else:
				combat.map_area.move_enemy_toward(combat.map_area.player_pos, ENEMY_MOVE_RANGE)
				combat.log_message("Enemy wanted to attack but moved closer instead.")
		"move":
			var moved: bool = combat.map_area.move_enemy_toward(combat.map_area.player_pos, ENEMY_MOVE_RANGE)
			if moved:
				combat.log_message("Enemy moves toward you.")
			else:
				combat.log_message("Enemy couldn't move.")

	combat.update_ui()
	pick_intent()

func pick_intent() -> void:
	var dist: float = combat.map_area.movement_distance(combat.map_area.enemy_pos, combat.map_area.player_pos)
	var roll := randi() % 100
	if dist <= float(ENEMY_MELEE_RANGE):
		state.enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
	elif dist <= 12.0:
		if roll < 65:
			state.enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
		else:
			state.enemy_intent = {"type": "move", "value": ENEMY_MOVE_RANGE}
	else:
		if roll < 25:
			state.enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
		else:
			state.enemy_intent = {"type": "move", "value": ENEMY_MOVE_RANGE}
