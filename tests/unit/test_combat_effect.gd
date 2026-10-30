extends GutTest

const CombatEffects := preload("res://features/combat/scene/combat_effect.gd")

func test_zones_and_statuses_have_a_single_valid_contract() -> void:
	for effect in CombatEffects.ZONE_TYPES:
		assert_true(CombatEffects.is_known_zone(effect))
		if effect != CombatEffects.BLOODY_ICE:
			assert_false(CombatEffects.path_rule(effect).is_empty(), "Falta regla para %s" % effect)
	for status in CombatEffects.STATUS_TYPES:
		assert_false(CombatEffects.status_field(status).is_empty(), "Falta campo para %s" % status)

func test_zone_combinations_are_order_independent() -> void:
	assert_eq(CombatEffects.combined_zone_effect(CombatEffects.WET, CombatEffects.ICE), CombatEffects.ICE)
	assert_eq(CombatEffects.combined_zone_effect(CombatEffects.ICE, CombatEffects.BLOOD), CombatEffects.BLOODY_ICE)
	assert_eq(CombatEffects.combined_zone_effect(CombatEffects.FIRE, CombatEffects.BLOOD), CombatEffects.DARK_SMOKE)
