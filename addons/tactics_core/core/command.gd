class_name Command
extends RefCounted
## Base class for every change to a [BattleState] (spec §2.5).
##
## Commands are validated with [method can_execute], applied with
## [method execute], serialized with [method to_dict] into the [ActionLog],
## and announce themselves through [method emit_events] so presentation can
## react. Commands never touch Nodes. A few (moving before acting) support
## [method undo]; rewind uses state snapshots instead.


## Short type id used in logs and replays (e.g. "move").
func get_type() -> StringName:
	return &"command"


## Id of the unit performing the command (empty for commands without one,
## such as ending a phase). Used by rewind to find action boundaries.
func actor_id() -> StringName:
	var value: Variant = get(&"unit_id")
	if value == null:
		value = get(&"attacker_id")
	if value == null:
		value = get(&"healer_id")
	return StringName(str(value)) if value != null else &""


## True if the command is legal in [param state].
func can_execute(_state: BattleState) -> bool:
	return false


## Applies the command. Call only after [method can_execute] returned true.
func execute(_state: BattleState) -> void:
	TacticsLog.error("Command", "%s does not implement execute()" % get_type())


## True if [method undo] is supported.
func can_undo() -> bool:
	return false


## Reverts [method execute]. Only valid immediately after executing.
func undo(_state: BattleState) -> void:
	TacticsLog.error("Command", "%s cannot be undone" % get_type())


## Emits [code]TacticsEvents[/code] signals describing what just happened.
func emit_events(_events: Node) -> void:
	pass


## Serializable description for the action log and replays.
func to_dict() -> Dictionary:
	return {"type": String(get_type())}
