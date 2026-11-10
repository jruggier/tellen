class_name MoveCommand
extends Command
## Moves a ready unit to a cell it can stop on, along its cheapest path.
##
## The path is computed from the state when the command executes, so a
## command built from an outdated preview cannot teleport a unit. Undo
## returns the unit to its start (cancel before choosing an action).

var unit_id: StringName
var destination: Vector2i
## Filled on execute: the cells walked, start and destination included.
var path: Array[Vector2i] = []
var _from: Vector2i


func _init(moving_unit_id: StringName = &"", to_cell: Vector2i = Vector2i.ZERO) -> void:
	unit_id = moving_unit_id
	destination = to_cell


func get_type() -> StringName:
	return &"move"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if unit == null or not unit.is_ready() or unit.has_moved:
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	return RangeCalculator.movement(state, unit).can_stop_at(destination)


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	path = RangeCalculator.movement(state, unit).path_to(destination)
	_from = unit.cell
	state.move_unit(unit_id, destination)
	unit.has_moved = true


func can_undo() -> bool:
	return true


func undo(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	state.move_unit(unit_id, _from)
	unit.has_moved = false


func emit_events(events: Node) -> void:
	events.emit_signal(&"unit_moved", unit_id, _from, destination, path)


func to_dict() -> Dictionary:
	var cells: Array[Array] = []
	for cell: Vector2i in path:
		cells.append([cell.x, cell.y])
	return {"type": "move", "unit": String(unit_id), "to": [destination.x, destination.y], "path": cells}
