class_name CombatModuleCasts
extends CombatEffectResolver

## El efecto de cada carta de módulo una vez que ya se eligió el módulo (y,
## si corresponde, la dirección o el punto de caída) — eso lo resuelve
## CombatModuleAction.

## Romper: destruye el módulo o, si es un árbol, lo tala (ver host._fell_tree).
func cast_break(played_card: CardActionLine, obs: Dictionary) -> void:
	var count := maxi(1, played_card.module_count)
	if obs.get("type", "") == "tree":
		await host._fell_tree(played_card, obs)
	else:
		var broken: int = host.map_area.break_modules(obs, count)
		host.log_requested.emit("%s: rompiste %d módulo(s)." % [played_card.name, broken])

## Crear: levanta un muro en el punto elegido.
func cast_build(played_card: CardActionLine, cell: Vector2) -> void:
	var count := maxi(1, played_card.module_count)
	var built: int = host.map_area.build_modules(cell, count)
	host.log_requested.emit("%s: levantaste %d módulo(s)." % [played_card.name, built])

## Golpear: el módulo elegido se deliza hacia la dirección elegida.
func cast_module_push(played_card: CardActionLine, obs: Dictionary, cell: Vector2) -> void:
	var result: Dictionary = host.map_area.slide_module(obs, cell - obs["pos"], host._w(played_card.cast_range_cells()))
	match result["hit"]:
		"enemy":
			host.log_requested.emit("¡%s! El módulo le pegó al enemigo — %d de daño." % [played_card.name, played_card.damage])
			await host._deal_damage_to_enemy.call(played_card.damage, true, played_card.damage_type)
		"player":
			host.log_requested.emit("¡%s! El módulo te pegó a vos — %d de daño." % [played_card.name, played_card.damage])
			await host._deal_damage_to_player.call(played_card.damage, true, played_card.damage_type)
		_:
			if not result.get("tree", {}).is_empty():
				host.log_requested.emit("%s: el módulo se estrella contra un árbol." % played_card.name)
			else:
				host.log_requested.emit("%s: mandaste el módulo a volar." % played_card.name)

## Lanzar: el módulo elegido cae sobre el punto elegido.
func cast_module_throw(played_card: CardActionLine, obs: Dictionary, cell: Vector2) -> void:
	var hits: Dictionary = host.map_area.throw_module(obs, cell)
	if hits["enemy"]:
		host.log_requested.emit("¡%s! El módulo cayó sobre el enemigo — %d de daño." % [played_card.name, played_card.damage])
		await host._deal_damage_to_enemy.call(played_card.damage, true, played_card.damage_type)
	if hits["player"]:
		host.log_requested.emit("¡%s! El módulo te cayó encima — %d de daño." % [played_card.name, played_card.damage])
		await host._deal_damage_to_player.call(played_card.damage, true, played_card.damage_type)
	if not hits["enemy"] and not hits["player"]:
		host.log_requested.emit("%s: el módulo se hizo pedazos contra el suelo." % played_card.name)

## Derrumbar: los módulos pegados al enemigo elegido le caen encima.
func cast_collapse(played_card: CardActionLine) -> void:
	var fallen: int = host.map_area.collapse_modules_on_enemy()
	if fallen == 0:
		host.log_requested.emit("%s: no hay módulos pegados al enemigo." % played_card.name)
	else:
		var total := played_card.damage * fallen
		host.log_requested.emit("¡%s! Se le cayeron %d módulo(s) encima — %d de daño." % [played_card.name, fallen, total])
		await host._deal_damage_to_enemy.call(total, true, played_card.damage_type)
