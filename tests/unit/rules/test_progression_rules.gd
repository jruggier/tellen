extends GutTest
## Growth modes, EXP, enemy stat generation and proficiency (§6).

const GROWABLE: Array[StringName] = [&"hp", &"str", &"spd"]


# Growths -----------------------------------------------------------------------

func test_effective_growths_add_class_modifiers() -> void:
	var rules := CrossroadsGrowthRules.new()
	var class_data := ClassData.new()
	class_data.growth_modifiers = StatBlock.from_values({"str": 10, "def": -5})
	var result: StatBlock = rules.effective_growths(StatBlock.from_values({"hp": 65, "str": 40, "def": 30}), class_data)
	assert_true(result.equals(StatBlock.from_values({"hp": 65, "str": 50, "def": 25})), str(result))


func test_fixed_mode_is_exact() -> void:
	var rules := CrossroadsGrowthRules.new()
	rules.growth_mode = CrossroadsGrowthRules.GrowthMode.FIXED
	var growths := StatBlock.from_values({"hp": 65, "str": 40, "spd": 135})
	var counters: Dictionary = {}
	var totals := StatBlock.new()
	for level: int in 10:
		totals.add_in_place(rules.roll_level_up(growths, GROWABLE, SeededRng.new(level), counters))
	# 10 level-ups: hp 650 → 6, str 400 → 4, spd 1350 → 13
	assert_true(totals.equals(StatBlock.from_values({"hp": 6, "str": 4, "spd": 13})), str(totals))
	assert_eq(counters[&"hp"], 50)


func test_fixed_mode_ignores_rng() -> void:
	var rules := CrossroadsGrowthRules.new()
	rules.growth_mode = CrossroadsGrowthRules.GrowthMode.FIXED
	var growths := StatBlock.from_values({"hp": 50})
	var a: StatBlock = rules.roll_level_up(growths, GROWABLE, SeededRng.new(1), {&"hp": 60})
	var b: StatBlock = rules.roll_level_up(growths, GROWABLE, SeededRng.new(999), {&"hp": 60})
	assert_true(a.equals(b))
	assert_eq(a.get_value(&"hp"), 1)


func test_random_mode_guarantees_over_100() -> void:
	var rules := CrossroadsGrowthRules.new()
	var growths := StatBlock.from_values({"hp": 100, "str": 0, "spd": 250})
	var rng := SeededRng.new(5)
	for i: int in 50:
		var gains: StatBlock = rules.roll_level_up(growths, GROWABLE, rng, {})
		assert_eq(gains.get_value(&"hp"), 1)
		assert_eq(gains.get_value(&"str"), 0)
		assert_between(gains.get_value(&"spd"), 2, 3)


func test_random_mode_average_matches_growth() -> void:
	var rules := CrossroadsGrowthRules.new()
	var growths := StatBlock.from_values({"str": 40})
	var rng := SeededRng.new(77)
	var total: int = 0
	for i: int in 5000:
		total += rules.roll_level_up(growths, GROWABLE, rng, {}).get_value(&"str")
	assert_almost_eq(total / 5000.0, 0.40, 0.03)


func test_random_mode_is_deterministic() -> void:
	var rules := CrossroadsGrowthRules.new()
	var growths := StatBlock.from_values({"hp": 65, "str": 40, "spd": 35})
	var a: StatBlock = rules.roll_level_up(growths, GROWABLE, SeededRng.new(3), {})
	var b: StatBlock = rules.roll_level_up(growths, GROWABLE, SeededRng.new(3), {})
	assert_true(a.equals(b))


func test_hybrid_mode_average_matches_growth() -> void:
	var rules := CrossroadsGrowthRules.new()
	rules.growth_mode = CrossroadsGrowthRules.GrowthMode.HYBRID
	var growths := StatBlock.from_values({"str": 40})
	var rng := SeededRng.new(8)
	var counters: Dictionary = {}
	var total: int = 0
	for i: int in 5000:
		total += rules.roll_level_up(growths, GROWABLE, rng, counters).get_value(&"str")
	assert_almost_eq(total / 5000.0, 0.40, 0.02)


func test_non_growable_stats_never_grow() -> void:
	var rules := CrossroadsGrowthRules.new()
	var gains: StatBlock = rules.roll_level_up(StatBlock.from_values({"mov": 100}), GROWABLE, SeededRng.new(1), {})
	assert_eq(gains.get_value(&"mov"), 0)


# EXP -----------------------------------------------------------------------------

func test_exp_formula() -> void:
	var rules := CrossroadsExpRules.new()
	var damaged: ExpRules.CombatOutcome = ExpRules.CombatOutcome.DAMAGED
	var killed: ExpRules.CombatOutcome = ExpRules.CombatOutcome.KILLED
	var missed: ExpRules.CombatOutcome = ExpRules.CombatOutcome.MISSED
	assert_eq(rules.combat_exp(4, 0, 3, 0, damaged, false), 9, "10 + (-1)")
	assert_eq(rules.combat_exp(4, 0, 3, 0, killed, false), 9 + 17, "+ 20 - 3")
	assert_eq(rules.combat_exp(4, 0, 3, 0, killed, true), 9 + 17 + 40, "boss bonus")
	assert_eq(rules.combat_exp(4, 0, 3, 0, missed, false), 1)
	assert_eq(rules.combat_exp(20, 0, 1, 0, damaged, false), 1, "floor of 1")
	assert_eq(rules.combat_exp(20, 0, 1, 0, killed, false), 1, "kill bonus floors at 0")
	assert_eq(rules.combat_exp(1, 0, 30, 0, killed, true), 100, "capped at 100")
	assert_eq(rules.heal_exp(5, 0), 12)


