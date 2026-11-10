class_name DirectionRepeat
extends RefCounted
## Turns held direction inputs into evenly spaced steps: one step the
## moment a direction is pressed, nothing more until it has been held for
## [member delay] seconds, then one step every [member interval] seconds.
##
## Owners call [method poll] every frame while their menu has focus and
## ignore direction input events (keyboard auto-repeat and analog sticks
## send far too many). Directions already held when a menu opens are
## ignored until released, so a held key doesn't leak into the next menu.

const ACTIONS: Dictionary[StringName, Vector2i] = {
	&"cursor_up": Vector2i.UP, &"cursor_down": Vector2i.DOWN,
	&"cursor_left": Vector2i.LEFT, &"cursor_right": Vector2i.RIGHT,
}

## Seconds a direction must be held before it starts repeating.
var delay: float = 0.5
## Seconds between steps while repeating.
var interval: float = 0.1

## Action → seconds held (absent = not held, negative = blocked until released).
var _held: Dictionary[StringName, float] = {}


func _init(repeat_delay: float = 0.5, repeat_interval: float = 0.1) -> void:
	delay = repeat_delay
	interval = repeat_interval


## Uses the player's menu repeat settings ([GameSettings]).
static func for_menus() -> DirectionRepeat:
	var settings: GameSettings = GameSettings.current()
	return DirectionRepeat.new(settings.menu_repeat_delay(), settings.menu_repeat_interval())


## The direction to step this frame (zero for none); [param pressed] reads
## whether an action is down (defaults to [method Input.is_action_pressed];
## tests pass their own).
func poll(delta: float, pressed: Callable = Callable()) -> Vector2i:
	var step := Vector2i.ZERO
	for action: StringName in ACTIONS:
		var down: bool = pressed.call(action) if pressed.is_valid() else (InputMap.has_action(action) and Input.is_action_pressed(action))
		if not down:
			_held.erase(action)
			continue
		if not _held.has(action):
			_held[action] = 0.0
			step += ACTIONS[action]
			continue
		var before: float = _held[action]
		if before < 0.0:
			continue  # held since before the menu opened
		var now: float = before + delta
		_held[action] = now
		if now >= delay:
			var steps_before: int = floori((before - delay) / interval) if before >= delay else -1
			var steps_now: int = floori((now - delay) / interval)
			if steps_now > steps_before:
				step += ACTIONS[action]
	return step.clamp(-Vector2i.ONE, Vector2i.ONE)


## Forgets timings; directions currently held won't step until released.
func reset(pressed: Callable = Callable()) -> void:
	_held.clear()
	for action: StringName in ACTIONS:
		var down: bool = pressed.call(action) if pressed.is_valid() else (InputMap.has_action(action) and Input.is_action_pressed(action))
		if down:
			_held[action] = -1.0


## True if [param event] belongs to a direction action (to swallow it).
static func is_direction_event(event: InputEvent) -> bool:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action) and event.is_action(action):
			return true
	return false
