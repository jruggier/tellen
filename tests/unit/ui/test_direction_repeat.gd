extends GutTest
## DirectionRepeat: one step per press, then a steady repeat after a hold.

var _down: Dictionary = {}


func _pressed(action: StringName) -> bool:
	return bool(_down.get(action, false))


## Steps produced by holding for [param seconds] at 60 fps.
func _hold(repeat: DirectionRepeat, seconds: float) -> int:
	var steps: int = 0
	var frames: int = roundi(seconds * 60.0)
	for i: int in frames:
		if repeat.poll(1.0 / 60.0, _pressed) != Vector2i.ZERO:
			steps += 1
	return steps


func before_each() -> void:
	_down.clear()


func test_tap_moves_once() -> void:
	var repeat := DirectionRepeat.new(0.5, 0.1)
	_down[&"cursor_down"] = true
	assert_eq(repeat.poll(1.0 / 60.0, _pressed), Vector2i.DOWN)
	assert_eq(_hold(repeat, 0.45), 0, "nothing more before the delay")
	_down.clear()
	repeat.poll(1.0 / 60.0, _pressed)
	_down[&"cursor_down"] = true
	assert_eq(repeat.poll(1.0 / 60.0, _pressed), Vector2i.DOWN, "a new press moves again")


func test_hold_repeats_at_the_interval() -> void:
	var repeat := DirectionRepeat.new(0.5, 0.1)
	_down[&"cursor_up"] = true
	var steps: int = _hold(repeat, 1.5)
	# 1 on press, then repeats at 0.5, 0.6, ... 1.4 → 10.
	assert_between(steps, 10, 12)


func test_keys_held_when_a_menu_opens_are_ignored_until_released() -> void:
	var repeat := DirectionRepeat.new(0.5, 0.1)
	_down[&"cursor_down"] = true
	repeat.reset(_pressed)
	assert_eq(_hold(repeat, 2.0), 0)
	_down.clear()
	repeat.poll(1.0 / 60.0, _pressed)
	_down[&"cursor_down"] = true
	assert_eq(repeat.poll(1.0 / 60.0, _pressed), Vector2i.DOWN)


func test_menu_scroll_setting() -> void:
	var settings := GameSettings.new()
	settings.menu_scroll = GameSettings.MenuScroll.SLOW
	assert_gt(settings.menu_repeat_delay(), 0.5)
	settings.menu_scroll = GameSettings.MenuScroll.FAST
	assert_lt(settings.menu_repeat_interval(), 0.1)
	assert_eq(GameSettings.new().menu_repeat_delay(), 0.5, "normal: half a second before scrolling")
