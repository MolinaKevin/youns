class_name CardText
extends RefCounted

## Textos de las cartas para la interfaz. Vive acá (y no en los recursos de
## datos) porque usa LocalizationState, que es un autoload.

const ICONS := {
	"move": preload("res://assets/icons/card/move.svg"),
	"sword": preload("res://assets/icons/card/sword.svg"),
	"bow": preload("res://assets/icons/card/bow.svg"),
	"shield": preload("res://assets/icons/card/shield.svg"),
	"target": preload("res://assets/icons/card/target.svg"),
	"throw": preload("res://assets/icons/card/throw.svg"),
	"radius": preload("res://assets/icons/card/radius.svg"),
	"bomb": preload("res://assets/icons/card/bomb.svg"),
	"drop": preload("res://assets/icons/card/drop.svg"),
	"trap": preload("res://assets/icons/card/trap.svg"),
	"push": preload("res://assets/icons/card/push.svg"),
	"retreat": preload("res://assets/icons/card/retreat.svg"),
	"jump": preload("res://assets/icons/card/jump.svg"),
	"eye": preload("res://assets/icons/card/eye.svg"),
	"keep": preload("res://assets/icons/card/keep.svg"),
	"heal": preload("res://assets/icons/card/heal.svg"),
	"clock": preload("res://assets/icons/card/clock.svg"),
	"pull": preload("res://assets/icons/card/pull.svg"),
	"anchor": preload("res://assets/icons/card/anchor.svg"),
	"break": preload("res://assets/icons/card/break.svg"),
	"wall": preload("res://assets/icons/card/wall.svg"),
}

## Mismos colores que los charcos en el mapa, aclarados para leerse sobre la carta.
const PUDDLE_COLORS := {
	"wet": Color(0.1, 0.4, 0.9), "fire": Color(1.0, 0.35, 0.05), "grease": Color(0.55, 0.45, 0.05),
	"vine": Color(0.1, 0.7, 0.15), "blood": Color(0.7, 0.05, 0.05), "poison": Color(0.45, 0.0, 0.65),
	"sand": Color(0.85, 0.75, 0.4), "ice": Color(0.6, 0.9, 1.0), "bloody_ice": Color(0.55, 0.65, 0.9),
	"dark_smoke": Color(0.2, 0.15, 0.25),
}

## Daño mágico y escudo mágico se tiñen de este color (el físico va en blanco).
const MAGIC_COLOR := Color(0.75, 0.6, 1.0)
## Costo de MP de una línea.
const MP_COLOR := Color(0.45, 0.75, 1.0)

static func icon(key: String) -> Texture2D:
	return ICONS.get(key)

