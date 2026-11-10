class_name InputHints
extends RefCounted
## Fills control hints with the player's current key bindings, so hint
## text follows remapping. Translation strings write an action id in
## braces, e.g. "{info}: details", and [method fill] swaps in "R".


## The display name of [param action]'s first keyboard key ("?" if none).
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if key.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			return OS.get_keycode_string(code)
	return "?"


## [param text] with every {action_id} replaced by that action's key name.
static func fill(text: String) -> String:
	var result: String = text
	var start: int = result.find("{")
	while start != -1:
		var end: int = result.find("}", start)
		if end == -1:
			break
		var action := StringName(result.substr(start + 1, end - start - 1))
		if InputMap.has_action(action):
			var replacement: String = key_name(action)
			result = result.substr(0, start) + replacement + result.substr(end + 1)
			start = result.find("{", start + replacement.length())
		else:
			start = result.find("{", end + 1)
	return result
