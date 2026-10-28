class_name PraderaCombatLayout
extends CombatBiomeLayout

func populate_map(construction) -> void:
	super.populate_map(construction)
	construction.add_solid(Vector2(14.0, 19.0), 1.5)
	construction.add_solid_box(Vector2(21.0, 9.0), Vector2(3.0, 2.5))
	construction.add_rock(Vector2(7.0, 14.0), 0.55)
	construction.add_rock(Vector2(15.0, 15.0), 0.5)
	construction.add_rock(Vector2(23.0, 17.0), 0.55)
	construction.add_bridge(Vector2(13.0, 24.0), Vector2(5.0, 2.0))
	construction.add_bridge(Vector2(17.0, 6.0), Vector2(2.0, 5.0))
	construction.add_tree(Vector2(5.0, 24.0))
	construction.add_tree(Vector2(22.0, 5.0))
	construction.add_tree(Vector2(20.0, 22.0))
	var platform_ramps: Array[Dictionary] = [
		{"side": "south", "width": 2.5},
		{"side": "east", "width": 2.5},
	]
	construction.add_platform(Vector2(8.0, 10.0), Vector2(5.0, 5.0), platform_ramps)
