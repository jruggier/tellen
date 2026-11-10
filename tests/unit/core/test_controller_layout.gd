extends GutTest
## Nintendo vs standard confirm/cancel face buttons.


func after_each() -> void:
	ControllerLayout.refresh()


func _buttons(action: StringName) -> Array[int]:
	var result: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			result.append((event as InputEventJoypadButton).button_index)
	return result


func test_nintendo_layout_swaps_face_buttons() -> void:
	ControllerLayout.apply(true)
	assert_eq(_buttons(&"confirm"), [JOY_BUTTON_B] as Array[int], "A (right) confirms")
	assert_eq(_buttons(&"cancel"), [JOY_BUTTON_A] as Array[int], "B (bottom) cancels")
	ControllerLayout.apply(false)
	assert_eq(_buttons(&"confirm"), [JOY_BUTTON_A] as Array[int])
	assert_eq(_buttons(&"cancel"), [JOY_BUTTON_B] as Array[int])


func test_keyboard_and_mouse_untouched() -> void:
	var before: int = InputMap.action_get_events(&"confirm").size()
	ControllerLayout.apply(true)
	ControllerLayout.apply(true)
	assert_eq(InputMap.action_get_events(&"confirm").size(), before, "no duplicates; keys and mouse kept")


func test_name_detection() -> void:
	for joy_name: String in ["Nintendo Switch Pro Controller", "Joy-Con (L/R)", "Pro Controller"]:
		assert_true(ControllerLayout.is_nintendo_name(joy_name), joy_name)
	for joy_name: String in ["Xbox Wireless Controller", "DualSense Wireless Controller"]:
		assert_false(ControllerLayout.is_nintendo_name(joy_name), joy_name)
