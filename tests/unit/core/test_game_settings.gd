extends GutTest
## GameSettings: persistence, audio buses, key remapping (spec §2a.5).

const TEST_PATH: String = "user://test_settings.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameSettings.new().apply()  # back to defaults for later tests


func test_defaults_when_file_missing() -> void:
	var settings: GameSettings = GameSettings.load_from("user://does_not_exist.cfg")
	assert_eq(settings.animation_speed, GameSettings.AnimationSpeed.NORMAL)
	assert_eq(settings.text_speed, 45.0)
	assert_eq(settings.master_volume, 80)


func test_save_and_load_round_trip() -> void:
	var settings := GameSettings.new()
	settings.animation_speed = GameSettings.AnimationSpeed.INSTANT
	settings.text_speed = 80.0
	settings.music_volume = 30
	settings.sfx_volume = 0
	settings.window_mode = GameSettings.WindowMode.FULLSCREEN
	settings.controller_layout = ControllerLayout.Mode.ALWAYS
	settings.colorblind_overlays = true
	settings.forecast_details = true
	settings.key_remaps[&"info"] = KEY_I
	assert_eq(settings.save(TEST_PATH), OK)
	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)
	assert_eq(loaded.animation_speed, GameSettings.AnimationSpeed.INSTANT)
	assert_eq(loaded.text_speed, 80.0)
	assert_eq(loaded.music_volume, 30)
	assert_eq(loaded.sfx_volume, 0)
	assert_eq(loaded.window_mode, GameSettings.WindowMode.FULLSCREEN)
	assert_eq(loaded.controller_layout, ControllerLayout.Mode.ALWAYS)
	assert_true(loaded.colorblind_overlays)
	assert_true(loaded.forecast_details)
	assert_eq(loaded.key_remaps.get(&"info", 0), KEY_I)


func test_out_of_range_values_are_clamped() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "master", 500)
	file.set_value("game", "animation_speed", 9)
	file.set_value("controls", "keys", {"not_an_action": KEY_K})
	file.save(TEST_PATH)
	var loaded: GameSettings = GameSettings.load_from(TEST_PATH)
	assert_eq(loaded.master_volume, 100)
	assert_eq(loaded.animation_speed, GameSettings.AnimationSpeed.INSTANT)
	assert_true(loaded.key_remaps.is_empty())


func test_animation_scale() -> void:
	var settings := GameSettings.new()
	assert_eq(settings.animation_scale(), 1.0)
	settings.animation_speed = GameSettings.AnimationSpeed.FAST
	assert_eq(settings.animation_scale(), 0.5)
	settings.animation_speed = GameSettings.AnimationSpeed.INSTANT
	assert_eq(settings.animation_scale(), 0.0)


func test_apply_creates_buses_and_sets_volume() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 50
	settings.sfx_volume = 0
	settings.apply()
	var music: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	var sfx: int = AudioServer.get_bus_index(GameSettings.SFX_BUS)
	assert_gt(music, 0)
	assert_gt(sfx, 0)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
	assert_true(AudioServer.is_bus_mute(sfx))


func test_remap_replaces_primary_key_and_keeps_others() -> void:
	var settings := GameSettings.new()
	settings.remap_key(&"confirm", KEY_J)
	settings.apply()
	assert_true(_has_key(&"confirm", KEY_J))
	assert_false(_has_key(&"confirm", KEY_Z), "old primary key removed")
	assert_true(_has_key(&"confirm", KEY_ENTER), "secondary keys stay")
	assert_eq(InputHints.key_name(&"confirm"), "J")


func test_remap_to_a_used_key_swaps() -> void:
	var settings := GameSettings.new()
	settings.remap_key(&"info", KEY_T)  # T is toggle_threat's key
	settings.apply()
	assert_true(_has_key(&"info", KEY_T))
	assert_true(_has_key(&"toggle_threat", KEY_R), "threat takes info's old key")
	assert_false(_has_key(&"toggle_threat", KEY_T))


func test_reset_restores_defaults() -> void:
	var settings := GameSettings.new()
	settings.remap_key(&"end_turn", KEY_G)
	settings.apply()
	settings.reset_keys()
	settings.apply()
	assert_true(_has_key(&"end_turn", KEY_F))
	assert_false(_has_key(&"end_turn", KEY_G))


func test_hints_follow_bindings() -> void:
	assert_eq(InputHints.fill("{info}: details, {nope} stays"), "R: details, {nope} stays")
	var settings := GameSettings.new()
	settings.remap_key(&"info", KEY_Y)
	settings.apply()
	assert_eq(InputHints.fill("{info}: details"), "Y: details")


func test_controller_layout_setting_overrides_project() -> void:
	var settings := GameSettings.new()
	settings.controller_layout = ControllerLayout.Mode.ALWAYS
	settings.apply()
	assert_true(ControllerLayout.nintendo_active)
	settings.controller_layout = ControllerLayout.Mode.NEVER
	settings.apply()
	assert_false(ControllerLayout.nintendo_active)


func test_settings_panel_changes_values() -> void:
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	var settings := GameSettings.new()
	panel.open(settings)
	panel.selected = panel.row_ids().find(&"animation_speed")
	panel.activate(1)
	assert_eq(settings.animation_speed, GameSettings.AnimationSpeed.FAST)
	panel.selected = panel.row_ids().find(&"music_volume")
	panel.activate(-1)
	assert_eq(settings.music_volume, 70)
	panel.selected = panel.row_ids().find(&"controls")
	panel.activate(0)
	assert_true(panel.row_ids().has(&"end_turn"), "controls page open")
	panel.selected = panel.row_ids().find(&"end_turn")
	panel.activate(0)
	assert_eq(panel.listening_action, &"end_turn")
	panel.bind_key(KEY_G)
	assert_eq(settings.primary_key(&"end_turn"), KEY_G)
	assert_eq(panel.listening_action, &"")


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false
