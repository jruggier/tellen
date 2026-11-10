class_name UnitFactory
extends RefCounted
## Creates [UnitState]s from [UnitPlacement]s (map start and reinforcements),
## assigning battle ids and applying the battle's difficulty to generic units.


## Creates the unit for [param placement] (faction overridden by
## [param faction_override] when given). Returns null (logged) if invalid.
static func from_placement(state: BattleState, placement: UnitPlacement, faction_override: StringName = &"") -> UnitState:
	var problems: PackedStringArray = placement.validate()
	if not problems.is_empty():
		for problem: String in problems:
			TacticsLog.warn("UnitFactory", problem)
		return null
	var faction: StringName = faction_override if faction_override != &"" else placement.faction_id
	if state.get_faction(faction) == null:
		TacticsLog.warn("UnitFactory", "Placement at %s uses faction '%s', which the map does not list" % [placement.cell, faction])
		return null
	var unit_id: StringName = placement.unit_id if placement.unit_id != &"" else state.next_unit_id(
		placement.unit_data.id if placement.unit_data != null else placement.class_data.id, placement.unit_data != null)
	var unit: UnitState
	if placement.unit_data != null:
		unit = UnitState.from_unit_data(unit_id, placement.unit_data, state.ruleset, faction, placement.cell)
		for item: ItemData in placement.drops:
			unit.inventory.append(InventorySlot.of(item, true))
	else:
		unit = UnitState.generic(unit_id, placement.class_data, placement.level, state.ruleset, faction, placement.cell,
			placement.items, state.difficulty_id, placement.drops)
	unit.is_boss = placement.is_boss
	unit.ai_profile = placement.ai_profile
	unit.ai_group = placement.ai_group
	return unit
