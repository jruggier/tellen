extends GutTest
## StatBlock math: defaults, sums, clamping, copies, serialization.


func test_missing_stat_reads_zero() -> void:
	var block := StatBlock.new()
	assert_eq(block.get_value(&"spd"), 0)
	assert_false(block.has_stat(&"spd"))


func test_from_values_accepts_string_keys() -> void:
	var block := StatBlock.from_values({"hp": 20, &"str": 6})
	assert_eq(block.get_value(&"hp"), 20)
	assert_eq(block.get_value(&"str"), 6)


func test_plus_sums_and_does_not_modify_inputs() -> void:
	var personal := StatBlock.from_values({"hp": 20, "str": 6})
	var class_bonus := StatBlock.from_values({"str": 2, "def": 3})
	var total: StatBlock = personal.plus(class_bonus)
	assert_true(total.equals(StatBlock.from_values({"hp": 20, "str": 8, "def": 3})), str(total))
	assert_true(personal.equals(StatBlock.from_values({"hp": 20, "str": 6})))
	assert_true(class_bonus.equals(StatBlock.from_values({"str": 2, "def": 3})))


func test_add_in_place_ignores_null() -> void:
	var block := StatBlock.from_values({"hp": 1})
	block.add_in_place(null)
	assert_eq(block.get_value(&"hp"), 1)


func test_clamped_to_caps_and_floor() -> void:
	var block := StatBlock.from_values({"hp": 70, "str": -2, "spd": 30})
	var caps := StatBlock.from_values({"hp": 60, "spd": 40})
	var result: StatBlock = block.clamped(caps)
	assert_eq(result.get_value(&"hp"), 60, "capped")
	assert_eq(result.get_value(&"str"), 0, "floored; no cap defined")
	assert_eq(result.get_value(&"spd"), 30, "under cap")
	assert_eq(block.get_value(&"hp"), 70, "input unchanged")


func test_copy_is_independent() -> void:
	var block := StatBlock.from_values({"hp": 5})
	var copy: StatBlock = block.copy()
	copy.set_value(&"hp", 9)
	assert_eq(block.get_value(&"hp"), 5)


func test_equals_treats_missing_as_zero() -> void:
	assert_true(StatBlock.from_values({"hp": 5, "mag": 0}).equals(StatBlock.from_values({"hp": 5})))
	assert_false(StatBlock.from_values({"hp": 5}).equals(StatBlock.from_values({"hp": 6})))
	assert_false(StatBlock.new().equals(null))


func test_to_dict_is_json_safe_and_sorted() -> void:
	var block := StatBlock.from_values({"str": 6, "hp": 20})
	assert_eq(JSON.stringify(block.to_dict()), '{"hp":20,"str":6}')
	assert_eq(str(block), "{hp: 20, str: 6}")


func test_saves_and_loads_as_resource() -> void:
	var path: String = "user://test_stat_block.tres"
	var block := StatBlock.from_values({"hp": 20, "spd": 6})
	assert_eq(ResourceSaver.save(block, path), OK)
	var loaded: StatBlock = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as StatBlock
	assert_not_null(loaded)
	assert_true(loaded.equals(block), str(loaded))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
