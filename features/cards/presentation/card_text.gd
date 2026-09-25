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
}

## Mismos colores que los charcos en el mapa, aclarados para leerse sobre la carta.
const PUDDLE_COLORS := {
	"wet": Color(0.1, 0.4, 0.9), "fire": Color(1.0, 0.35, 0.05), "grease": Color(0.55, 0.45, 0.05),
	"vine": Color(0.1, 0.7, 0.15), "blood": Color(0.7, 0.05, 0.05), "poison": Color(0.45, 0.0, 0.65),
	"sand": Color(0.85, 0.75, 0.4), "ice": Color(0.6, 0.9, 1.0), "bloody_ice": Color(0.55, 0.65, 0.9),
	"dark_smoke": Color(0.2, 0.15, 0.25),
}

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
	match line.card_type:
		"move":
			add.call("move", line.card_range, Color.WHITE, true)
		"melee_attack":
			# Cuerpo a cuerpo: el alcance es una regla del combate, no de la carta.
			add.call("sword", line.damage, Color.WHITE, true)
		"targeted_attack":
			add.call("sword", line.damage, Color.WHITE, true)
			add.call("target", line.card_range)
		"range_attack":
			add.call("bow", line.damage, Color.WHITE, true)
			add.call("target", line.card_range)
		"block":
			add.call("shield", line.block_amount, Color.WHITE, true)
		"grenade":
			add.call("bomb", line.damage, Color.WHITE, true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"trap_place", "trap_throw":
			add.call("trap", line.damage, Color.WHITE, true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"puddle":
			var tint: Color = PUDDLE_COLORS.get(line.puddle_effect, Color.WHITE)
			add.call("drop", 0, tint.lightened(0.3), true)
			add.call("throw", line.throw_range)
			add.call("radius", line.card_range)
		"push":
			add.call("push", line.throw_range, Color.WHITE, true)
			add.call("target", line.card_range)
		"rock_jump":
			add.call("jump", line.damage, Color.WHITE, true)
			add.call("target", line.card_range)
			add.call("throw", line.throw_range)
		"overwatch":
			add.call("eye", line.damage, Color.WHITE, true)
			add.call("target", line.card_range)
		_:
			parts.append({"icon": null, "value": LocalizationState.card_type_name(line.card_type), "color": Color.WHITE})
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
	return "  ·  ".join(parts)

## Las líneas de una mitad unidas con `separator`, con los valores finales
## para el Youn del jugador.
static func half_summary(half: CardAction, separator: String) -> String:
	var rows: PackedStringArray = []
	if half != null:
		for line in CardScaling.resolve_lines(half.lines, CardScaling.player_stats()):
			rows.append(line_summary(line))
	return separator.join(rows)