func test_exp_tier_offset() -> void:
	var rules := CrossroadsExpRules.new()
	rules.tier_level_offset = 10
	assert_eq(rules.combat_exp(5, 1, 5, 0, ExpRules.CombatOutcome.DAMAGED, false), 1, "promoted unit counts as level 15")


# Enemy stats ---------------------------------------------------------------------

func _brigand_class(tier: int = 0) -> ClassData:
	var class_data := ClassData.new()
	class_data.id = &"hatchetman"
	class_data.tier = tier
	class_data.generic_base_stats = StatBlock.from_values({"hp": 20, "str": 5, "spd": 3, "bld": 10})
	class_data.generic_growths = StatBlock.from_values({"hp": 80, "str": 50, "spd": 25})
	class_data.caps = StatBlock.from_values({"hp": 40, "str": 20, "spd": 20})
	return class_data


func test_enemy_stats_formula() -> void:
	var rules := CrossroadsEnemyStatRules.new()
	var stats: StatBlock = rules.generate(_brigand_class(), 5, &"normal")
	# 4 levels: hp 20 + round(3.2) = 23, str 5 + 2 = 7, spd 3 + round(1.0) = 4, bld unchanged
	assert_true(stats.equals(StatBlock.from_values({"hp": 23, "str": 7, "spd": 4, "bld": 10})), str(stats))


func test_enemy_stats_tier_difficulty_and_caps() -> void:
	var rules := CrossroadsEnemyStatRules.new()
	# tier 1 (+5) and hard (+3): 4 + 5 + 3 = 12 levels
	var stats: StatBlock = rules.generate(_brigand_class(1), 5, &"hard")
	assert_eq(stats.get_value(&"str"), 11, "5 + round(6.0)")
	var capped: StatBlock = rules.generate(_brigand_class(), 40, &"maddening")
	assert_eq(capped.get_value(&"hp"), 40, "capped")


func test_enemy_stats_are_deterministic() -> void:
	var rules := CrossroadsEnemyStatRules.new()
	assert_true(rules.generate(_brigand_class(), 9, &"normal").equals(rules.generate(_brigand_class(), 9, &"normal")))


func test_enemy_stats_unknown_difficulty_warns() -> void:
	var rules := CrossroadsEnemyStatRules.new()
	var stats: StatBlock = rules.generate(_brigand_class(), 1, &"impossible")
	assert_eq(stats.get_value(&"hp"), 20)
	assert_push_warning_count(1)


# Proficiency ---------------------------------------------------------------------

func test_proficiency_levels() -> void:
	var rules := ProficiencyRules.new()
	assert_eq(rules.level_for_points(0), 0)
	assert_eq(rules.level_for_points(9), 0)
	assert_eq(rules.level_for_points(10), 1)
	assert_eq(rules.level_for_points(44), 2)
	assert_eq(rules.level_for_points(1000), rules.max_level())
	assert_eq(rules.points_for_level(0), 0)
	assert_eq(rules.points_for_level(3), 45)
	assert_eq(rules.validate().size(), 0)


func test_proficiency_gain_by_tier() -> void:
	var rules := ProficiencyRules.new()
	var beginner := ClassData.new()
	beginner.primary_proficiency = &"sword"
	beginner.secondary_proficiencies = [&"foot"]
	assert_eq(rules.gain_for(beginner, &"sword"), 1)
	assert_eq(rules.gain_for(beginner, &"foot"), 1)
	assert_eq(rules.gain_for(beginner, &"axe"), 0)
	var intermediate: ClassData = beginner.duplicate() as ClassData
	intermediate.tier = 2
	assert_eq(rules.gain_for(intermediate, &"sword"), 2)
	assert_eq(rules.gain_for(intermediate, &"foot"), 1)


func test_proficiency_thresholds_must_increase() -> void:
	var rules := ProficiencyRules.new()
	rules.level_thresholds = [10, 10, 30]
	assert_eq(rules.validate().size(), 1)


# Ruleset ---------------------------------------------------------------------------

func test_ruleset_validation_catches_missing_rules_and_bad_links() -> void:
	var ruleset := Ruleset.new()
	ruleset.ruleset_id = &"t"
	ruleset.weapon_types = [CombatFixtures.weapon_type(&"sword", [&"axe"])]
	var problems: PackedStringArray = ruleset.validate()
	assert_eq(problems.size(), 6, "5 missing rule slots + unknown stagger target: %s" % problems)


func test_crossroads_ruleset_loads_rules() -> void:
	var ruleset: Ruleset = load("res://game/rules/crossroads_ruleset.tres") as Ruleset
	assert_true(ruleset.combat_rules is CrossroadsCombatRules)
	assert_true(ruleset.growth_rules is CrossroadsGrowthRules)
	assert_true(ruleset.exp_rules is CrossroadsExpRules)
	assert_true(ruleset.enemy_stat_rules is CrossroadsEnemyStatRules)
	assert_not_null(ruleset.proficiency_rules)
	assert_eq(ruleset.validate().size(), 0, str(ruleset.validate()))
