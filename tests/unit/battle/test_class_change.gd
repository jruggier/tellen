extends GutTest
## Class change: proficiency gates, class trees, stat swap, command.

const DATA: String = "res://game/data/"


func _tellen(battle: BattleState) -> UnitState:
	var tellen: UnitState = UnitState.from_unit_data(&"tellen", load(DATA + "units/tellen.tres") as UnitData, battle.ruleset, &"player", Vector2i(0, 0))
	battle.add_unit(tellen)
	return tellen


func _ids(classes: Array[ClassData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for class_data: ClassData in classes:
		ids.append(class_data.id)
	return ids


func test_requirements_gate_the_tree() -> void:
	var battle: BattleState = BattleFixtures.state([".."])
	var tellen: UnitState = _tellen(battle)
	assert_eq(ClassChangeRules.eligible_classes(battle, tellen).size(), 0, "Duelist needs sword 2; Tellen has 1")
	tellen.proficiencies[&"sword"] = 2
	assert_eq(_ids(ClassChangeRules.eligible_classes(battle, tellen)), [&"duelist"] as Array[StringName], "only classes in Tellen's tree")


func test_empty_tree_offers_any_qualifying_class_but_not_enemy_only() -> void:
	var battle: BattleState = BattleFixtures.state([".."])
	var recruit: UnitState = UnitState.from_unit_data(&"recruit", load(DATA + "units/recruit_hunter.tres") as UnitData, battle.ruleset, &"player", Vector2i(0, 0))
	battle.add_unit(recruit)
	var ids: Array[StringName] = _ids(ClassChangeRules.eligible_classes(battle, recruit))
	assert_true(ids.has(&"sellsword"), "Beginner classes have no requirements")
	assert_false(ids.has(&"hunter"), "not the current class")
	assert_false(ids.has(&"brigand"), "enemy-only")
	assert_false(ids.has(&"duelist"), "requirements unmet")


func test_generic_units_cannot_change() -> void:
	var battle: BattleState = BattleFixtures.state([".."])
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "sellsword", &"enemy", Vector2i(0, 0), ["iron_sword"])
	assert_eq(ClassChangeRules.eligible_classes(battle, foe).size(), 0)


func test_stats_swap_class_bonuses_and_keep_level() -> void:
	var battle: BattleState = BattleFixtures.state([".."])
	var tellen: UnitState = _tellen(battle)
	tellen.proficiencies[&"sword"] = 2
	tellen.level = 7
	tellen.current_hp -= 4
	var before: StatBlock = tellen.stats.copy()
	var duelist: ClassData = load(DATA + "classes/duelist.tres") as ClassData
	var delta: StatBlock = ClassChangeRules.apply(battle, tellen, duelist)
	assert_eq(tellen.level, 7, "one continuous level track")
	assert_eq(tellen.class_data, duelist)
	assert_eq(tellen.stats.get_value(&"str"), before.get_value(&"str") + 2, "Intermediate +2 offense")
	assert_eq(tellen.stats.get_value(&"def"), before.get_value(&"def") + 3, "Intermediate +3 defense")
	assert_eq(tellen.stats.get_value(&"mov"), 5)
	assert_eq(tellen.stats.get_value(&"bld"), before.get_value(&"bld") + duelist.build_bonus)
	assert_eq(tellen.current_hp, tellen.max_hp(battle.ruleset) - 4, "damage taken carries over")
	assert_eq(delta.get_value(&"hp"), 3)


func test_command() -> void:
	var battle: BattleState = BattleFixtures.state([".."])
	var tellen: UnitState = _tellen(battle)
	assert_false(ClassChangeCommand.new(&"tellen", &"duelist").can_execute(battle))
	tellen.proficiencies[&"sword"] = 2
	assert_false(ClassChangeCommand.new(&"tellen", &"warlock").can_execute(battle), "not in Tellen's tree")
	var command := ClassChangeCommand.new(&"tellen", &"duelist")
	assert_true(command.can_execute(battle))
	command.execute(battle)
	assert_eq(tellen.class_data.id, &"duelist")
	assert_true(tellen.has_acted, "ends the action")
	assert_true(tellen.can_equip(load(DATA + "weapons/iron_knife.tres") as WeaponData), "Duelists can use knives")
	assert_false(tellen.can_equip(load(DATA + "weapons/steel_knife.tres") as WeaponData), "but Steel needs knife proficiency 1")


func test_proficiency_overrides_in_placements() -> void:
	var map: BattleMap = (load("res://game/maps/test_arena.tscn") as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 1)
	var tellen: UnitState = controller.state.get_unit(&"tellen")
	assert_eq(tellen.proficiencies[&"sword"], 2, "arena Tellen can try Duelist")
	assert_eq(tellen.proficiency_points[&"sword"], 25)
