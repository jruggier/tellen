extends GutTest
## SaveMigrator: ordered steps, version stamping and rejection of bad data.


func _add_field(data: Dictionary) -> Dictionary:
	data["gold"] = 0
	return data


func _rename_field(data: Dictionary) -> Dictionary:
	data["coins"] = data["gold"]
	data.erase("gold")
	return data


func test_current_data_passes_through() -> void:
	var migrator := SaveMigrator.new(1)
	var result: Dictionary = migrator.migrate({"save_version": 1, "x": 5})
	assert_eq(result, {"save_version": 1, "x": 5})


func test_steps_apply_in_order() -> void:
	var migrator := SaveMigrator.new(3)
	migrator.register_step(2, _rename_field)
	migrator.register_step(1, _add_field)
	var result: Dictionary = migrator.migrate({"save_version": 1})
	assert_eq(result, {"save_version": 3, "coins": 0})


func test_missing_version_treated_as_one() -> void:
	var migrator := SaveMigrator.new(2)
	migrator.register_step(1, _add_field)
	assert_eq(migrator.migrate({}), {"save_version": 2, "gold": 0})


func test_input_is_not_modified() -> void:
	var migrator := SaveMigrator.new(2)
	migrator.register_step(1, _add_field)
	var original: Dictionary = {"save_version": 1}
	migrator.migrate(original)
	assert_eq(original, {"save_version": 1})


func test_newer_version_rejected() -> void:
	var migrator := SaveMigrator.new(1)
	assert_eq(migrator.migrate({"save_version": 2}), {})
	assert_push_warning_count(1)


func test_gap_in_steps_rejected() -> void:
	var migrator := SaveMigrator.new(3)
	migrator.register_step(1, _add_field)
	assert_eq(migrator.migrate({"save_version": 1}), {})
	assert_push_warning_count(1)


func test_default_version_matches_framework() -> void:
	assert_eq(SaveMigrator.new().get_current_version(), TacticsIds.SAVE_VERSION)
