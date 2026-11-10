class_name ActionLog
extends RefCounted
## Ordered record of executed commands, with the turn and phase they ran in.
## Used for debugging, replays and rewind (M8).

var _entries: Array[Dictionary] = []


## Records [param command] as executed in [param state].
func record(command: Command, state: BattleState) -> void:
	var entry: Dictionary = command.to_dict()
	entry["turn"] = state.turn
	entry["phase"] = state.phase_index
	_entries.append(entry)


## Removes the most recent entry (after an undo).
func pop() -> void:
	if not _entries.is_empty():
		_entries.pop_back()


## Drops every entry after the first [param new_size] (rewind).
func truncate(new_size: int) -> void:
	_entries.resize(clampi(new_size, 0, _entries.size()))


func size() -> int:
	return _entries.size()


## A copy of all entries, oldest first.
func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)
