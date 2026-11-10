@tool
class_name ActionChargeAwakeningRule
extends AwakeningRule
## A per-unit meter fills from actions (Stagger, kills, chain attacks,
## heals, and each own phase start). A full meter lets the unit awaken for
## [member duration_turns] turns; the meter then resets to 0.

@export_range(1, 99) var max_charge: int = 6
@export_range(0, 99) var start_charge: int = 3
@export_range(1, 20) var duration_turns: int = 3
@export_range(1, 99) var max_uses_per_unit_per_map: int = 2
## Charge gained per event id (stagger, kill, chain, heal, phase_start).
@export var gains: Dictionary[StringName, int] = {&"stagger": 2, &"kill": 1, &"chain": 1, &"heal": 1, &"phase_start": 1}


func on_unit_added(_state: BattleState, unit: UnitState) -> void:
	if unit.awakening != null:
		unit.awaken_charge = mini(start_charge, max_charge)


func can_awaken(state: BattleState, unit: UnitState) -> bool:
	return super(state, unit) and unit.awaken_charge >= max_charge and unit.awaken_uses < max_uses_per_unit_per_map


func awaken(state: BattleState, unit: UnitState) -> void:
	super(state, unit)
	unit.awaken_turns_left = duration_turns
	unit.awaken_charge = 0


func on_phase_start(state: BattleState, unit: UnitState) -> void:
	if unit.awakened:
		unit.awaken_turns_left -= 1
		if unit.awaken_turns_left <= 0:
			end_awakening(state, unit)
	elif state.turn > 1:
		# No phase-start charge on turn 1: the meter starts at start_charge.
		on_event(state, unit, &"phase_start")


func on_event(_state: BattleState, unit: UnitState, event: StringName) -> void:
	if unit.awakening == null or unit.awakened:
		return
	unit.awaken_charge = mini(max_charge, unit.awaken_charge + int(gains.get(event, 0)))


func forecast_gain(forecast: CombatForecast) -> int:
	var gain: int = 0
	if forecast.stagger_on_hit and forecast.defender.hp_after_all_hits > 0:
		gain += int(gains.get(EVENT_STAGGER, 0))
	if forecast.defender.hp_after_all_hits == 0:
		gain += int(gains.get(EVENT_KILL, 0))
	return gain


func status_text(_state: BattleState, unit: UnitState) -> String:
	if unit.awakening == null:
		return ""
	if unit.awakened:
		return tr("AWAKEN_STATUS_ACTIVE") % unit.awaken_turns_left
	return tr("AWAKEN_STATUS_CHARGE") % [unit.awaken_charge, max_charge]
