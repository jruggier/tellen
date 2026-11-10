extends GutTest
## Crossroads combat formulas (§5) checked against the §13.2 numbers.

var rules: CrossroadsCombatRules


func before_each() -> void:
	rules = CrossroadsCombatRules.new()


func _assert_side(attacker: CombatParticipant, defender: CombatParticipant, dmg: int, hit: int, crit: int) -> void:
	assert_eq(rules.damage(attacker, defender), dmg, "damage")
	assert_eq(rules.displayed_hit(attacker, defender), hit, "hit")
	assert_eq(rules.displayed_crit(attacker, defender), crit, "crit")


# §13.2 formula values -------------------------------------------------------

func test_early_swordsman_vs_brigand() -> void:
	var a: CombatParticipant = CombatFixtures.swordsman()
	var d: CombatParticipant = CombatFixtures.brigand()
	assert_eq(rules.hit_total(a), 102)
	assert_eq(rules.avoid_total(d), 10)
	_assert_side(a, d, 8, 92, 1)
	_assert_side(d, a, 11, 53, 0)
	assert_eq(rules.follow_up_percent(a, d), 50)
	assert_eq(rules.follow_up_damage(8, 50), 4)
	assert_eq(rules.follow_up_percent(d, a), 0)
	assert_true(rules.inflicts_stagger(a, d), "sword staggers axe")


func test_mid_rogue_vs_dark_mage() -> void:
	var a: CombatParticipant = CombatFixtures.rogue()
	var d: CombatParticipant = CombatFixtures.dark_mage()
	_assert_side(a, d, 14, 96, 12)
	_assert_side(d, a, 15, 58, 0)
	assert_eq(rules.crit_damage(14), 42)
	assert_eq(rules.follow_up_percent(a, d), 50)
	assert_eq(rules.follow_up_damage(14, 50), 7)
	# §5.5 loop is Knife > Gauntlet > Tome > Knife: tome staggers knife, not the reverse
	# (Jake, 2026-11-10; the §13.2 note "Knife staggers tome" was a typo).
	assert_false(rules.inflicts_stagger(a, d), "knife does not stagger tome")
	assert_true(rules.inflicts_stagger(d, a), "tome staggers knife")


func test_late_swordmaster_vs_general() -> void:
	var a: CombatParticipant = CombatFixtures.swordmaster()
	var d: CombatParticipant = CombatFixtures.general()
	_assert_side(a, d, 3, 100, 35)
	_assert_side(d, a, 26, 40, 0)
	assert_eq(rules.follow_up_percent(a, d), 100)
	assert_eq(rules.follow_up_damage(3, 100), 3)
	assert_false(rules.inflicts_stagger(a, d), "heavy is immune (and sword does not stagger lance)")


func test_late_sage_vs_general() -> void:
	var a: CombatParticipant = CombatFixtures.sage()
	var d: CombatParticipant = CombatFixtures.general()
	_assert_side(a, d, 24, 100, 6)
	assert_eq(rules.follow_up_percent(a, d), 60)
	assert_eq(rules.follow_up_damage(24, 60), 14)


func test_weight_fixture() -> void:
	var unit: CombatParticipant = CombatFixtures.participant({"spd": 10, "skl": 10, "bld": 6}, CombatFixtures.steel_sword())
	assert_eq(rules.weight_penalty(unit), 3)
	assert_eq(rules.effective_speed(unit), 7)
	assert_eq(rules.effective_skill_for_follow_ups(unit), 7)


func test_weight_flags_can_be_disabled() -> void:
	rules.weight_affects_speed = false
	rules.weight_affects_skill_for_followups = false
	var unit: CombatParticipant = CombatFixtures.participant({"spd": 10, "skl": 10, "bld": 6}, CombatFixtures.steel_sword())
	assert_eq(rules.effective_speed(unit), 10)
	assert_eq(rules.effective_skill_for_follow_ups(unit), 10)


# Follow-up curve edges: lead 4, 5, 9, 10, 12 ---------------------------------

func test_follow_up_curve_edges() -> void:
	var expected: Dictionary = {4: 0, 5: 50, 6: 60, 9: 90, 10: 100, 12: 100}
	for lead: int in expected:
		var a: CombatParticipant = CombatFixtures.participant({"skl": 10 + lead}, CombatFixtures.iron_sword())
		var d: CombatParticipant = CombatFixtures.participant({"skl": 10}, CombatFixtures.iron_sword())
		assert_eq(rules.follow_up_percent(a, d), expected[lead], "lead %d" % lead)


func test_staggered_unit_never_follows_up() -> void:
	var a: CombatParticipant = CombatFixtures.swordsman()
	a.staggered = true
	assert_eq(rules.follow_up_percent(a, CombatFixtures.brigand()), 0)


# Stagger ----------------------------------------------------------------------

func test_stagger_needs_matching_loop() -> void:
	var lance_user: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_lance())
	var sword_user: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_sword())
	assert_true(rules.inflicts_stagger(lance_user, sword_user), "lance > sword")
	assert_false(rules.inflicts_stagger(sword_user, lance_user), "sword does not stagger lance")


func test_bows_neither_stagger_nor_get_staggered() -> void:
	var bow_user: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_bow())
	var sword_user: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_sword())
	assert_false(rules.inflicts_stagger(bow_user, sword_user))
	assert_false(rules.inflicts_stagger(sword_user, bow_user))


