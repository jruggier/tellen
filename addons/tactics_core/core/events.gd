extends Node
## Global event bus, registered as the [code]TacticsEvents[/code] autoload.
##
## Framework systems emit; game code and presentation listen. Payloads use
## ids and plain values (not Node references) so listeners never reach into
## battle logic, and so events can be logged or replayed.
##
## Signals for systems that do not exist yet (combat results, level-ups,
## awakening) are added in the milestone that introduces their data types.

## A battle on map [param map_id] has finished loading and is about to start.
signal battle_started(map_id: StringName)

## The battle ended. [param victory] is false for a defeat.
signal battle_ended(map_id: StringName, victory: bool)

## A new turn began (turn 1 is the first).
signal turn_started(turn: int)

## [param faction_id]'s phase began on [param turn].
signal phase_started(faction_id: StringName, turn: int)

## [param faction_id]'s phase ended on [param turn].
signal phase_ended(faction_id: StringName, turn: int)

## A unit moved along [param path] (first cell is [param from], last is [param to]).
signal unit_moved(unit_id: StringName, from: Vector2i, to: Vector2i, path: Array[Vector2i])

## A unit was defeated. [param by_unit_id] is empty if no unit caused it.
signal unit_defeated(unit_id: StringName, by_unit_id: StringName)

## A combat finished; [param result] holds every strike in order.
signal combat_resolved(attacker_id: StringName, defender_id: StringName, result: CombatResult)

## A unit gained a level; [param gains] holds the stat increases.
signal level_up(unit_id: StringName, new_level: int, gains: StatBlock)

## A unit recovered [param amount] HP.
signal unit_healed(unit_id: StringName, amount: int)

## A dialogue script should play. [param context] carries trigger details.
signal dialogue_requested(script_id: StringName, context: Dictionary)

## An objective was completed.
signal objective_completed(objective_id: StringName)

## The active ruleset changed (see the [code]RulesetProvider[/code] autoload).
signal ruleset_changed(ruleset: Ruleset)

## A log line was emitted at WARN level or above (for in-game consoles).
signal log_emitted(level: int, line: String)

## The player's settings changed (see [GameSettings]).
signal settings_changed


func _ready() -> void:
	TacticsLog.configure_from_project_settings()
	GameSettings.current()  # loads and applies the player's settings (incl. controller layout)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	ControllerLayout.refresh()
