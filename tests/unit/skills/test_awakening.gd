extends GutTest
## Awakening: both rules, stat/skill grants, signature attacks.

const DATA: String = "res://game/data/"


func _setup(rule: AwakeningRule) -> BattleState:
	var ruleset: Ruleset = BattleFixtures.ruleset().duplicate() as Ruleset
	ruleset.awakening_rule = rule
	var battle: BattleState = BattleFixtures.state(["....", "...."], ruleset)
	for unit_id: String in ["tellen", "sable"]:
		battle.add_unit(UnitState.from_unit_data(StringName(unit_id), load(DATA + "units/%s.tres" % unit_id) as UnitData, ruleset, &"player",
			Vector2i(0, 0) if unit_id == "tellen" else Vector2i(0, 1)))
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	TurnManager.start_battle(battle)
	return battle


func _round(battle: BattleState) -> void:
	TurnManager.end_phase(battle)
	TurnManager.end_phase(battle)


func test_cooldown_rule_lifecycle() -> void:
	var battle: BattleState = _setup(CooldownAwakeningRule.new())
	var tellen: UnitState = battle.get_unit(&"tellen")
	var str_before: int = tellen.effective_stats().get_value(&"str")
	var awaken := AwakenCommand.new(&"tellen")
	assert_true(awaken.can_execute(battle))
	awaken.execute(battle)
	assert_true(tellen.awakened)
	assert_true(tellen.is_ready(), "awakening is a free action")
	assert_eq(tellen.effective_stats().get_value(&"str"), str_before + 3)
	assert_eq(tellen.stats.get_value(&"str"), str_before, "base stats untouched")
	assert_true(SkillRunner.has_skill(tellen, &"vigil"), "awakened skill active")
	assert_false(AwakenCommand.new(&"tellen").can_execute(battle), "already awakened")
	_round(battle)
	_round(battle)
	assert_true(tellen.awakened, "turns 1-3 awakened")
	_round(battle)
	assert_false(tellen.awakened, "ends at the start of turn 4")
	assert_eq(tellen.awaken_cooldown, 3)
	assert_false(SkillRunner.has_skill(tellen, &"vigil"))
	_round(battle)
	_round(battle)
	_round(battle)
	assert_eq(tellen.awaken_cooldown, 0)
	assert_true(AwakenCommand.new(&"tellen").can_execute(battle))


func test_army_wide_use_limit() -> void:
	var rule := CooldownAwakeningRule.new()
	rule.max_uses_per_map = 1
	var battle: BattleState = _setup(rule)
	AwakenCommand.new(&"tellen").execute(battle)
	assert_false(AwakenCommand.new(&"sable").can_execute(battle), "army shares one use")
	rule.use_scope = CooldownAwakeningRule.UseScope.UNIT
	assert_true(AwakenCommand.new(&"sable").can_execute(battle), "per-unit scope")


func test_units_without_awakening_cannot() -> void:
	var battle: BattleState = _setup(CooldownAwakeningRule.new())
	assert_false(AwakenCommand.new(&"foe").can_execute(battle))


func test_action_charge_rule() -> void:
	var rule := ActionChargeAwakeningRule.new()
	var battle: BattleState = _setup(rule)
	var tellen: UnitState = battle.get_unit(&"tellen")
	assert_eq(tellen.awaken_charge, 3, "starts at start_charge")
	assert_false(AwakenCommand.new(&"tellen").can_execute(battle))
	rule.on_event(battle, tellen, AwakeningRule.EVENT_STAGGER)
	assert_eq(tellen.awaken_charge, 5)
	_round(battle)
	assert_eq(tellen.awaken_charge, 6, "+1 at own phase start; capped at max")
	AwakenCommand.new(&"tellen").execute(battle)
	assert_eq(tellen.awaken_charge, 0, "meter resets")
	assert_true(tellen.awakened)
	rule.on_event(battle, tellen, AwakeningRule.EVENT_KILL)
	assert_eq(tellen.awaken_charge, 0, "no charge while awakened")


func test_action_charge_forecast_gain() -> void:
	var rule := ActionChargeAwakeningRule.new()
	var rules: CombatRules = BattleFixtures.ruleset().combat_rules
	var forecast: CombatForecast = CombatForecast.calculate(rules, CombatFixtures.swordsman(), CombatFixtures.brigand(), 1)
	assert_eq(rule.forecast_gain(forecast), 2, "Stagger on hit")
	var weak: CombatParticipant = CombatFixtures.brigand()
	weak.current_hp = 5
	assert_eq(rule.forecast_gain(CombatForecast.calculate(rules, CombatFixtures.swordsman(), weak, 1)), 1, "kill (no Stagger on a kill)")


func test_attack_charges_meter() -> void:
	var rule := ActionChargeAwakeningRule.new()
	var battle: BattleState = _setup(rule)
	battle.rng = ScriptedRng.new([0, 99, 99, 99, 99, 99])
	var tellen: UnitState = battle.get_unit(&"tellen")
	AttackCommand.new(&"tellen", &"foe", 0).execute(battle)
	assert_eq(tellen.awaken_charge, 5, "sword hit staggered the axe: +2")


func test_signature_attack() -> void:
	var battle: BattleState = _setup(CooldownAwakeningRule.new())
	var tellen: UnitState = battle.get_unit(&"tellen")
	assert_false(SignatureAttackCommand.new(&"tellen", &"foe", 0).can_execute(battle), "not awakened")
	AwakenCommand.new(&"tellen").execute(battle)
	var normal: CombatForecast = CombatForecast.build(battle, tellen, battle.get_unit(&"foe"), tellen.cell)
	var participant: CombatParticipant = CombatContext.participant(battle, tellen, tellen.cell, tellen.equipped_weapon(), battle.get_unit(&"foe"), true)
	SignatureAttackCommand.apply_signature(tellen, participant)
	var foe_p: CombatParticipant = CombatContext.participant(battle, battle.get_unit(&"foe"), Vector2i(1, 0), battle.get_unit(&"foe").equipped_weapon(), tellen, false)
	var boosted: CombatForecast = CombatForecast.calculate(battle.ruleset.combat_rules, participant, foe_p, 1)
	assert_eq(boosted.attacker.damage, normal.attacker.damage + 8)
	assert_false(boosted.defender.can_strike, "Gambit Strike cannot be countered")
	battle.rng = ScriptedRng.new([0, 99, 99, 99])
	var signature := SignatureAttackCommand.new(&"tellen", &"foe", 0)
	assert_true(signature.can_execute(battle))
	signature.execute(battle)
	assert_true(tellen.signature_used)
	for strike: Strike in signature.result.strikes:
		assert_eq(strike.actor, Strike.Role.ATTACKER, "no counter strikes")
	tellen.has_acted = false
	assert_false(SignatureAttackCommand.new(&"tellen", &"foe", 0).can_execute(battle), "once per awakening")


func test_awakening_data_valid() -> void:
	for awakening_id: String in ["crossroads_pact", "moonlit_veil", "iron_resolve"]:
		var data: AwakeningData = load(DATA + "awakenings/%s.tres" % awakening_id) as AwakeningData
		assert_eq(data.validate().size(), 0, awakening_id)
