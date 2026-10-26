class_name CombatSpellCasts
extends CombatEffectResolver
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")

## El efecto de cada hechizo una vez que ya se confirmó el punto/dirección/
## objetivo (eso lo decide CombatSpellAction). Esta clase no sabe nada de
## selección en el mapa ni de fases — solo recibe la carta y el dato ya
## resuelto (cell, dir, el charco o el árbol elegidos) y aplica el efecto.

## Chispa / Escarcha: daño mágico en un círculo y cambia los charcos que toca.
func cast_element_bolt(played_card: CardActionLine, cell: Vector2) -> void:
	var radius := host.w(played_card.primary_range_cells())
	if played_card.pattern != null:
		host.map_area.presentation.show_card_pattern(played_card.pattern, cell, Vector2(0, 1), radius)
	var from_effects: Array = CombatEffect.ELEMENT_CONVERSIONS.get(played_card.puddle_effect, [])
	var converted: int = host.map_area.interactions.convert_puddles(cell, radius, from_effects, played_card.puddle_effect)
	if converted > 0:
		host.emit_log("combat.log.spell.puddles_converted", [played_card.name, converted])
	if played_card.puddle_effect == "fire" and host.map_area.interactions.ignite_trees_in_circle(cell, radius) > 0:
		host.emit_log("combat.log.spell.tree_ignited", [played_card.name])
	elif played_card.puddle_effect == "ice" and host.map_area.interactions.extinguish_trees_in_circle(cell, radius) > 0:
		host.emit_log("combat.log.spell.tree_extinguished", [played_card.name])
	var hit_enemy: bool = host.map_area.interactions.is_enemy_in_card_pattern(played_card.pattern, cell, Vector2(0, 1), radius) if played_card.pattern != null else host.map_area.queries.is_enemy_in_area_circle(cell, radius)
	if not hit_enemy:
		host.emit_log("combat.log.spell.missed_enemy", [played_card.name])
		return
	var was_wet: bool = host.state.enemy_wet_turns > 0
	host.emit_log("combat.log.spell.hits_enemy", [played_card.name, played_card.damage])
	await host.deal_damage_to_enemy.call(played_card.damage, true, CombatState.MAGICO)
	if host.state.enemy_hp <= 0:
		return
	if played_card.puddle_effect == "ice" and was_wet:
		host._apply_spell_status("freeze", CombatPlayerActions.FREEZE_TURNS)
	elif played_card.status_effect != "ninguno":
		host._apply_spell_status(played_card.status_effect, maxi(1, played_card.duration))

## Descarga: rayo en línea. Pega doble a los mojados y se propaga por el agua
## que toca (a quien esté parado en ella, también a vos).
func cast_chain_bolt(played_card: CardActionLine, bolt_dir: Vector2) -> void:
	var from: Vector2 = host.map_area.player_pos
	var to: Vector2 = from + bolt_dir * host.w(played_card.cast_range_cells())
	# Pararrayos: el rayo se frena en el primer árbol y le pega a quien esté arriba.
	var rod: Dictionary = host.map_area.interactions.first_tree_on_segment(from, to)
	if not rod.is_empty():
		to = from + (to - from) * float(rod["t"])
		host.emit_log("combat.log.spell.bolt_hits_tree", [played_card.name])
		if host.map_area.interactions.is_player_in_tree(rod["tree"]):
			host.emit_log("combat.log.spell.player_in_tree_hit", [played_card.damage])
			await host.deal_damage_to_player.call(played_card.damage, true, CombatState.MAGICO)
	var water: Array = host.map_area.interactions.puddles_on_segment(from, to, ["wet"])
	var enemy_in_water: bool = host.map_area.queries.is_enemy_in_zones(water)
	var hit_enemy: bool = host.map_area.queries.segment_hits_enemy(from, to) or enemy_in_water
	var hit_player: bool = host.map_area.queries.is_player_in_zones(water)
	if not hit_enemy and not hit_player:
		host.emit_log("combat.log.spell.missed_all", [played_card.name])
		return
	if hit_enemy:
		var dmg: int = played_card.damage * (2 if host.state.enemy_wet_turns > 0 or enemy_in_water else 1)
		host.emit_log("combat.log.spell.electrocutes_enemy", [played_card.name, dmg])
		await host.deal_damage_to_enemy.call(dmg, true, CombatState.MAGICO)
	if hit_player and host.state.player_hp > 0:
		var own: int = played_card.damage * 2
		host.emit_log("combat.log.spell.shock_returns", [played_card.name, own])
		await host.deal_damage_to_player.call(own, true, CombatState.MAGICO)

