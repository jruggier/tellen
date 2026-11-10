extends GutTest
## The framework autoloads are registered and behave as documented.


func test_autoloads_exist() -> void:
	for autoload_name: String in ["TacticsEvents", "TacticsRng", "RulesetProvider", "SceneRouter"]:
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), "%s autoload missing" % autoload_name)


func test_default_ruleset_loaded() -> void:
	assert_true(RulesetProvider.has_ruleset())
	assert_eq(RulesetProvider.get_ruleset().ruleset_id, &"crossroads")
	assert_eq(RulesetProvider.get_ruleset().validate().size(), 0)


func test_set_ruleset_emits_event() -> void:
	var previous: Ruleset = RulesetProvider.get_ruleset()
	var other: Ruleset = previous.duplicate() as Ruleset
	other.ruleset_id = &"test"
	watch_signals(TacticsEvents)
	RulesetProvider.set_ruleset(other)
	assert_signal_emitted_with_parameters(TacticsEvents, "ruleset_changed", [other])
	assert_eq(RulesetProvider.get_ruleset(), other)
	RulesetProvider.set_ruleset(previous)


func test_invalid_ruleset_still_activates_with_warning() -> void:
	var previous: Ruleset = RulesetProvider.get_ruleset()
	var invalid: Ruleset = RulesetProvider.get_ruleset().duplicate() as Ruleset
	invalid.ruleset_id = &""
	RulesetProvider.set_ruleset(invalid)
	assert_eq(RulesetProvider.get_ruleset(), invalid, "activated despite problems")
	assert_push_warning_count(1)
	RulesetProvider.set_ruleset(previous)


func test_load_missing_ruleset_fails_gracefully() -> void:
	assert_false(RulesetProvider.load_ruleset("res://does/not/exist.tres"))
	assert_push_warning_count(1)


func test_tactics_rng_reseed_is_deterministic() -> void:
	var saved: SeededRng = TacticsRng.get_rng()
	TacticsRng.reseed(77)
	var first: int = TacticsRng.randi_range(TacticsIds.STREAM_COMBAT, 0, 1_000_000)
	TacticsRng.reseed(77)
	assert_eq(TacticsRng.randi_range(TacticsIds.STREAM_COMBAT, 0, 1_000_000), first)
	TacticsRng.set_rng(saved)


func test_scene_router_routes_and_params() -> void:
	SceneRouter.register_route(&"test_main", "res://game/scenes/main.tscn")
	assert_eq(SceneRouter.resolve(&"test_main"), "res://game/scenes/main.tscn")
	assert_eq(SceneRouter.resolve(&"nope"), "")
	assert_eq(SceneRouter.go_to_route(&"nope"), ERR_DOES_NOT_EXIST)
	assert_eq(SceneRouter.go_to("res://missing.tscn"), ERR_FILE_NOT_FOUND)
	assert_push_warning_count(2)
	assert_eq(SceneRouter.take_params(), {})


func test_project_display_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest: crisp pixel art")
	assert_eq(RulesetProvider.get_ruleset().cell_size(), 64, "16 px tiles at 4x")


func test_input_actions_defined() -> void:
	for action: String in ["confirm", "cancel", "menu", "info", "cursor_up", "cursor_down", "cursor_left",
			"cursor_right", "next_unit", "prev_unit", "toggle_threat", "end_turn", "speed_up", "debug_overlay"]:
		assert_true(InputMap.has_action(action), "missing input action %s" % action)
		assert_gt(InputMap.action_get_events(action).size(), 0, "no bindings for %s" % action)
