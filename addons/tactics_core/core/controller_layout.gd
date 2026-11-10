class_name ControllerLayout
extends RefCounted
## Gamepad confirm/cancel layout.
##
## Godot names face buttons by position (A = bottom, B = right). Xbox and
## PlayStation pads confirm with the bottom button; Nintendo pads confirm
## with A, which sits on the right. With the Nintendo layout active,
## [code]confirm[/code] uses the right face button and [code]cancel[/code]
## the bottom one.
##
## The project setting [code]tactics_core/input/nintendo_layout[/code] picks
## AUTO (default: on whenever a Nintendo controller is connected), ALWAYS or
## NEVER. Applied at startup and whenever a controller connects or
## disconnects (wired up by the [code]TacticsEvents[/code] autoload).

enum Mode { AUTO, ALWAYS, NEVER }

const SETTING_MODE: String = "tactics_core/input/nintendo_layout"
const CONFIRM: StringName = &"confirm"
const CANCEL: StringName = &"cancel"
const NINTENDO_NAMES: PackedStringArray = ["nintendo", "switch", "joy-con", "joycon", "pro controller"]

## Layout currently applied.
static var nintendo_active: bool = false


## Applies the layout chosen by the project setting and connected pads.
static func refresh() -> void:
	var mode: int = int(ProjectSettings.get_setting(SETTING_MODE, Mode.AUTO))
	match mode:
		Mode.ALWAYS:
			apply(true)
		Mode.NEVER:
			apply(false)
		_:
			apply(any_nintendo_connected())


## True if a connected controller reports a Nintendo name.
static func any_nintendo_connected() -> bool:
	for device: int in Input.get_connected_joypads():
		if is_nintendo_name(Input.get_joy_name(device)):
			return true
	return false


static func is_nintendo_name(joy_name: String) -> bool:
	var lowered: String = joy_name.to_lower()
	for marker: String in NINTENDO_NAMES:
		if lowered.contains(marker):
			return true
	return false


## Puts confirm on the right face button (Nintendo) or the bottom one.
static func apply(nintendo: bool) -> void:
	nintendo_active = nintendo
	_set_face_button(CONFIRM, JOY_BUTTON_B if nintendo else JOY_BUTTON_A)
	_set_face_button(CANCEL, JOY_BUTTON_A if nintendo else JOY_BUTTON_B)


static func _set_face_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
			InputMap.action_erase_event(action, event)
	var replacement := InputEventJoypadButton.new()
	replacement.button_index = button
	InputMap.action_add_event(action, replacement)
