extends GutTest
## CombatResolver: §5.7 sequence, Stagger, follow-ups, kills and
## agreement with CombatForecast.

const ATTACKER: Strike.Role = Strike.Role.ATTACKER
const DEFENDER: Strike.Role = Strike.Role.DEFENDER

var rules: CrossroadsCombatRules


func before_each() -> void:
	rules = CrossroadsCombatRules.new()


func _rolls(values: Array[int]) -> ScriptedRng:
	return ScriptedRng.new(values)


func _kinds(result: CombatResult) -> Array[String]:
	var kinds: Array[String] = []
	for strike: Strike in result.strikes:
		kinds.append("%s:%s" % [Strike.Role.keys()[strike.actor], Strike.Kind.keys()[strike.kind]])
	return kinds


func _damages(result: CombatResult) -> Array[int]:
	var damages: Array[int] = []
	for strike: Strike in result.strikes:
		damages.append(strike.damage)
	return damages


func test_full_sequence_swordsman_vs_brigand() -> void:
	# rolls: atk hit(0) crit(99) | counter hit(10) crit(99) | follow-up hit(0) crit(99)
	var rng: ScriptedRng = _rolls([0, 99, 10, 99, 0, 99])
	var result: CombatResult = CombatResolver.resolve(rules, CombatFixtures.swordsman(), CombatFixtures.brigand(), 1, rng)
	assert_eq(_kinds(result), ["ATTACKER:INITIAL", "DEFENDER:COUNTER", "ATTACKER:FOLLOW_UP"] as Array[String])
	assert_eq(_damages(result), [8, 11, 4] as Array[int])
	assert_true(result.strikes[0].staggered, "sword hit staggers axe")
	assert_true(result.defender_staggered)
	assert_eq(result.defender_hp_after, 24 - 8 - 4)
	assert_eq(result.attacker_hp_after, 22 - 11)
	assert_eq(rng.remaining(), 0, "exactly 6 rolls consumed")


func test_miss_skips_crit_roll_and_stagger() -> void:
	# atk miss(99) | counter miss(99) | follow-up miss(99)
	var rng: ScriptedRng = _rolls([99, 99, 99])
	var result: CombatResult = CombatResolver.resolve(rules, CombatFixtures.swordsman(), CombatFixtures.brigand(), 1, rng)
	assert_eq(result.strikes.size(), 3)
	assert_false(result.defender_staggered, "no hit, no Stagger")
	assert_eq(rng.consumed.size(), 3, "no crit rolls after misses")
	assert_false(result.attacker_dealt_damage)


func test_crit_damage_and_follow_up_crit() -> void:
	# Rogue vs Dark Mage: atk hit crit(0,0) = 42 → mage dead
	var result: CombatResult = CombatResolver.resolve(rules, CombatFixtures.rogue(), CombatFixtures.dark_mage(), 1, _rolls([0, 0]))
	assert_true(result.strikes[0].crit)
	assert_eq(result.strikes[0].damage, 27, "capped at remaining HP (42 rolled)")
	assert_true(result.strikes[0].lethal)
	assert_eq(result.strikes.size(), 1, "kill ends combat")
	assert_true(result.defender_defeated())


func test_follow_up_crit_triples_follow_up_damage() -> void:
	var tank: CombatParticipant = CombatFixtures.brigand()
	tank.current_hp = 99
	# atk hit no-crit | counter miss | follow-up hit crit → floor(4 * 3) = 12
	var result: CombatResult = CombatResolver.resolve(rules, CombatFixtures.swordsman(), tank, 1, _rolls([0, 99, 99, 0, 0]))
	assert_eq(result.strikes[2].kind, Strike.Kind.FOLLOW_UP)
	assert_true(result.strikes[2].crit)
	assert_eq(result.strikes[2].damage, 12)


func _slow_lancer() -> CombatParticipant:
	return CombatFixtures.participant({"hp": 30, "str": 9, "def": 6, "dex": 8, "spd": 5, "skl": 3, "bld": 8}, CombatFixtures.iron_lance())


func _fast_swordsman() -> CombatParticipant:
	return CombatFixtures.participant({"hp": 30, "str": 7, "def": 5, "dex": 9, "spd": 9, "skl": 12, "bld": 6}, CombatFixtures.iron_sword())


func test_stagger_blocks_defender_follow_up_this_combat() -> void:
	# lancer hits (stagger), sword counters, sword would follow up (lead 9) but is Staggered
	var result: CombatResult = CombatResolver.resolve(rules, _slow_lancer(), _fast_swordsman(), 1, _rolls([0, 99, 0, 99]))
	assert_true(result.defender_staggered)
	assert_eq(_kinds(result), ["ATTACKER:INITIAL", "DEFENDER:COUNTER"] as Array[String], "counter still happens, follow-up does not")


func test_defender_follows_up_when_attacker_misses() -> void:
	var result: CombatResult = CombatResolver.resolve(rules, _slow_lancer(), _fast_swordsman(), 1, _rolls([99, 0, 99, 0, 99]))
	assert_false(result.defender_staggered)
	assert_eq(_kinds(result), ["ATTACKER:INITIAL", "DEFENDER:COUNTER", "DEFENDER:FOLLOW_UP"] as Array[String])


