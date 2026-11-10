extends GutTest
## The shipped Ruined Crossroads data is complete and valid (M1.3).

const DATA: String = "res://game/data/"

var ruleset: Ruleset


func before_all() -> void:
	ruleset = load("res://game/rules/crossroads_ruleset.tres") as Ruleset


func test_all_game_data_is_valid() -> void:
	var problems: PackedStringArray = DataValidator.validate_project(ruleset)
	assert_eq(problems.size(), 0, "\n".join(problems))


func test_catalog_contents() -> void:
	assert_eq(ruleset.stats.size(), 10, "8 growable + mov + bld")
	assert_eq(ruleset.growable_stat_ids(), [&"hp", &"str", &"mag", &"def", &"res", &"spd", &"skl", &"dex"] as Array[StringName])
	assert_eq(ruleset.movement_types.size(), 4)
	assert_eq(ruleset.weapon_types.size(), 8)
	assert_eq(ruleset.get_tier_name(1), "Intermediate")


func test_stagger_loops() -> void:
	var expected: Dictionary = {
		&"sword": [&"axe"], &"axe": [&"lance"], &"lance": [&"sword"],
		&"knife": [&"gauntlet"], &"gauntlet": [&"dark", &"white"], &"dark": [&"knife"], &"white": [&"knife"], &"bow": [],
	}
	for type_id: StringName in expected:
		var weapon_type: WeaponType = ruleset.get_weapon_type(type_id)
		assert_not_null(weapon_type, str(type_id))
		assert_eq(weapon_type.staggers, expected[type_id] as Array[StringName], str(type_id))
	assert_true(ruleset.get_weapon_type(&"bow").stagger_exempt)
	assert_true(ruleset.get_movement_type(&"heavy").stagger_immune)


func test_weapon_table_matches_spec() -> void:
	# id: [might, hit, crit, crit_evade, weight, range_min, range_max]
	var table: Dictionary = {
		"iron_sword": [5, 80, 0, 5, 5, 1, 1], "steel_sword": [8, 75, 0, 5, 9, 1, 1], "killing_edge": [9, 75, 30, 0, 7, 1, 1],
		"iron_lance": [6, 75, 0, 0, 7, 1, 1], "silver_lance": [14, 75, 0, 0, 10, 1, 1], "javelin": [5, 65, 0, 0, 9, 1, 2],
		"iron_axe": [8, 65, 0, 0, 10, 1, 1], "hand_axe": [6, 60, 0, 0, 11, 1, 2], "iron_knife": [4, 90, 5, 10, 2, 1, 2],
		"steel_knife": [7, 85, 10, 10, 4, 1, 2], "iron_gauntlets": [4, 85, 5, 5, 2, 1, 1], "iron_bow": [6, 80, 0, 0, 5, 2, 2],
		"flux": [8, 75, 0, 0, 6, 1, 2], "bolt": [10, 80, 5, 0, 7, 1, 2], "light": [5, 85, 0, 0, 3, 1, 2], "mend": [0, 0, 0, 0, 3, 1, 1],
	}
	for weapon_id: String in table:
		var weapon: WeaponData = load(DATA + "weapons/%s.tres" % weapon_id) as WeaponData
		var row: Array = table[weapon_id]
		assert_eq([weapon.might, weapon.hit, weapon.crit, weapon.crit_evade, weapon.weight, weapon.range_min, weapon.range_max], row, weapon_id)
	var mend: WeaponData = load(DATA + "weapons/mend.tres") as WeaponData
	assert_true(mend.heals)
	assert_eq(mend.heal_power, 10)
	assert_eq((load(DATA + "weapons/iron_bow.tres") as WeaponData).effective_against, [&"sky"] as Array[StringName])


