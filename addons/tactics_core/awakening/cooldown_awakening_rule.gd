@tool
class_name CooldownAwakeningRule
extends AwakeningRule
## Awakening lasts [member duration_turns] of the unit's turns, then the
## unit waits [member cooldown_turns] before it can awaken again. At most
## [member max_uses_per_map] awakenings per map, counted for the whole army
## or per unit.

enum UseScope { ARMY, UNIT }

@export_range(1, 20) var duration_turns: int = 3
@export_range(0, 20) var cooldown_turns: int = 3
@export_range(1, 99) var max_uses_per_map: int = 3
@export var use_scope: UseScope = UseScope.ARMY


func can_awaken(state: BattleState, unit: UnitState) -> bool:
	return super(state, unit) and unit.awaken_cooldown <= 0 and uses_left(state, unit) > 0


## Awakenings still available to [param unit] this map.
func uses_left(state: BattleState, unit: UnitState) -> int:
	if use_scope == UseScope.UNIT:
		return max_uses_per_map - unit.awaken_uses
	return max_uses_per_map - int(state.flags.get(_army_key(unit), 0))


func awaken(state: BattleState, unit: UnitState) -> void:
	super(state, unit)
	unit.awaken_turns_left = duration_turns
	var key: String = _army_key(unit)
	state.flags[key] = int(state.flags.get(key, 0)) + 1


func end_awakening(state: BattleState, unit: UnitState) -> void:
	super(state, unit)
	unit.awaken_cooldown = cooldown_turns


func on_phase_start(state: BattleState, unit: UnitState) -> void:
	if unit.awakened:
		unit.awaken_turns_left -= 1
		if unit.awaken_turns_left <= 0:
			end_awakening(state, unit)
	elif unit.awaken_cooldown > 0:
		unit.awaken_cooldown -= 1


func status_text(state: BattleState, unit: UnitState) -> String:
	if unit.awakening == null:
		return ""
	if unit.awakened:
		return tr("AWAKEN_STATUS_ACTIVE") % unit.awaken_turns_left
	if unit.awaken_cooldown > 0:
		return tr("AWAKEN_STATUS_COOLDOWN") % unit.awaken_cooldown
	return tr("AWAKEN_STATUS_READY") % [uses_left(state, unit), max_uses_per_map]


static func _army_key(unit: UnitState) -> String:
	return "awakening_uses_%s" % unit.faction_id