func test_carried_stagger_blocks_follow_up_but_not_counter() -> void:
	var sword: CombatParticipant = _fast_swordsman()
	sword.staggered = true
	var axe_user: CombatParticipant = CombatFixtures.participant({"hp": 30, "skl": 3}, CombatFixtures.iron_axe())
	# sword initiates while Staggered: it may not follow up despite the lead
	var as_attacker: CombatResult = CombatResolver.resolve(rules, sword, axe_user, 1, _rolls([99, 99]))
	assert_eq(_kinds(as_attacker), ["ATTACKER:INITIAL", "DEFENDER:COUNTER"] as Array[String])
	# Staggered defender still counters
	var as_defender: CombatResult = CombatResolver.resolve(rules, axe_user, sword, 1, _rolls([99, 99]))
	assert_eq(_kinds(as_defender), ["ATTACKER:INITIAL", "DEFENDER:COUNTER"] as Array[String])


func test_defender_cannot_stagger() -> void:
	# axe attacks sword: the sword's counter hits but defenders never inflict Stagger
	var axe_user: CombatParticipant = CombatFixtures.participant({"hp": 30, "skl": 3}, CombatFixtures.iron_axe())
	var result: CombatResult = CombatResolver.resolve(rules, axe_user, _fast_swordsman(), 1, _rolls([99, 0, 99, 99]))
	assert_false(result.defender_staggered)
	for strike: Strike in result.strikes:
		assert_false(strike.staggered)


func test_lethal_hit_does_not_stagger() -> void:
	var fragile: CombatParticipant = CombatFixtures.brigand()
	fragile.current_hp = 5
	var result: CombatResult = CombatResolver.resolve(rules, CombatFixtures.swordsman(), fragile, 1, _rolls([0, 99]))
	assert_true(result.defender_defeated())
	assert_false(result.defender_staggered, "Stagger requires the defender to survive")


func test_no_counter_out_of_range() -> void:
	var archer: CombatParticipant = CombatFixtures.participant({"hp": 20, "str": 6, "dex": 8, "skl": 6}, CombatFixtures.iron_bow())
	var result: CombatResult = CombatResolver.resolve(rules, archer, CombatFixtures.swordsman(), 2, _rolls([0, 99]))
	assert_eq(_kinds(result), ["ATTACKER:INITIAL"] as Array[String])


func test_brave_weapon_strikes_twice_each_turn() -> void:
	var brave: WeaponData = CombatFixtures.iron_sword()
	brave.brave = true
	var attacker: CombatParticipant = CombatFixtures.participant({"hp": 40, "str": 7, "dex": 9, "skl": 9, "bld": 6}, brave)
	var target: CombatParticipant = CombatFixtures.brigand()
	target.current_hp = 99
	var result: CombatResult = CombatResolver.resolve(rules, attacker, target, 1, _rolls([0, 99, 0, 99, 99, 0, 99, 0, 99]))
	assert_eq(_kinds(result), ["ATTACKER:INITIAL", "ATTACKER:INITIAL", "DEFENDER:COUNTER", "ATTACKER:FOLLOW_UP", "ATTACKER:FOLLOW_UP"] as Array[String])


func test_unarmed_attacker_does_nothing() -> void:
	var unarmed: CombatParticipant = CombatFixtures.participant({"hp": 20}, null)
	var result: CombatResult = CombatResolver.resolve(rules, unarmed, CombatFixtures.brigand(), 1, _rolls([0, 99]))
	assert_eq(_kinds(result), ["DEFENDER:COUNTER"] as Array[String])


func test_resolver_does_not_mutate_participants() -> void:
	var a: CombatParticipant = CombatFixtures.swordsman()
	var d: CombatParticipant = CombatFixtures.brigand()
	CombatResolver.resolve(rules, a, d, 1, _rolls([0, 0, 0, 0, 0, 0]))
	assert_eq([a.current_hp, d.current_hp, a.staggered, d.staggered], [22, 24, false, false])


func test_same_seed_same_result() -> void:
	var a: Dictionary = CombatResolver.resolve(rules, CombatFixtures.rogue(), CombatFixtures.dark_mage(), 1, SeededRng.new(9)).to_dict()
	var b: Dictionary = CombatResolver.resolve(rules, CombatFixtures.rogue(), CombatFixtures.dark_mage(), 1, SeededRng.new(9)).to_dict()
	assert_eq(a, b)


func test_resolver_matches_forecast_over_many_seeds() -> void:
	var pairs: Array = [
		[CombatFixtures.swordsman(), CombatFixtures.brigand()], [CombatFixtures.rogue(), CombatFixtures.dark_mage()],
		[CombatFixtures.swordmaster(), CombatFixtures.general()], [CombatFixtures.sage(), CombatFixtures.general()],
		[_slow_lancer(), _fast_swordsman()],
	]
	for pair: Array in pairs:
		var attacker: CombatParticipant = pair[0]
		var defender: CombatParticipant = pair[1]
		var forecast: CombatForecast = CombatForecast.calculate(rules, attacker, defender, 1)
		for seed: int in 400:
			var result: CombatResult = CombatResolver.resolve(rules, attacker, defender, 1, SeededRng.new(seed))
			for strike: Strike in result.strikes:
				var side: CombatForecast.SideForecast = forecast.attacker if strike.actor == ATTACKER else forecast.defender
				var hp_before: int = strike.target_hp_after + strike.damage
				var expected: int = side.follow_up_damage if strike.kind == Strike.Kind.FOLLOW_UP else side.damage
				if strike.crit:
					expected = rules.crit_damage(expected)
				if not strike.hit:
					expected = 0
				if strike.damage != mini(expected, hp_before):
					fail_test("seed %d: %s strike dealt %d, forecast says %d" % [seed, Strike.Kind.keys()[strike.kind], strike.damage, expected])
					return
				if strike.kind == Strike.Kind.FOLLOW_UP:
					assert_gt(side.follow_up_percent, 0, "follow-up only when forecast shows one")
			if result.defender_staggered and not forecast.stagger_on_hit:
				fail_test("Stagger not forecast")
				return
	pass_test("forecast and resolver agree")
