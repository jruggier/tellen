class_name EndPhaseCommand
extends Command
## Ends the current faction's phase and starts the next (see [TurnManager]).

var faction_id: StringName
## Filled on execute: what happened at the start of the next phase.
var report: TurnManager.PhaseReport
var _turn_before: int = 0


func _init(ending_faction: StringName = &"") -> void:
	faction_id = ending_faction


func get_type() -> StringName:
	return &"end_phase"


func can_execute(state: BattleState) -> bool:
	return state.current_faction() != null and state.current_faction().id == faction_id


func execute(state: BattleState) -> void:
	_turn_before = state.turn
	report = TurnManager.end_phase(state)


func emit_events(events: Node) -> void:
	events.emit_signal(&"phase_ended", faction_id, _turn_before)
	if report.turn != _turn_before:
		events.emit_signal(&"turn_started", report.turn)
	events.emit_signal(&"phase_started", report.faction_id, report.turn)
	for unit_id: StringName in report.healed:
		events.emit_signal(&"unit_healed", unit_id, report.healed[unit_id])


func to_dict() -> Dictionary:
	return {"type": "end_phase", "faction": String(faction_id)}
