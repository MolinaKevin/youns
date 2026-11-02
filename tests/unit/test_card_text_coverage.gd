extends GutTest

## Cada card_type que declara CardActionLine tiene que tener su propia rama en
## CardText.line_parts() — si se agrega un TYPE_* nuevo y se olvida acá, la
## carta cae en la rama por defecto (sin ícono) en silencio, sin ningún error.

func test_line_parts_tiene_rama_para_cada_card_type() -> void:
	var constants: Dictionary = (preload("res://data/card_action_line.gd") as GDScript).get_script_constant_map()
	for const_name in constants:
		if not String(const_name).begins_with("TYPE_"):
			continue
		var card_type: String = constants[const_name]
		var line := CardActionLine.new()
		line.card_type = card_type
		var parts := CardText.line_parts(line)
		assert_false(parts.is_empty(),
			"card_type '%s' (%s) no genera ninguna parte visible en CardText.line_parts()." % [card_type, const_name])
		if not parts.is_empty():
			assert_not_null(parts[0].get("icon"),
				"card_type '%s' (%s) cae en la rama por defecto de line_parts() (sin ícono) — falta agregar su rama." % [card_type, const_name])
