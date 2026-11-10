class_name ThreatMap
extends RefCounted
## Where hostile units can move or attack this turn (spec §7.3, §14).
##
## Per-unit results are cached and recomputed only after the battle state
## changes (any movement can open or block paths), so toggling the overlay
## or hovering units stays cheap.

## Danger for one unit: cells it can move to and cells it can attack.
class Entry:
	extends RefCounted
	var move_cells: Dictionary[Vector2i, bool] = {}
	var attack_cells: Dictionary[Vector2i, bool] = {}

	## Union of move and attack cells.
	func all_cells() -> Dictionary[Vector2i, bool]:
		var result: Dictionary[Vector2i, bool] = move_cells.duplicate()
		result.merge(attack_cells)
		return result


var _entries: Dictionary[StringName, Entry] = {}
var _version: int = -1


## Movement and attack cells for [param unit_id].
func for_unit(state: BattleState, unit_id: StringName) -> Entry:
	_sync(state)
	if _entries.has(unit_id):
		return _entries[unit_id]
	var entry := Entry.new()
	var unit: UnitState = state.get_unit(unit_id)
	if unit != null and unit.is_alive():
		var move_range: MoveRange = RangeCalculator.movement(state, unit)
		for cell: Vector2i in move_range.stop_cells():
			entry.move_cells[cell] = true
		entry.attack_cells = RangeCalculator.attack_cells(state, unit, move_range)
	_entries[unit_id] = entry
	return entry


## Union of every living unit not allied with [param viewer_faction].
func for_enemies_of(state: BattleState, viewer_faction: StringName) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for unit: UnitState in state.all_units():
		if unit.is_alive() and not state.are_allied(unit.faction_id, viewer_faction):
			result.merge(for_unit(state, unit.id).all_cells())
	return result


## Drops all cached results.
func invalidate() -> void:
	_entries.clear()


func _sync(state: BattleState) -> void:
	if state.version != _version:
		_entries.clear()
		_version = state.version
