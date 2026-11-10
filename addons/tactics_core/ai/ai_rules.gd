class_name AIRules
extends RefCounted
## Waking sleeping AI units (AGGRO_REGION, spec §10.1).


## True if [param unit] currently behaves as its profile's waiting state.
static func is_asleep(unit: UnitState) -> bool:
	return unit.ai_profile != null and unit.ai_profile.behavior == AIProfile.Behavior.AGGRO_REGION and not unit.ai_awake


## Wakes [param unit] and every unit of its faction sharing its ai_group.
static func wake(state: BattleState, unit: UnitState) -> void:
	unit.ai_awake = true
	if unit.ai_group != &"":
		wake_group(state, unit.ai_group)


## Wakes every unit in [param group].
static func wake_group(state: BattleState, group: StringName) -> void:
	for other: UnitState in state.all_units():
		if other.ai_group == group:
			other.ai_awake = true
	state.mark_changed()


## Wakes sleeping units whose trigger region holds a hostile unit.
static func wake_by_regions(state: BattleState) -> void:
	for unit: UnitState in state.all_units():
		if not unit.is_alive() or not is_asleep(unit) or unit.ai_profile.trigger_region.size == Vector2i.ZERO:
			continue
		for other: UnitState in state.all_units():
			if other.is_alive() and not state.are_allied(other.faction_id, unit.faction_id) \
					and unit.ai_profile.trigger_region.has_point(other.cell):
				wake(state, unit)
				break
