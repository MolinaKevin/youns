class_name CombatDamageResolver
extends RefCounted

## Aplica daño y sincroniza las animaciones de ataque/daño/idle del jugador y
## el enemigo. `host` es el Combat dueño exclusivo de esta instancia; sus
## métodos se pasan como Callable a CombatPlayerActions/CombatEnemyAI (ver
## Combat._ready()), que no saben ni necesitan saber de dónde vienen.

var host: Combat

func _init(p_host: Combat) -> void:
	host = p_host

func deal_to_enemy(amount: int, skip_attack_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
	host.state.damage_enemy(amount, damage_type)
	if not skip_attack_anim:
		await _play_player_anim_timed("attack")
	await _play_enemy_anim_timed("damage")

func deal_to_player(amount: int, skip_attack_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
	var dmg: int = host.state.damage_player(amount, damage_type)
	if dmg > 0 and host.state.player_overwatch_active:
		host.state.player_overwatch_active = false
		host.map_area.clear_overwatch_zone()
		host.log_message(LocalizationState.t("combat.overwatch.cancelled_by_damage"))
	if not skip_attack_anim:
		await _play_enemy_anim_timed("attack")
	await _play_player_anim_timed("damage")

func _play_player_anim_timed(anim_key: String) -> void:
	host.map_area.play_player_anim(anim_key)
	await host.map_area.player_anim_finished
	if not host._combat_finished and host.state.player_hp > 0:
		host.map_area.play_player_anim("idle")

func _play_enemy_anim_timed(anim_key: String) -> void:
	host.map_area.play_enemy_anim(anim_key)
	await host.map_area.enemy_anim_finished
	if not host._combat_finished and host.state.enemy_hp > 0:
		host.map_area.play_enemy_anim("idle")
