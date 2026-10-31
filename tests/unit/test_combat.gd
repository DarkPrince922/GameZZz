extends GutTest
## Pure maths and economy: damage, crits, combo steps, shop prices, stars.


func test_hit_damage_applies_multiplier() -> void:
	assert_almost_eq(CombatMath.hit_damage(10.0, 1.0, false), 10.0, 0.01)
	assert_almost_eq(CombatMath.hit_damage(10.0, 2.0, false), 20.0, 0.01)


func test_critical_hit_is_stronger() -> void:
	var normal := CombatMath.hit_damage(10.0, 1.0, false)
	var crit := CombatMath.hit_damage(10.0, 1.0, true)
	assert_gt(crit, normal, "crits must hit harder")
	assert_almost_eq(crit, 17.5, 0.1, "default crit multiplier is 1.75")


func test_crit_chance_is_clamped() -> void:
	assert_eq(CombatMath.clamp_crit(-1.0), 0.0)
	assert_eq(CombatMath.clamp_crit(5.0), 1.0)


func test_roll_crit_respects_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	assert_false(CombatMath.roll_crit(rng, 0.0), "0 chance never crits")
	assert_true(CombatMath.roll_crit(rng, 1.0), "1.0 chance always crits")
	var crits := 0
	for i in 1000:
		if CombatMath.roll_crit(rng, 0.25):
			crits += 1
	assert_between(crits, 150, 350, "25% chance should land near a quarter of the time")


func test_combo_steps_pick_the_right_multiplier() -> void:
	var steps: Array = [1.0, 1.0, 1.6]
	assert_almost_eq(CombatMath.combo_step(0, steps), 1.0, 0.01)
	assert_almost_eq(CombatMath.combo_step(2, steps), 1.6, 0.01)
	assert_almost_eq(CombatMath.combo_step(99, steps), 1.6, 0.01, "index is clamped")


func test_upgrade_prices_grow() -> void:
	var price0 := CombatMath.upgrade_price(30, 1.6, 0)
	var price1 := CombatMath.upgrade_price(30, 1.6, 1)
	var price4 := CombatMath.upgrade_price(30, 1.6, 4)
	assert_eq(price0, 30)
	assert_gt(price1, price0, "each level must cost more")
	assert_gt(price4, price1)


func test_upgrade_values() -> void:
	assert_almost_eq(CombatMath.upgrade_value(100.0, 10.0, 3), 130.0, 0.01)
	assert_almost_eq(CombatMath.upgrade_value(1.0, 0.08, 5), 1.4, 0.01)


func test_difficulty_scaling() -> void:
	assert_almost_eq(CombatMath.damage_taken(100.0, "easy"), 60.0, 0.1)
	assert_almost_eq(CombatMath.damage_taken(100.0, "normal"), 100.0, 0.1)
	assert_almost_eq(CombatMath.damage_taken(100.0, "nightmare"), 155.0, 0.5)
	assert_gt(CombatMath.enemy_health(100.0, "nightmare"), CombatMath.enemy_health(100.0, "normal"))
	assert_gt(CombatMath.shard_amount(10, "nightmare"), CombatMath.shard_amount(10, "normal"))


func test_unknown_difficulty_falls_back_to_normal() -> void:
	assert_almost_eq(CombatMath.damage_taken(100.0, "impossible"), 100.0, 0.01)


func test_stars() -> void:
	assert_eq(CombatMath.stars_awarded(true, true, true), 3)
	assert_eq(CombatMath.stars_awarded(true, false, true), 2)
	assert_eq(CombatMath.stars_awarded(true, false, false), 1)
	assert_eq(CombatMath.stars_awarded(false, true, true), 0, "not clearing gives no stars")


func test_shard_chain_pitch_rises_and_caps() -> void:
	var first := CombatMath.shard_chain_pitch(0)
	var fifth := CombatMath.shard_chain_pitch(4)
	var capped := CombatMath.shard_chain_pitch(100)
	assert_almost_eq(first, 1.0, 0.001)
	assert_gt(fifth, first, "chain must rise in pitch")
	assert_lte(capped, 1.45, "pitch must be capped to stay pleasant")