func test_heavy_units_cannot_be_staggered() -> void:
	var lance_user: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_lance())
	var heavy_sword: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_sword(), CombatFixtures.heavy())
	assert_false(rules.inflicts_stagger(lance_user, heavy_sword))


func test_unarmed_defender_cannot_be_staggered() -> void:
	assert_false(rules.inflicts_stagger(CombatFixtures.swordsman(), CombatFixtures.participant({}, null)))


# Effectiveness, terrain, healing, ranges -------------------------------------

func test_effective_might_multiplier() -> void:
	var archer: CombatParticipant = CombatFixtures.participant({"str": 5}, CombatFixtures.iron_bow())
	var flier: CombatParticipant = CombatFixtures.participant({"def": 4}, null)
	flier.tags = [&"sky"]
	assert_true(rules.is_effective(archer, flier))
	assert_eq(rules.damage(archer, flier), 5 + 6 * 3 - 4)
	var walker: CombatParticipant = CombatFixtures.participant({"def": 4}, null)
	assert_eq(rules.damage(archer, walker), 5 + 6 - 4)


func test_terrain_bonuses() -> void:
	var fort := TerrainData.new()
	fort.avoid_bonus = 20
	fort.defense_bonus = 2
	fort.resistance_bonus = 2
	var brigand: CombatParticipant = CombatFixtures.brigand()
	brigand.terrain = fort
	assert_eq(rules.avoid_total(brigand), 30)
	assert_eq(rules.damage(CombatFixtures.swordsman(), brigand), 6)


func test_damage_never_negative() -> void:
	var weak: CombatParticipant = CombatFixtures.participant({"str": 0}, CombatFixtures.iron_sword())
	assert_eq(rules.damage(weak, CombatFixtures.general()), 0)


func test_unarmed_deals_nothing() -> void:
	var unarmed: CombatParticipant = CombatFixtures.participant({"str": 20}, null)
	_assert_side(unarmed, CombatFixtures.brigand(), 0, 0, 0)
	assert_false(rules.can_counter(unarmed, CombatFixtures.brigand(), 1))


func test_bows_cannot_counter_adjacent() -> void:
	var archer: CombatParticipant = CombatFixtures.participant({}, CombatFixtures.iron_bow())
	assert_false(rules.can_counter(archer, CombatFixtures.swordsman(), 1))
	assert_true(rules.can_counter(archer, CombatFixtures.swordsman(), 2))


func test_heal_amount() -> void:
	var healer: CombatParticipant = CombatFixtures.participant({"mag": 7}, CombatFixtures.mend())
	assert_eq(rules.heal_amount(healer), 17)
	assert_false(healer.has_attack_weapon(), "heal staves cannot attack")


func test_brave_strikes_twice() -> void:
	var brave_sword: WeaponData = CombatFixtures.iron_sword()
	brave_sword.brave = true
	assert_eq(rules.strikes_per_turn(CombatFixtures.participant({}, brave_sword)), 2)
	assert_eq(rules.strikes_per_turn(CombatFixtures.swordsman()), 1)


func test_modifiers_apply() -> void:
	var a: CombatParticipant = CombatFixtures.swordsman()
	var d: CombatParticipant = CombatFixtures.brigand()
	a.add_modifier(CombatParticipant.MOD_HIT, -10)
	d.add_modifier(CombatParticipant.MOD_DEFENSE, 2)
	assert_eq(rules.displayed_hit(a, d), 82)
	assert_eq(rules.damage(a, d), 6)


# True hit modes ----------------------------------------------------------------

func test_one_rn_true_hit_equals_displayed() -> void:
	assert_eq(rules.true_hit_chance(73), 73.0)


func test_two_rn_true_hit_curve() -> void:
	rules.true_hit_mode = CombatRules.TrueHitMode.TWO_RN
	assert_eq(rules.true_hit_chance(0), 0.0)
	assert_eq(rules.true_hit_chance(100), 100.0)
	assert_almost_eq(rules.true_hit_chance(50), 50.0, 0.6)
	assert_gt(rules.true_hit_chance(80), 80.0, "2RN inflates high hit")
	assert_lt(rules.true_hit_chance(20), 20.0, "2RN deflates low hit")


func test_hybrid_true_hit_curve() -> void:
	rules.true_hit_mode = CombatRules.TrueHitMode.HYBRID
	assert_eq(rules.true_hit_chance(30), 30.0, "below 50 is 1RN")
	assert_almost_eq(rules.true_hit_chance(50), 50.0, 0.01)
	assert_gt(rules.true_hit_chance(75), 75.0)
	assert_almost_eq(rules.true_hit_chance(100), 100.0, 0.01)


func test_rolls_are_deterministic_and_respect_bounds() -> void:
	for mode: int in [CombatRules.TrueHitMode.ONE_RN, CombatRules.TrueHitMode.TWO_RN, CombatRules.TrueHitMode.HYBRID]:
		rules.true_hit_mode = mode as CombatRules.TrueHitMode
		var rng_a := SeededRng.new(11)
		var rng_b := SeededRng.new(11)
		for i: int in 200:
			assert_eq(rules.roll_hit(rng_a, 60), rules.roll_hit(rng_b, 60))
			if i == 0:
				assert_false(rules.roll_hit(rng_a, 0), "0% never hits")
				assert_true(rules.roll_hit(rng_a, 100), "100% always hits")
				rules.roll_hit(rng_b, 0)
				rules.roll_hit(rng_b, 100)


func test_default_rules_validate() -> void:
	assert_eq(rules.validate().size(), 0)
