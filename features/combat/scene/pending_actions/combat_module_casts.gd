class_name CombatModuleCasts
extends CombatEffectResolver

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## El efecto de cada carta de módulo una vez que ya se eligió el módulo (y,
## si corresponde, la dirección o el punto de caída) — eso lo resuelve
## CombatModuleAction.

## Romper: destruye el módulo o, si es un árbol, lo tala (ver host._fell_tree).
func cast_break(played_card: CardActionLine, obs: Dictionary, flow: AsyncFlowToken) -> void:
	var count := maxi(1, played_card.module_count)
	if CombatObstacle.type_of(obs) == CombatObstacle.TREE:
		await host._fell_tree(played_card, obs, flow)
	else:
		var broken: int = host.map_area.interactions.break_modules(obs, count)
		host.emit_log("combat.log.module.broken", [played_card.name, broken])

## Crear: levanta un muro en el punto elegido.
func cast_build(played_card: CardActionLine, cell: Vector2) -> void:
	var count := maxi(1, played_card.module_count)
	var built: int = host.map_area.interactions.build_modules(cell, count)
	host.emit_log("combat.log.module.built", [played_card.name, built])

## Golpear: el módulo elegido se deliza hacia la dirección elegida.
func cast_module_push(played_card: CardActionLine, obs: Dictionary, cell: Vector2, flow: AsyncFlowToken) -> void:
	var result: Dictionary = host.map_area.interactions.slide_module(obs, cell - obs["pos"], host.w(played_card.cast_range_cells()))
	match result["hit"]:
		"enemy":
			host.emit_log("combat.log.module.push_hits_enemy", [played_card.name, played_card.damage])
			await host.deal_damage_to_enemy.call(played_card.damage, true, played_card.damage_type)
			if not _flow_is_active(flow): return
		"player":
			host.emit_log("combat.log.module.push_hits_player", [played_card.name, played_card.damage])
			await host.deal_damage_to_player.call(played_card.damage, true, played_card.damage_type)
			if not _flow_is_active(flow): return
		_:
			if not result.get("tree", {}).is_empty():
				host.emit_log("combat.log.module.push_hits_tree", [played_card.name])
			else:
				host.emit_log("combat.log.module.pushed", [played_card.name])

## Lanzar: el módulo elegido cae sobre el punto elegido.
func cast_module_throw(played_card: CardActionLine, obs: Dictionary, cell: Vector2, flow: AsyncFlowToken) -> void:
	var hits: Dictionary = host.map_area.interactions.throw_module(obs, cell)
	if hits["enemy"]:
		host.emit_log("combat.log.module.throw_hits_enemy", [played_card.name, played_card.damage])
		await host.deal_damage_to_enemy.call(played_card.damage, true, played_card.damage_type)
		if not _flow_is_active(flow): return
	if hits["player"]:
		host.emit_log("combat.log.module.throw_hits_player", [played_card.name, played_card.damage])
		await host.deal_damage_to_player.call(played_card.damage, true, played_card.damage_type)
		if not _flow_is_active(flow): return
	if not hits["enemy"] and not hits["player"]:
		host.emit_log("combat.log.module.throw_breaks", [played_card.name])

## Derrumbar: los módulos pegados al enemigo elegido le caen encima.
func cast_collapse(played_card: CardActionLine, flow: AsyncFlowToken) -> void:
	var fallen: int = host.map_area.interactions.collapse_modules_on_enemy()
	if fallen == 0:
		host.emit_log("combat.log.module.collapse_none", [played_card.name])
	else:
		var total := played_card.damage * fallen
		host.emit_log("combat.log.module.collapse_hits_enemy", [played_card.name, fallen, total])
		await host.deal_damage_to_enemy.call(total, true, played_card.damage_type)
		if not _flow_is_active(flow): return
