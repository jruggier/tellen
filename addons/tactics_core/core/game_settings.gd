class_name GameSettings
extends RefCounted
## Player settings saved to [code]user://settings.cfg[/code] (spec §2a.5):
## animation and text speed, volumes, window mode, controller layout,
## colorblind-safe overlays, forecast detail and keyboard remapping.
##
## [method current] loads the file once and applies it; the
## [code]TacticsEvents[/code] autoload calls it at startup so every scene
## (including maps run with F6) starts with the player's settings. After
## changing values call [method apply] and [method save]. Listeners update
## through [signal TacticsEvents.settings_changed].

enum AnimationSpeed { NORMAL, FAST, INSTANT }
enum WindowMode { WINDOWED, FULLSCREEN }

const PATH: String = "user://settings.cfg"
## Settings file version (for future migrations).
const VERSION: int = 1
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Actions the player may rebind (keyboard). Gamepad confirm/cancel follow
## [member controller_layout] instead.
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"confirm", &"cancel", &"menu", &"info", &"cursor_up", &"cursor_down", &"cursor_left",
	&"cursor_right", &"next_unit", &"prev_unit", &"toggle_threat", &"end_turn", &"speed_up",
]
## Text speeds offered, in characters per second (0 = instant).
const TEXT_SPEEDS: Array[float] = [25.0, 45.0, 80.0, 0.0]

var animation_speed: AnimationSpeed = AnimationSpeed.NORMAL
## Dialogue characters per second (0 = whole line at once).
var text_speed: float = 45.0
## Volumes 0–100.
var master_volume: int = 80
var music_volume: int = 80
var sfx_volume: int = 80
var window_mode: WindowMode = WindowMode.WINDOWED
## [enum ControllerLayout.Mode]: AUTO, ALWAYS (Nintendo), NEVER (standard).
var controller_layout: int = ControllerLayout.Mode.AUTO
## Range overlays use a colorblind-safe palette (patterns are always on).
var colorblind_overlays: bool = false
## The combat forecast opens with details shown.
var forecast_details: bool = false
## Action → physical keycode replacing that action's primary key.
var key_remaps: Dictionary[StringName, int] = {}

static var _current: GameSettings = null
## Each remappable action's key events before any remap (to reset or re-apply).
static var _default_keys: Dictionary = {}


## The active settings, loaded from disk (and applied) on first use.
static func current() -> GameSettings:
	if _current == null:
		_current = load_from(PATH)
		_current.apply()
	return _current


## Reads [param path]; missing or unreadable files give the defaults.
static func load_from(path: String) -> GameSettings:
	var settings := GameSettings.new()
	var file := ConfigFile.new()
	if not FileAccess.file_exists(path):
		return settings
	if file.load(path) != OK:
		TacticsLog.warn("Settings", "Cannot read %s; using defaults" % path)
		return settings
	settings.animation_speed = clampi(int(file.get_value("game", "animation_speed", 0)), 0, AnimationSpeed.size() - 1) as AnimationSpeed
	settings.text_speed = maxf(0.0, float(file.get_value("game", "text_speed", 45.0)))
	settings.forecast_details = bool(file.get_value("game", "forecast_details", false))
	settings.master_volume = clampi(int(file.get_value("audio", "master", 80)), 0, 100)
	settings.music_volume = clampi(int(file.get_value("audio", "music", 80)), 0, 100)
	settings.sfx_volume = clampi(int(file.get_value("audio", "sfx", 80)), 0, 100)
	settings.window_mode = clampi(int(file.get_value("display", "window_mode", 0)), 0, WindowMode.size() - 1) as WindowMode
	settings.colorblind_overlays = bool(file.get_value("display", "colorblind_overlays", false))
	settings.controller_layout = clampi(int(file.get_value("controls", "controller_layout", 0)), 0, 2)
	var remaps: Variant = file.get_value("controls", "keys", {})
	if remaps is Dictionary:
		for action: Variant in remaps:
			var action_id := StringName(str(action))
			if REMAPPABLE_ACTIONS.has(action_id):
				settings.key_remaps[action_id] = int(remaps[action])
	return settings


