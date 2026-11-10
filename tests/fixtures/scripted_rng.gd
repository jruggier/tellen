class_name ScriptedRng
extends SeededRng
## Test RNG that returns queued rolls in order, so resolver tests can force
## exact hit/miss/crit sequences. Falls back to seeded rolls when empty.

var _queue: Array[int] = []
## Every value returned, for asserting how many rolls were consumed.
var consumed: Array[int] = []


func _init(rolls: Array[int] = []) -> void:
	super(0)
	_queue = rolls.duplicate()


func roll_100(stream: StringName) -> int:
	return _next(super.roll_100(stream))


func randi_range(stream: StringName, from: int, to: int) -> int:
	return _next(super.randi_range(stream, from, to))


func remaining() -> int:
	return _queue.size()


func _next(fallback: int) -> int:
	var value: int = _queue.pop_front() if not _queue.is_empty() else fallback
	consumed.append(value)
	return value
