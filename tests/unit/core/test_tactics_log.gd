extends GutTest
## TacticsLog: level filtering and formatting.

var _saved_level: TacticsLog.Level


func before_each() -> void:
	_saved_level = TacticsLog.min_level


func after_each() -> void:
	TacticsLog.min_level = _saved_level


func test_format_line() -> void:
	assert_eq(TacticsLog.format_line(TacticsLog.Level.WARN, "Grid", "bad cell"), "[WARN][Grid] bad cell")


func test_min_level_filters_lower_levels() -> void:
	TacticsLog.min_level = TacticsLog.Level.WARN
	assert_false(TacticsLog.is_enabled(TacticsLog.Level.INFO))
	assert_true(TacticsLog.is_enabled(TacticsLog.Level.WARN))
	assert_true(TacticsLog.is_enabled(TacticsLog.Level.ERROR))


func test_none_is_never_enabled() -> void:
	TacticsLog.min_level = TacticsLog.Level.DEBUG
	assert_false(TacticsLog.is_enabled(TacticsLog.Level.NONE))


func test_warn_reaches_event_bus() -> void:
	watch_signals(TacticsEvents)
	TacticsLog.warn("Test", "hello")
	assert_signal_emitted_with_parameters(TacticsEvents, "log_emitted", [TacticsLog.Level.WARN, "[WARN][Test] hello"])
	assert_push_warning_count(1)