## Writes the settings to [param path] ([constant PATH] by default).
func save(path: String = PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	file.set_value("game", "animation_speed", int(animation_speed))
	file.set_value("game", "text_speed", text_speed)
	file.set_value("game", "forecast_details", forecast_details)
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("display", "window_mode", int(window_mode))
	file.set_value("display", "colorblind_overlays", colorblind_overlays)
	file.set_value("controls", "controller_layout", controller_layout)
	var remaps: Dictionary = {}
	for action: StringName in key_remaps:
		remaps[String(action)] = key_remaps[action]
	file.set_value("controls", "keys", remaps)
	var result: Error = file.save(path)
	if result != OK:
		TacticsLog.warn("Settings", "Cannot save %s (%d)" % [path, result])
	return result


## Pushes the settings to the engine (audio buses, window, input map,
## controller layout) and tells listeners.
func apply() -> void:
	_current = self
	_apply_audio()
	_apply_window()
	_apply_keys()
	ControllerLayout.mode_override = controller_layout
	ControllerLayout.refresh()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node(^"TacticsEvents"):
		tree.root.get_node(^"TacticsEvents").emit_signal(&"settings_changed")


## Multiplier for presentation timings: 1 normal, 0.5 fast, 0 instant.
func animation_scale() -> float:
	match animation_speed:
		AnimationSpeed.FAST:
			return 0.5
		AnimationSpeed.INSTANT:
			return 0.0
	return 1.0


## The key bound as [param action]'s primary key (physical keycode), or 0.
func primary_key(action: StringName) -> int:
	if key_remaps.has(action):
		return key_remaps[action]
	_capture_default_keys()
	var defaults: Array = _default_keys.get(action, [])
	return (defaults[0] as InputEventKey).physical_keycode if not defaults.is_empty() else 0


## Rebinds [param action]'s primary key. If another action already uses
## [param physical_keycode] as its primary key, the two swap.
func remap_key(action: StringName, physical_keycode: int) -> void:
	var previous: int = primary_key(action)
	for other: StringName in REMAPPABLE_ACTIONS:
		if other != action and primary_key(other) == physical_keycode:
			key_remaps[other] = previous
	key_remaps[action] = physical_keycode


func reset_keys() -> void:
	key_remaps.clear()


## Volume 0–100 → decibels (0 is silent).
static func volume_db(volume: int) -> float:
	return linear_to_db(clampi(volume, 0, 100) / 100.0) if volume > 0 else -80.0


func _apply_audio() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_set_bus(&"Master", master_volume)
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")


static func _set_bus(bus_name: StringName, volume: int) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, volume_db(volume))
		AudioServer.set_bus_mute(index, volume <= 0)


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless" or Engine.is_editor_hint():
		return
	var wanted: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if window_mode == WindowMode.FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)


## Replaces each remapped action's primary key, keeping its other keys,
## gamepad and mouse bindings.
func _apply_keys() -> void:
	_capture_default_keys()
	for action: StringName in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var keys: Array = (_default_keys.get(action, []) as Array).duplicate()
		if key_remaps.has(action):
			var replacement := InputEventKey.new()
			replacement.physical_keycode = key_remaps[action] as Key
			if keys.is_empty():
				keys.append(replacement)
			else:
				keys[0] = replacement
		for key: InputEventKey in keys:
			if key.physical_keycode == 0 or _key_used_elsewhere(action, key.physical_keycode, keys[0] == key):
				continue
			InputMap.action_add_event(action, key)


## A secondary key is dropped when another action now uses it as its primary.
func _key_used_elsewhere(action: StringName, physical_keycode: int, is_primary: bool) -> bool:
	if is_primary:
		return false
	for other: StringName in REMAPPABLE_ACTIONS:
		if other != action and primary_key(other) == physical_keycode:
			return true
	return false


static func _capture_default_keys() -> void:
	if not _default_keys.is_empty():
		return
	for action: StringName in REMAPPABLE_ACTIONS:
		var keys: Array = []
		if InputMap.has_action(action):
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey:
					keys.append(event.duplicate())
		_default_keys[action] = keys
