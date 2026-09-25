extends SceneTree

## Exporta los Youns reales del juego (data/youns/*.tres) para la página de
## evoluciones. Genera docs/evoluciones/datos_juego.js, que la página combina
## con datos.js (árbol, condiciones y Youns provisorios).
##
## Uso, desde la raíz del proyecto:
##   godot --headless --path . --script res://tools/export_evoluciones.gd

const YOUNS_DIR := "res://data/youns/"
const OUTPUT := "res://docs/evoluciones/datos_juego.js"

## Youns de prueba que no forman parte del árbol.
const EXCLUIR := ["agumon", "monzaemon"]

## Etapas del código → etapas de la página.
const ETAPAS := {"adolescente": "rookie"}


func _initialize() -> void:
	var youns: Array = []
	var files := DirAccess.get_files_at(YOUNS_DIR)
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var data := load(YOUNS_DIR + file) as YounData
		if data == null or data.id in EXCLUIR:
			continue
		var youn := {
			"id": data.id,
			"nombre": data.youn_name,
			"etapa": ETAPAS.get(data.stage, data.stage),
			"archivo": "data/youns/" + file,
		}
		if data.is_wildcard:
			youn["comodin"] = true
		if data.base_stats:
			youn["stats"] = data.base_stats.to_dict()
		youns.append(youn)

	var out := FileAccess.open(OUTPUT, FileAccess.WRITE)
	if out == null:
		push_error("No se pudo escribir %s" % OUTPUT)
		quit(1)
		return
	out.store_string("// Generado por tools/export_evoluciones.gd — no editar a mano.\n")
	out.store_string("window.EVOLUCIONES_JUEGO = %s;\n" % JSON.stringify({"youns": youns}, "  ", false))
	out.close()
	print("Exportados %d Youns a %s" % [youns.size(), OUTPUT])
	quit()
