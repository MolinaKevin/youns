extends GutTest

const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")

func test_zones_and_statuses_have_a_single_valid_contract() -> void:
	for effect in CombatEffect.ZONE_TYPES:
		assert_true(CombatEffect.is_known_zone(effect))
		if effect != CombatEffect.BLOODY_ICE:
			assert_false(CombatEffect.path_rule(effect).is_empty(), "Falta regla para %s" % effect)
	for status in CombatEffect.STATUS_TYPES:
		assert_false(CombatEffect.status_field(status).is_empty(), "Falta campo para %s" % status)

func test_zone_combinations_are_order_independent() -> void:
	assert_eq(CombatEffect.combined_zone_effect(CombatEffect.WET, CombatEffect.ICE), CombatEffect.ICE)
	assert_eq(CombatEffect.combined_zone_effect(CombatEffect.ICE, CombatEffect.BLOOD), CombatEffect.BLOODY_ICE)
	assert_eq(CombatEffect.combined_zone_effect(CombatEffect.FIRE, CombatEffect.BLOOD), CombatEffect.DARK_SMOKE)
