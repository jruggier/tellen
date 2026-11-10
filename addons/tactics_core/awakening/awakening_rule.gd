@tool
class_name AwakeningRule
extends Resource
## Abstract rules for awakening (spec §9.5). The ruleset picks one
## implementation; units carry what awakening grants ([AwakeningData]).
##
## Awakening is a free action from the action menu (it locks in the move).
## While awakened, a unit gets its stat modifiers and skills, and may use
## its signature attack once.

const EVENT_STAGGER: StringName = &"stagger"
const EVENT_KILL: StringName = &"kill"
const EVENT_CHAIN: StringName = &"chain"
const EVENT_HEAL: StringName = &"heal"


## Called once per unit when it enters the battle.
func on_unit_added(_state: BattleState, _unit: UnitState) -> void:
	pass


## True if [param unit] may awaken now.
func can_awaken(_state: BattleState, unit: UnitState) -> bool:
	return unit.awakening != null and not unit.awakened and unit.is_alive()


## Awakens [param unit]. Subclasses call super() and set their counters.
func awaken(_state: BattleState, unit: UnitState) -> void:
	unit.awakened = true
	unit.signature_used = false
	unit.awaken_uses += 1


## Ends [param unit]'s awakening.
func end_awakening(_state: BattleState, unit: UnitState) -> void:
	unit.awakened = false
	unit.awaken_turns_left = 0


## Start of [param unit]'s own phase: count down durations and cooldowns.
func on_phase_start(_state: BattleState, _unit: UnitState) -> void:
	pass


## Something happened that may charge awakening (EVENT_*).
func on_event(_state: BattleState, _unit: UnitState, _event: StringName) -> void:
	pass


## Charge the attacker would gain if everything in [param forecast] hits
## (shown in the forecast panel; 0 for rules without charge).
func forecast_gain(_forecast: CombatForecast) -> int:
	return 0


## One-line status for the unit panel (localized).
func status_text(_state: BattleState, _unit: UnitState) -> String:
	return ""


## Problems with this configuration (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()