## Zona demorada: marca el punto, cae unas rondas después (ver
## CombatRoundResolver/MapArea.place_delayed_zone).
func cast_delayed_area(played_card: CardActionLine, cell: Vector2) -> void:
	# Deja charco solo si tiene duración (un charco permanente de un hechizo no).
	var effect := played_card.puddle_effect if played_card.duration > 0 else ""
	host.map_area.interactions.place_delayed_zone(cell, host.w(played_card.primary_range_cells()), played_card.damage, played_card.name,
		played_card.delay, effect, played_card.duration)
	host.emit_log("combat.log.spell.delayed_zone_marked", [played_card.name, maxi(1, played_card.delay)])

## Soplido en cono: daño y estado si alcanza al enemigo, puede prender árboles.
func cast_cone_blast(played_card: CardActionLine, blast_dir: Vector2) -> void:
	var cone_angle := played_card.pattern.cone_half_angle if played_card.pattern != null else CombatPlayerActions.CONE_HALF_ANGLE
	if played_card.pattern != null:
		host.map_area.presentation.show_card_pattern(played_card.pattern, host.map_area.player_pos, blast_dir, host.w(played_card.cast_range_cells()))
	if played_card.status_effect == "burn" and host.map_area.interactions.ignite_trees_in_cone(host.map_area.player_pos, blast_dir, host.w(played_card.cast_range_cells()), cone_angle) > 0:
		host.emit_log("combat.log.spell.tree_ignited", [played_card.name])
	var in_pattern: bool = host.map_area.interactions.is_enemy_in_card_pattern(played_card.pattern, host.map_area.player_pos, blast_dir, host.w(played_card.cast_range_cells())) if played_card.pattern != null else host.map_area.queries.is_enemy_in_cone(host.map_area.player_pos, blast_dir, host.w(played_card.cast_range_cells()), cone_angle)
	if in_pattern:
		host.emit_log("combat.log.spell.reaches_enemy", [played_card.name, played_card.damage])
		await host.deal_damage_to_enemy.call(played_card.damage, true, CombatState.MAGICO)
		if played_card.status_effect != "ninguno" and host.state.enemy_hp > 0:
			host._apply_spell_status(played_card.status_effect, maxi(1, played_card.duration))
	else:
		host.emit_log("combat.log.spell.missed_all", [played_card.name])

## Maldición: daño directo opcional + estado. Las raíces de un árbol cercano
## suman un turno de enredo.
func cast_curse(played_card: CardActionLine) -> void:
	if played_card.damage > 0:
		await host.deal_damage_to_enemy.call(played_card.damage, true, CombatState.MAGICO)
	var turns: int = maxi(1, played_card.duration)
	if played_card.status_effect == "entangle" and host.map_area.interactions.is_tree_near(host.map_area.enemy_pos, CombatPlayerActions.TREE_ROOT_REACH):
		turns += CombatPlayerActions.TREE_ROOT_BONUS_TURNS
		host.emit_log("combat.log.spell.tree_roots_help")
	host._apply_spell_status(played_card.status_effect, turns)

## Parpadeo: teletransporte instantáneo, sin daño ni estado.
func cast_blink(played_card: CardActionLine, cell: Vector2) -> void:
	host.map_area.interactions.blink_player_to(cell)
	host.emit_log("combat.log.spell.blink", [played_card.name])

## Traslado de charco: el charco salta a `cell`. Si le cae encima al enemigo,
## el resolver de zonas aplica su estado; el hielo cae como granizo.
func cast_puddle_hop(played_card: CardActionLine, moved_puddle: Dictionary, cell: Vector2) -> void:
	var effect: String = moved_puddle.get("effect", "wet")
	var zone_damage: int = moved_puddle.get("damage", 0)
	var landed: Dictionary = host.map_area.interactions.move_puddle(moved_puddle, cell)
	if not host.map_area.queries.is_enemy_in_area_circle(cell, landed.get("radius", 0.0)):
		host.emit_log("combat.log.spell.puddle_lands_elsewhere", [played_card.name])
		return
	if effect == "ice":
		host.emit_log("combat.log.spell.hail_hits_enemy", [played_card.name, played_card.damage])
		await host.deal_damage_to_enemy.call(played_card.damage, true, CombatState.MAGICO)
		return
	host.emit_log("combat.log.spell.puddle_hits_enemy", [played_card.name])
	var fx: Array = host.zone_effects.apply_direct_impact(host.state, effect, zone_damage, false)
	if not fx.is_empty() and fx[1] > 0:
		host.emit_log("combat.status.enemy_applied", [LocalizationState.t("combat.status_name.%s" % fx[0]), fx[1]])

## Trepar árbol: quedás arriba hasta que termine la ronda.
func cast_tree_climb(played_card: CardActionLine, climbed_tree: Dictionary, cell: Vector2) -> void:
	host.state.player_in_tree = true
	host.state.player_tree_landing = cell
	host.state.player_tree_drop_damage = played_card.damage
	host.map_area.interactions.climb_tree(climbed_tree, cell)
	host.emit_log("combat.log.spell.tree_climb", [played_card.name])
