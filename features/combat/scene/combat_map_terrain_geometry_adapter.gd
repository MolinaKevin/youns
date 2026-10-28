class_name CombatMapTerrainGeometryAdapter
extends CombatMapTerrainGeometryPort

func _init(value: CombatMapTerrain) -> void:
	bounds = CombatMapTerrainBoundsAdapter.new(value)
	collision = CombatMapTerrainCollisionAdapter.new(value)
	spatial = CombatMapTerrainSpatialAdapter.new(value)
