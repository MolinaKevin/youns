class_name CombatMapOverlay
extends Node3D

## Capa puramente visual: rangos, selección, hover y patrones. No contiene
## reglas espaciales; MapArea sigue calculando qué celdas son válidas.
var move_disc: MeshInstance3D
var player_circle: MeshInstance3D
var attack_disc: MeshInstance3D
var dest_marker: MeshInstance3D
var path_highlight: MeshInstance3D
var hover_cell: MeshInstance3D
var player_shadow: MeshInstance3D
var enemy_shadow: MeshInstance3D
var enemy_highlight: MeshInstance3D
var self_highlight: MeshInstance3D
var enemy_hover: MeshInstance3D
var self_hover: MeshInstance3D
var push_disc: MeshInstance3D
var push_enemy_disc: MeshInstance3D
var card_pattern_preview: MeshInstance3D
var overwatch_zone: MeshInstance3D
var overwatch_preview_disc: MeshInstance3D

func setup() -> void:
	move_disc = make_disc(Color(0.2, 0.45, 0.85, 0.35))
	player_circle = make_disc(Color(0.6, 0.85, 1.0, 0.50))
	attack_disc = make_disc(Color(0.9, 0.35, 0.1, 0.40))
	dest_marker = make_disc(Color(0.2, 0.95, 0.3, 0.80))
	path_highlight = make_disc(Color(0.3, 0.95, 0.45, 0.70))
	hover_cell = make_disc(Color(1.0, 1.0, 1.0, 0.55))
	player_shadow = make_disc(Color(0.3, 0.6, 1.0, 0.35))
	enemy_shadow = make_disc(Color(1.0, 0.3, 0.2, 0.35))
	push_disc = make_disc(Color(0.9, 0.2, 0.6, 0.40))
	push_enemy_disc = make_disc(Color(1.0, 0.5, 0.1, 0.70))
	card_pattern_preview = _make_empty_mesh()
	overwatch_zone = _make_empty_mesh()
	overwatch_preview_disc = _make_empty_mesh()
	enemy_highlight = make_highlight_disc(Color(1.0, 0.25, 0.1))
	self_highlight = make_highlight_disc(Color(0.2, 0.75, 1.0))
	enemy_hover = make_highlight_disc(Color(1.0, 0.85, 0.2))
	self_hover = make_highlight_disc(Color(0.6, 1.0, 1.0))

func _make_empty_mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.visible = false
	add_child(mesh)
	return mesh

func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func make_disc(color: Color) -> MeshInstance3D:
	var disc := _make_empty_mesh()
	disc.set_meta("fill_mat", make_material(Color(color.r, color.g, color.b, color.a * 0.5)))
	disc.set_meta("bord_mat", make_material(Color(minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0), minf(color.a + 0.3, 1.0))))
	return disc

func make_highlight_disc(color: Color) -> MeshInstance3D:
	var disc := make_disc(color)
	disc.set_meta("fill_mat", make_material(Color(color, 0.85)))
	disc.set_meta("bord_mat", make_material(Color(color.lightened(0.45), 1.0)))
	return disc
