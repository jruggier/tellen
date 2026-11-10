class_name CantoMoveCommand
extends Command
## Canto (spec §7.4): after acting, a unit with a Canto skill moves again
## using the movement it has left this phase. Once per phase.

var unit_id: StringName
var destination: Vector2i
var path: Array[Vector2i] = []
var _from: Vector2i


func _init(moving_unit: StringName = &"", to_cell: Vector2i = Vector2i.ZERO) -> void:
	unit_id = moving_unit
	destination = to_cell


func get_type() -> StringName:
	return &"canto_move"


## Movement [param unit] has left for Canto, or 0 if it can't use Canto now.
static func remaining(state: BattleState, unit: UnitState) -> int:
	if unit == null or not unit.is_alive() or not unit.has_acted or unit.canto_used or not SkillRunner.has_canto(state, unit):
		return 0
	return maxi(0, unit.mov(state.ruleset) - unit.moved_cost)


## Cells [param unit] can reach with its remaining Canto movement.
static func range_for(state: BattleState, unit: UnitState) -> MoveRange:
	return RangeCalculator.movement_with_budget(state, unit, remaining(state, unit))


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if remaining(state, unit) <= 0:
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	return destination != unit.cell and range_for(state, unit).can_stop_at(destination)


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	var move_range: MoveRange = range_for(state, unit)
	path = move_range.path_to(destination)
	_from = unit.cell
	unit.moved_cost += move_range.cost_to(destination)
	unit.canto_used = true
	state.move_unit(unit_id, destination)
	TriggerRules.on_unit_moved(state, state.trigger_regions, unit)


func emit_events(events: Node) -> void:
	events.emit_signal(&"unit_moved", unit_id, _from, destination, path)


func to_dict() -> Dictionary:
	return {"type": "canto_move", "unit": String(unit_id), "to": [destination.x, destination.y]}
