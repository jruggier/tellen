extends GutTest
## Skill hooks: active skill sources, auras, conditional bonuses, Vantage,
## heal on kill, Canto, and skill data validation.

const DATA: String = "res://game/data/"


func _named(battle: BattleState, unit_id: String, faction: StringName, cell: Vector2i) -> UnitState:
	var unit: UnitState = UnitState.from_unit_data(StringName(unit_id), load(DATA + "units/%s.tres" % unit_id) as UnitData, battle.ruleset, faction, cell)
	battle.add_unit(unit)
	return unit


func test_active_skills_combine_sources() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	assert_true(SkillRunner.has_skill(tellen, &"second_wind"), "equipped skill")
	var armor: UnitState = BattleFixtures.add(battle, &"armor", "bulwark", &"player", Vector2i(1, 0), ["iron_lance"])
	assert_true(SkillRunner.has_skill(armor, &"shield_wall"), "class ability")
	var rider: UnitState = BattleFixtures.add(battle, &"rider", "outrider", &"player", Vector2i(2, 0), ["javelin"])
	assert_true(SkillRunner.has_canto(battle, rider))
	assert_false(SkillRunner.has_canto(battle, tellen))


func test_shield_wall_aura() -> void:
	var battle: BattleState = BattleFixtures.state([".....", "....."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(1, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(2, 0), ["iron_axe"])
	var before: int = CombatForecast.build(battle, foe, tellen, foe.cell).attacker.damage
	BattleFixtures.add(battle, &"armor", "bulwark", &"player", Vector2i(1, 1), ["iron_lance"])
	assert_eq(CombatForecast.build(battle, foe, tellen, foe.cell).attacker.damage, maxi(0, before - 2), "adjacent Bulwark: +2 Def")
	battle.move_unit(&"armor", Vector2i(0, 1))
	assert_eq(CombatForecast.build(battle, foe, tellen, foe.cell).attacker.damage, before, "2 tiles away: no aura")


func test_aura_uses_hypothetical_destination() -> void:
	var battle: BattleState = BattleFixtures.state([".....", "....."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(4, 0), ["iron_axe"])
	BattleFixtures.add(battle, &"armor", "bulwark", &"player", Vector2i(3, 1), ["iron_lance"])
	var far: CombatParticipant = CombatContext.participant(battle, tellen, Vector2i(0, 0), tellen.equipped_weapon(), foe, true)
	var near: CombatParticipant = CombatContext.participant(battle, tellen, Vector2i(3, 0), tellen.equipped_weapon(), foe, true)
	assert_eq(far.modifier(CombatParticipant.MOD_DEFENSE), 0)
	assert_eq(near.modifier(CombatParticipant.MOD_DEFENSE), 2, "attacking from next to the Bulwark")
	assert_eq(tellen.cell, Vector2i(0, 0), "state untouched")


func test_fleetfoot_at_low_hp() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var sable: UnitState = _named(battle, "sable", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	var healthy_hit: int = CombatForecast.build(battle, foe, sable, foe.cell).attacker.hit
	sable.current_hp = sable.max_hp(battle.ruleset) / 2
	assert_eq(CombatForecast.build(battle, foe, sable, foe.cell).attacker.hit, maxi(0, healthy_hit - 20))


func test_vigil_strikes_first_on_enemy_phase_only() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	battle.phase_index = 1
	var spear: UnitState = _named(battle, "recruit_spearhand", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	foe.current_hp = 99
	assert_true(CombatForecast.build(battle, foe, spear, foe.cell).defender_strikes_first)
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	var attack := AttackCommand.new(&"foe", &"recruit_spearhand", 0)
	attack.execute(battle)
	assert_eq(attack.result.strikes[0].actor, Strike.Role.DEFENDER, "Vigil: the defender strikes first")
	assert_eq(attack.result.strikes[1].actor, Strike.Role.ATTACKER)
	battle.phase_index = 0
	spear.has_acted = false
	assert_false(CombatForecast.build(battle, spear, foe, spear.cell).defender_strikes_first, "never when attacking")


func test_vantage_forecast_matches_resolver_order() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	battle.phase_index = 1
	var spear: UnitState = _named(battle, "recruit_spearhand", &"player", Vector2i(0, 0))
	spear.stats.set_value(&"str", 40)
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	var forecast: CombatForecast = CombatForecast.build(battle, foe, spear, foe.cell)
	assert_eq(forecast.attacker.hp_after_all_hits, 0, "Vigil kills before the brigand swings")
	assert_eq(forecast.defender.hp_after_all_hits, spear.current_hp, "so the spearhand takes nothing")


func test_second_wind_heals_on_kill() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	battle.rng = ScriptedRng.new([0, 99])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.current_hp = 5
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	foe.current_hp = 1
	var attack := AttackCommand.new(&"tellen", &"foe", 0)
	attack.execute(battle)
	var heal: int = maxi(1, floori(tellen.max_hp(battle.ruleset) * 0.2))
	assert_eq(tellen.current_hp, 5 + heal)
	assert_eq(attack.skill_effects.size(), 1)
	assert_eq(attack.skill_effects[0]["heal"], heal)


func test_canto_after_acting() -> void:
	var battle: BattleState = BattleFixtures.state(["........", "........"])
	var rider: UnitState = BattleFixtures.add(battle, &"rider", "outrider", &"player", Vector2i(0, 0), ["iron_lance"])
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(3, 1), ["iron_axe"])
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	MoveCommand.new(&"rider", Vector2i(2, 1)).execute(battle)
	assert_eq(rider.moved_cost, 3)
	assert_eq(CantoMoveCommand.remaining(battle, rider), 0, "must act first")
	AttackCommand.new(&"rider", &"foe", 0).execute(battle)
	assert_eq(CantoMoveCommand.remaining(battle, rider), 2, "5 mov - 3 spent")
	assert_false(CantoMoveCommand.new(&"rider", Vector2i(5, 1)).can_execute(battle), "3 tiles away is too far")
	var canto := CantoMoveCommand.new(&"rider", Vector2i(1, 0))
	assert_true(canto.can_execute(battle))
	canto.execute(battle)
	assert_eq(rider.cell, Vector2i(1, 0))
	assert_eq(CantoMoveCommand.remaining(battle, rider), 0, "once per phase")


func test_units_without_canto_cannot() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.has_acted = true
	assert_eq(CantoMoveCommand.remaining(battle, tellen), 0)


func test_skill_validation() -> void:
	var skill := SkillData.new()
	skill.id = &"broken"
	skill.hooks_script = load("res://addons/tactics_core/core/tactics_log.gd") as Script
	assert_eq(skill.validate().size(), 1)
	skill.hooks_script = load("res://game/skills/canto_hooks.gd") as Script
	assert_eq(skill.validate().size(), 0)