## Partes que se muestran de una línea: [{"icon": Texture2D, "value": String, "color": Color}].
## El primer ícono dice qué hace la línea; los siguientes, sus distancias en casillas:
## target = rango, throw = distancia de lanzamiento, radius = radio del área.
static func line_parts(line: CardActionLine) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var add := func(key: String, value: int, color := Color.WHITE, show_zero := false) -> void:
		if value > 0 or show_zero:
			parts.append({"icon": ICONS[key], "value": str(value) if value > 0 else "", "color": color})
	var dmg_color: Color = MAGIC_COLOR if line.damage_type == CombatState.MAGICO else Color.WHITE
	match line.card_type:
		"move":
			add.call("move", line.card_range, Color.WHITE, true)
		"melee_attack":
			# Cuerpo a cuerpo: el alcance es una regla del combate, no de la carta.
			add.call("sword", line.damage, dmg_color, true)
		"range_attack":
			add.call("bow", line.damage, dmg_color, true)
			add.call("target", line.card_range)
		"block":
			add.call("shield", line.block_amount, Color.WHITE, true)
		"ward":
			add.call("shield", line.block_amount, MAGIC_COLOR, true)
		"counter":
			add.call("shield", 0, Color.WHITE, true)
			add.call("sword", line.damage, dmg_color, true)
		"mp_restore":
			add.call("heal", line.restore_amount, MP_COLOR, true)
		"grenade":
			add.call("bomb", line.damage, dmg_color, true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"trap_place", "trap_throw":
			add.call("trap", line.damage, Color.WHITE, true)  # las trampas siempre hacen daño físico
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"puddle":
			var tint: Color = PUDDLE_COLORS.get(line.puddle_effect, Color.WHITE)
			# El número junto a la gota es el daño por turno del estado que deja.
			add.call("drop", line.damage, tint.lightened(0.3), true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
			add.call("clock", line.duration)
		"push":
			add.call("push", line.throw_range, Color.WHITE, true)
			add.call("target", line.card_range)
		"pull":
			add.call("pull", line.throw_range, Color.WHITE, true)
			add.call("target", line.card_range)
		"break":
			add.call("break", line.module_count, Color.WHITE, true)
			add.call("target", line.card_range)
		"build":
			add.call("wall", line.module_count, Color.WHITE, true)
			add.call("target", line.card_range)
		"element_bolt":
			add.call("drop", 0, PUDDLE_COLORS.get(line.puddle_effect, Color.WHITE).lightened(0.3), true)
			add.call("bomb", line.damage, MAGIC_COLOR, true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"chain_bolt":
			add.call("bow", line.damage, MAGIC_COLOR, true)
			add.call("target", line.throw_range)
		"delayed_area":
			add.call("bomb", line.damage, MAGIC_COLOR, true)
			add.call("drop", 0, PUDDLE_COLORS.get(line.puddle_effect, Color.WHITE).lightened(0.3), true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
			add.call("clock", line.delay)
		"cone_blast":
			add.call("sword", line.damage, MAGIC_COLOR, true)
			add.call("target", line.throw_range)
		"curse":
			add.call("eye", line.damage, MAGIC_COLOR, true)
			add.call("clock", line.duration)
			add.call("target", line.throw_range)
		"nova":
			add.call("push", line.throw_range, MAGIC_COLOR, true)
			add.call("sword", line.damage, MAGIC_COLOR)
			add.call("radius", line.card_range)
		"heal":
			add.call("heal", line.restore_amount, Color(0.5, 1.0, 0.55), true)
		"enchant":
			add.call("sword", line.damage, MAGIC_COLOR, true)
		"puddle_hop":
			add.call("drop", line.damage, MAGIC_COLOR, true)
			add.call("throw", line.throw_range)
			add.call("move", line.card_range)
		"tree_climb":
			add.call("jump", line.damage, Color.WHITE, true)
			add.call("move", line.throw_range)
		"blink":
			add.call("move", line.throw_range, MAGIC_COLOR, true)
		"module_throw":
			add.call("wall", 0, Color.WHITE, true)
			add.call("throw", line.throw_range)
			add.call("bomb", line.damage, dmg_color)
		"collapse":
			add.call("wall", 0, Color.WHITE, true)
			add.call("sword", line.damage, dmg_color)
			add.call("target", line.card_range)
		"module_push":
			add.call("wall", 0, Color.WHITE, true)
			add.call("push", line.throw_range)
			add.call("sword", line.damage, dmg_color)
		"anchor":
			add.call("anchor", line.throw_range, Color.WHITE, true)
			add.call("throw", line.card_range)
		"rock_jump":
			add.call("jump", line.damage, dmg_color, true)
			add.call("target", line.card_range)
			add.call("throw", line.throw_range)
		"overwatch":
			add.call("eye", line.damage, dmg_color, true)
			add.call("target", line.card_range)
		_:
			parts.append({"icon": null, "value": LocalizationState.card_type_name(line.card_type), "color": Color.WHITE})
	if line.mp_cost > 0:
		parts.append({"icon": null, "value": "%d MP" % line.mp_cost, "color": MP_COLOR})
	return parts

## "Tipo · Daño 6 · Rango 1"
static func line_summary(line: CardActionLine) -> String:
	var parts: PackedStringArray = [LocalizationState.card_type_name(line.card_type)]
	if line.damage > 0:
		parts.append(LocalizationState.t("card.stat.damage", [line.damage]))
	if line.block_amount > 0:
		parts.append(LocalizationState.t("card.stat.block", [line.block_amount]))
	if line.card_range > 0:
		parts.append(LocalizationState.t("card.stat.range", [line.card_range]))
	if line.throw_range > 0:
		parts.append(LocalizationState.t("card.stat.throw", [line.throw_range]))
	if line.duration > 0:
		parts.append(LocalizationState.t("card.stat.duration", [line.duration]))
	if line.mp_cost > 0:
		parts.append("%d MP" % line.mp_cost)
	return "  ·  ".join(parts)

## Las líneas de una mitad unidas con `separator`, con los valores finales
## para el Youn del jugador.
static func half_summary(half: CardAction, separator: String) -> String:
	var rows: PackedStringArray = []
	if half != null:
		for line in CardScaling.resolve_lines(half.lines, CardScaling.player_stats()):
			rows.append(line_summary(line))
	return separator.join(rows)
