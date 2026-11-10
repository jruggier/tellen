extends GutTest
## UnitStats (average stats at level, generic units) and CombatSimulation.

const DATA: String = "res://game/data/"

var ruleset: Ruleset


func before_all() -> void:
	ruleset = load("res://game/rules/crossroads_ruleset.tres") as Ruleset


func test_starting_stats_add_class_and_build_bonus() -> void:
	var gid: UnitData = load(DATA + "units/gid.tres") as UnitData
	var stats: StatBlock = UnitStats.starting_stats(gid, ruleset)
	assert_eq(stats.get_value(&"str"), gid.personal_base.get_value(&"str"), "Beginner class adds 0")
	assert_eq(stats.get_value(&"bld"), gid.personal_base.get_value(&"bld") + gid.class_data.build_bonus)
	assert_eq(stats.get_value(&"mov"), gid.class_data.mov)


func test_average_at_level_uses_combined_growths() -> void:
	var tellen: UnitData = load(DATA + "units/tellen.tres") as UnitData
	var at_11: StatBlock = UnitStats.average_at_level(tellen, ruleset, 11)
	var growths: StatBlock = ruleset.growth_rules.effective_growths(tellen.personal_growths, tellen.class_data)
	for stat_id: StringName in ruleset.growable_stat_ids():
		var expected: int = mini(tellen.personal_base.get_value(stat_id) + roundi(growths.get_value(stat_id) * 10 / 100.0),
			tellen.class_data.caps.get_value(stat_id))
		assert_eq(at_11.get_value(stat_id), expected, str(stat_id))


func test_average_at_level_respects_caps() -> void:
	var tellen: UnitData = load(DATA + "units/tellen.tres") as UnitData
	var at_cap: StatBlock = UnitStats.average_at_level(tellen, ruleset, ruleset.level_cap)
	assert_eq(at_cap.get_value(&"hp"), tellen.class_data.caps.get_value(&"hp"))


func test_generic_unit_gets_class_movement() -> void:
	var bulwark: ClassData = load(DATA + "classes/bulwark.tres") as ClassData
	var stats: StatBlock = UnitStats.generic(bulwark, ruleset, 5)
	assert_eq(stats.get_value(&"mov"), 4)
	assert_gt(stats.get_value(&"def"), bulwark.generic_base_stats.get_value(&"def"))


func test_tags_include_movement_and_class() -> void:
	var wingrider: ClassData = load(DATA + "classes/wingrider.tres") as ClassData
	var extra: Array[StringName] = [&"boss", &"sky"]
	assert_eq(UnitStats.tags_for(wingrider, extra), [&"sky", &"boss"] as Array[StringName])


func test_simulation_counts() -> void:
	var rules: CombatRules = ruleset.combat_rules
	var summary: CombatSimulation.Summary = CombatSimulation.run(rules, CombatFixtures.swordsman(), CombatFixtures.brigand(), 1, 500, 1)
	assert_eq(summary.combats, 500)
	# 92% hit → Stagger whenever the opening strike hits and the brigand survives (always: 24 HP vs 8)
	assert_almost_eq(summary.stagger_pct(), 92.0, 4.0)
	# Every combat either ends in a kill (a 1% crit on the opening strike deals 24)
	# or reaches the swordsman's follow-up; a follow-up never kills (8 + 12 < 24).
	assert_eq(summary.attacker_kills + summary.attacker_follow_ups, 500)
	assert_lt(summary.attacker_kills, 15, "kills only come from 1% crits")
	assert_eq(summary.defender_follow_up_pct(), 0.0)


func test_simulation_is_deterministic() -> void:
	var rules: CombatRules = ruleset.combat_rules
	var a: CombatSimulation.Summary = CombatSimulation.run(rules, CombatFixtures.rogue(), CombatFixtures.dark_mage(), 1, 200, 42)
	var b: CombatSimulation.Summary = CombatSimulation.run(rules, CombatFixtures.rogue(), CombatFixtures.dark_mage(), 1, 200, 42)
	assert_eq([a.attacker_kills, a.attacker_damage_total, a.defender_damage_total], [b.attacker_kills, b.attacker_damage_total, b.defender_damage_total])


func test_combat_lab_scene_builds() -> void:
	var lab: Control = (load("res://game/scenes/combat_lab.tscn") as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	await wait_process_frames(2)
	lab.call("_simulate")
	assert_gt(lab.get_child_count(), 0, "lab built its UI")
	lab.free()
