extends GutTest
## Framework data resources: helpers and validation rules.


func _weapon_type(type_id: StringName, staggers: Array[StringName] = [], exempt: bool = false) -> WeaponType:
	var weapon_type := WeaponType.new()
	weapon_type.id = type_id
	weapon_type.staggers = staggers
	weapon_type.stagger_exempt = exempt
	return weapon_type


func test_missing_id_is_reported() -> void:
	var problems: PackedStringArray = StatDefinition.new().validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "missing id")
	assert_string_contains(problems[0], "StatDefinition")


func test_display_name_falls_back_to_id() -> void:
	var stat := StatDefinition.new()
	stat.id = &"spd"
	assert_eq(stat.get_display_name(), "spd")
	assert_eq(stat.get_abbreviation(), "spd")


func test_weapon_type_stagger_links() -> void:
	var sword: WeaponType = _weapon_type(&"sword", [&"axe"])
	var axe: WeaponType = _weapon_type(&"axe", [&"lance"])
	var bow: WeaponType = _weapon_type(&"bow", [], true)
	assert_true(sword.staggers_type(axe))
	assert_false(axe.staggers_type(sword))
	assert_false(sword.staggers_type(bow), "bows cannot be staggered")
	assert_false(bow.staggers_type(sword), "bows cannot stagger")
	assert_false(sword.staggers_type(null))


func test_weapon_type_validation() -> void:
	assert_eq(_weapon_type(&"bow", [&"sword"], true).validate().size(), 1)
	assert_eq(_weapon_type(&"sword", [&"sword"]).validate().size(), 1)
	assert_eq(_weapon_type(&"sword", [&"axe"]).validate().size(), 0)


func test_terrain_costs() -> void:
	var forest := TerrainData.new()
	forest.id = &"forest"
	forest.move_costs = {&"foot": 2, &"sky": 1}
	assert_eq(forest.get_move_cost(&"foot"), 2)
	assert_eq(forest.get_move_cost(&"heavy"), -1)
	assert_false(forest.is_passable_for(&"heavy"))
	assert_eq(forest.validate().size(), 0)
	forest.move_costs[&"ground"] = 0
	assert_eq(forest.validate().size(), 1)


func test_weapon_range_and_effectiveness() -> void:
	var javelin := WeaponData.new()
	javelin.id = &"javelin"
	javelin.weapon_type = _weapon_type(&"lance")
	javelin.range_min = 1
	javelin.range_max = 2
	javelin.effective_against = [&"sky"]
	assert_false(javelin.is_in_range(0))
	assert_true(javelin.is_in_range(1))
	assert_true(javelin.is_in_range(2))
	assert_false(javelin.is_in_range(3))
	var tags: Array[StringName] = [&"sky", &"foot"]
	assert_true(javelin.is_effective_against(tags))
	var no_tags: Array[StringName] = [&"foot"]
	assert_false(javelin.is_effective_against(no_tags))
	assert_eq(javelin.validate().size(), 0)


func test_weapon_validation() -> void:
	var weapon := WeaponData.new()
	weapon.id = &"broken"
	weapon.range_min = 3
	weapon.range_max = 1
	weapon.heals = true
	weapon.weight = -1
	# no weapon_type, bad range, heals without power, negative weight
	assert_eq(weapon.validate().size(), 4, str(weapon.validate()))


func test_consumable_needs_an_effect() -> void:
	var item := ConsumableData.new()
	item.id = &"nothing"
	assert_eq(item.validate().size(), 1)
	item.heal_amount = 10
	assert_eq(item.validate().size(), 0)
	var booster := ConsumableData.new()
	booster.id = &"booster"
	booster.permanent_boosts = StatBlock.from_values({"str": 2})
	assert_eq(booster.validate().size(), 0)


func test_class_weapon_permissions_and_requirements() -> void:
	var class_data := ClassData.new()
	class_data.id = &"sellsword"
	class_data.usable_weapon_types = [_weapon_type(&"sword")]
	class_data.primary_proficiency = &"sword"
	class_data.secondary_proficiencies = [&"foot", &"sword"]
	class_data.requirements = {&"sword": 3}
	assert_true(class_data.can_use_weapon_type(_weapon_type(&"sword")))
	assert_false(class_data.can_use_weapon_type(_weapon_type(&"axe")))
	assert_eq(class_data.trained_proficiencies(), [&"sword", &"foot"] as Array[StringName])
	assert_false(class_data.requirements_met({&"sword": 2}))
	assert_true(class_data.requirements_met({&"sword": 3, &"axe": 1}))
	# no movement type, no caps
	assert_eq(class_data.validate().size(), 2)


func test_unit_validation() -> void:
	var unit := UnitData.new()
	unit.id = &"tellen"
	assert_eq(unit.validate().size(), 3, "class, base and growths missing")


func test_character_portrait_fallback() -> void:
	var character := CharacterData.new()
	var neutral := PlaceholderTexture2D.new()
	character.portraits = {&"neutral": neutral}
	assert_eq(character.get_portrait(&"angry"), neutral)
	assert_null(CharacterData.new().get_portrait(&"neutral"))


func test_faction_alliances() -> void:
	var player := FactionData.new()
	player.id = &"player"
	player.allied_with = [&"ally"]
	assert_true(player.is_allied_with(&"player"))
	assert_true(player.is_allied_with(&"ally"))
	assert_false(player.is_allied_with(&"enemy"))


func test_class_resource_round_trip() -> void:
	var path: String = "user://test_class_data.tres"
	var class_data := ClassData.new()
	class_data.id = &"spearhand"
	class_data.caps = StatBlock.from_values({"hp": 60})
	class_data.requirements = {&"lance": 2}
	assert_eq(ResourceSaver.save(class_data, path), OK)
	var loaded: ClassData = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ClassData
	assert_not_null(loaded)
	assert_eq(loaded.id, &"spearhand")
	assert_eq(loaded.caps.get_value(&"hp"), 60)
	assert_eq(loaded.requirements.get(&"lance"), 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