func test_terrain_table_matches_spec() -> void:
	# id: [foot, ground, sky, heavy, avoid, def, heal]  (-1 = impassable)
	var table: Dictionary = {
		"plains": [1, 1, 1, 1, 0, 0, 0], "road": [1, 1, 1, 1, 0, 0, 0], "forest": [2, 3, 1, 2, 20, 0, 0],
		"ruins": [2, 3, 1, 3, 10, 1, 0], "hill": [2, 3, 1, 3, 10, 1, 0], "fort": [1, 1, 1, 1, 20, 2, 20],
		"water": [-1, -1, 1, -1, 0, 0, 0], "wall": [-1, -1, -1, -1, 0, 0, 0], "doorway": [1, -1, -1, 1, 0, 0, 0],
	}
	for terrain_id: String in table:
		var terrain: TerrainData = load(DATA + "terrain/%s.tres" % terrain_id) as TerrainData
		var actual: Array = [terrain.get_move_cost(&"foot"), terrain.get_move_cost(&"ground"), terrain.get_move_cost(&"sky"),
			terrain.get_move_cost(&"heavy"), terrain.avoid_bonus, terrain.defense_bonus, terrain.heal_percent]
		assert_eq(actual, table[terrain_id], terrain_id)


func test_beginner_classes() -> void:
	for class_id: String in ["sellsword", "spearhand", "hatchetman", "cutpurse", "brawler", "hexcaller", "acolyte", "hunter", "outrider", "wingrider", "bulwark"]:
		var class_data: ClassData = load(DATA + "classes/%s.tres" % class_id) as ClassData
		assert_eq(class_data.tier, 0, class_id)
		var mounted: bool = class_data.movement_type.id in [&"ground", &"sky"]
		assert_eq(class_data.mov, 5 if mounted else 4, class_id)
	var outrider: ClassData = load(DATA + "classes/outrider.tres") as ClassData
	assert_eq(outrider.abilities[0].id, &"canto", "ground classes have Canto")


func test_intermediate_classes_gated_by_proficiency() -> void:
	for class_id: String in ["duelist", "warlock", "vanguard"]:
		var class_data: ClassData = load(DATA + "classes/%s.tres" % class_id) as ClassData
		assert_eq(class_data.tier, 1, class_id)
		assert_false(class_data.requirements.is_empty(), class_id)


func test_units() -> void:
	var tellen: UnitData = load(DATA + "units/tellen.tres") as UnitData
	assert_true(tellen.is_lord)
	assert_eq(tellen.character.id, &"tellen")
	var lords: int = 0
	for unit_id: String in ["tellen", "sable", "gid", "recruit_spearhand", "recruit_acolyte", "recruit_hunter"]:
		var unit: UnitData = load(DATA + "units/%s.tres" % unit_id) as UnitData
		assert_not_null(unit, unit_id)
		if unit.is_lord:
			lords += 1
		var growth_total: int = 0
		for stat_id: StringName in ruleset.growable_stat_ids():
			growth_total += unit.personal_growths.get_value(stat_id)
		assert_between(growth_total, 240, 300, "%s growth budget" % unit_id)
	assert_eq(lords, 1)


func test_validator_catches_bad_unit() -> void:
	var unit := UnitData.new()
	unit.id = &"bad"
	unit.class_data = load(DATA + "classes/sellsword.tres") as ClassData
	unit.personal_base = StatBlock.from_values({"luck": 5})
	unit.personal_growths = StatBlock.new()
	unit.level = 99
	var inventory: Array[ItemData] = [load(DATA + "weapons/iron_axe.tres"), load(DATA + "weapons/killing_edge.tres")]
	unit.inventory = inventory
	unit.proficiencies = {&"swords": 1}
	var validator := DataValidator.new(ruleset)
	validator.check_resource(unit)
	# unknown stat luck, level above cap, unknown proficiency, axe unusable, killing edge needs proficiency 2
	assert_eq(validator.get_problems().size(), 5, "\n".join(validator.get_problems()))


func test_validator_catches_duplicate_ids() -> void:
	var validator := DataValidator.new(ruleset)
	var first: WeaponData = load(DATA + "weapons/iron_sword.tres") as WeaponData
	var copy: WeaponData = first.duplicate() as WeaponData
	copy.take_over_path("res://fake/other_sword.tres")
	validator.check_resource(first)
	validator.check_resource(copy)
	assert_eq(validator.get_problems().size(), 1, "\n".join(validator.get_problems()))


func test_strings_exist_for_data_keys() -> void:
	var unit: UnitData = load(DATA + "units/sable.tres") as UnitData
	assert_eq(unit.get_display_name(), "Sable")
	assert_eq((load(DATA + "stats/res.tres") as StatDefinition).get_abbreviation(), "Res")
	assert_eq((load(DATA + "classes/bulwark.tres") as ClassData).get_display_name(), "Bulwark")
