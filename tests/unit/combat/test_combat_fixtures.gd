extends GutTest
## Spec §13.2 combat fixtures through CombatForecast, using the shipped
## weapon data and ruleset (1RN, crit ×3). These must pass exactly.

const WEAPONS: String = "res://game/data/weapons/"

var rules: CombatRules


func before_all() -> void:
	rules = (load("res://game/rules/crossroads_ruleset.tres") as Ruleset).combat_rules


func _unit(stats: Dictionary, weapon_id: String, movement_id: String = "") -> CombatParticipant:
	var movement: MovementType = null
	if not movement_id.is_empty():
		movement = load("res://game/data/movement_types/%s.tres" % movement_id) as MovementType
	return CombatFixtures.participant(stats, load(WEAPONS + weapon_id + ".tres") as WeaponData, movement)


func _side(side: CombatForecast.SideForecast, damage: int, hit: int, crit: int) -> void:
	assert_eq(side.damage, damage, "damage")
	assert_eq(side.hit, hit, "hit")
	assert_eq(side.crit, crit, "crit")


func test_early_swordsman_attacks_brigand() -> void:
	var swordsman: CombatParticipant = _unit({"hp": 22, "str": 7, "def": 5, "res": 2, "dex": 9, "spd": 9, "skl": 9, "bld": 6}, "iron_sword")
	var brigand: CombatParticipant = _unit({"hp": 24, "str": 8, "def": 4, "res": 0, "dex": 4, "spd": 4, "skl": 4, "bld": 10}, "iron_axe")
	var f: CombatForecast = CombatForecast.calculate(rules, swordsman, brigand, 1)
	_side(f.attacker, 8, 92, 1)
	assert_eq(f.attacker.follow_up_percent, 50)
	assert_eq(f.attacker.follow_up_damage, 4)
	_side(f.defender, 11, 53, 0)
	assert_eq(f.defender.follow_up_percent, 0)
	assert_true(f.stagger_on_hit, "sword staggers axe")
	assert_eq(f.defender.hp_after_all_hits, 24 - 8 - 4)
	assert_eq(f.attacker.hp_after_all_hits, 22 - 11)


func test_mid_rogue_attacks_dark_mage() -> void:
	var rogue: CombatParticipant = _unit({"hp": 30, "str": 11, "mag": 2, "def": 8, "res": 5, "dex": 14, "spd": 17, "skl": 13, "bld": 6}, "steel_knife")
	var mage: CombatParticipant = _unit({"hp": 27, "mag": 12, "def": 4, "res": 10, "dex": 10, "spd": 9, "skl": 8, "bld": 6}, "flux")
	var f: CombatForecast = CombatForecast.calculate(rules, rogue, mage, 1)
	_side(f.attacker, 14, 96, 12)
	assert_eq(f.attacker.crit_damage, 42)
	assert_eq(f.attacker.follow_up_percent, 50)
	assert_eq(f.attacker.follow_up_damage, 7)
	_side(f.defender, 15, 58, 0)
	assert_false(f.stagger_on_hit, "§5.5: tome staggers knife, not the reverse")


func test_late_swordmaster_attacks_general() -> void:
	var swordmaster: CombatParticipant = _unit({"hp": 48, "str": 24, "def": 16, "res": 12, "dex": 28, "spd": 32, "skl": 26, "bld": 9}, "killing_edge")
	var general: CombatParticipant = _unit({"hp": 60, "str": 28, "def": 30, "res": 12, "dex": 18, "spd": 10, "skl": 14, "bld": 14}, "silver_lance", "heavy")
	var f: CombatForecast = CombatForecast.calculate(rules, swordmaster, general, 1)
	_side(f.attacker, 3, 100, 35)
	assert_eq(f.attacker.follow_up_percent, 100)
	assert_eq(f.attacker.follow_up_damage, 3)
	_side(f.defender, 26, 40, 0)
	assert_false(f.stagger_on_hit, "heavy is immune")


func test_late_sage_attacks_general() -> void:
	var sage: CombatParticipant = _unit({"hp": 42, "mag": 26, "def": 12, "res": 22, "dex": 22, "spd": 18, "skl": 20, "bld": 7}, "bolt")
	var general: CombatParticipant = _unit({"hp": 60, "str": 28, "def": 30, "res": 12, "dex": 18, "spd": 10, "skl": 14, "bld": 14}, "silver_lance", "heavy")
	var f: CombatForecast = CombatForecast.calculate(rules, sage, general, 1)
	_side(f.attacker, 24, 100, 6)
	assert_eq(f.attacker.follow_up_percent, 60)
	assert_eq(f.attacker.follow_up_damage, 14)


func test_weight_fixture() -> void:
	var unit: CombatParticipant = _unit({"spd": 10, "skl": 10, "bld": 6}, "steel_sword")
	var crossroads: CrossroadsCombatRules = rules as CrossroadsCombatRules
	assert_eq(crossroads.weight_penalty(unit), 3)
	assert_eq(crossroads.effective_speed(unit), 7)
	assert_eq(crossroads.effective_skill_for_follow_ups(unit), 7)


func test_forecast_does_not_mutate_participants() -> void:
	var a: CombatParticipant = _unit({"hp": 22, "str": 7, "skl": 9}, "iron_sword")
	var d: CombatParticipant = _unit({"hp": 24, "str": 8, "skl": 4}, "iron_axe")
	var before: Array = [a.current_hp, d.current_hp, a.staggered, d.staggered, a.stats.to_dict(), d.stats.to_dict()]
	CombatForecast.calculate(rules, a, d, 1)
	assert_eq([a.current_hp, d.current_hp, a.staggered, d.staggered, a.stats.to_dict(), d.stats.to_dict()], before)
