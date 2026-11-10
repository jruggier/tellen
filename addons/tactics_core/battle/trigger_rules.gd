class_name TriggerRules
extends RefCounted
## Fires [TriggerRegion]s when units stop inside them (spec §8.6).


## Checks [param regions] for [param unit] (call after it moves). Returns
## the regions that fired.
static func on_unit_moved(state: BattleState, regions: Array[TriggerRegion], unit: UnitState) -> Array[TriggerRegion]:
	var fired: Array[TriggerRegion] = []
	for i: int in regions.size():
		var region: TriggerRegion = regions[i]
		if region == null or not region.rect.has_point(unit.cell):
			continue
		var faction: StringName = region.faction_id if region.faction_id != &"" else Objective.player_faction_id(state)
		if unit.faction_id != faction:
			continue
		var key: String = "region_fired_%d" % i
		if region.once and state.flags.get(key, false):
			continue
		state.flags[key] = true
		for group: StringName in region.wake_groups:
			AIRules.wake_group(state, group)
		for flag: String in region.set_flags:
			state.flags[flag] = true
		fired.append(region)
	return fired
