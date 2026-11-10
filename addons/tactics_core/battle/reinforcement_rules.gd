class_name ReinforcementRules
extends RefCounted
## Spawning and telegraphing reinforcements (spec §8.5).
##
## Each pending arrival is spawned at the start of its faction's phase on or
## after its turn. If its tile is occupied it waits and retries next phase.
## Spawned units count as having acted, so they never act on arrival.


## Spawns every arrival due for the current phase. Returns the new unit ids.
static func spawn_due(state: BattleState) -> Array[StringName]:
	var spawned: Array[StringName] = []
	var faction: FactionData = state.current_faction()
	if faction == null:
		return spawned
	var still_pending: Array[Dictionary] = []
	for arrival: Dictionary in state.pending_arrivals:
		var placement: UnitPlacement = arrival["placement"]
		if StringName(arrival["faction"]) != faction.id or int(arrival["turn"]) > state.turn:
			still_pending.append(arrival)
			continue
		if state.unit_at(placement.cell) != null:
			still_pending.append(arrival)
			TacticsLog.info("Reinforcements", "Tile %s is occupied; arrival delayed" % placement.cell)
			continue
		var unit: UnitState = UnitFactory.from_placement(state, placement, faction.id)
		if unit == null:
			continue
		unit.has_moved = true
		unit.has_acted = true
		if state.add_unit(unit):
			spawned.append(unit.id)
			if state.ruleset.awakening_rule != null:
				state.ruleset.awakening_rule.on_unit_added(state, unit)
	state.pending_arrivals = still_pending
	return spawned


## True if [param faction_id] still has arrivals waiting.
static func has_pending(state: BattleState, faction_id: StringName) -> bool:
	for arrival: Dictionary in state.pending_arrivals:
		if StringName(arrival["faction"]) == faction_id:
			return true
	return false


## Tiles to mark with a warning now: telegraphed arrivals whose phase comes
## within the next full round, shown only during a human faction's phase.
static func telegraphed_cells(state: BattleState) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var current: FactionData = state.current_faction()
	if current == null or current.controller != FactionData.Controller.HUMAN:
		return cells
	var count: int = state.factions.size()
	var now: int = (state.turn - 1) * count + state.phase_index
	for arrival: Dictionary in state.pending_arrivals:
		if not bool(arrival["telegraph"]):
			continue
		var faction_index: int = _faction_index(state, StringName(arrival["faction"]))
		var due: int = (int(arrival["turn"]) - 1) * count + faction_index
		if due > now and due - now <= count:
			cells.append((arrival["placement"] as UnitPlacement).cell)
	return cells


## Queues every arrival of [param reinforcements] on [param state].
static func queue(state: BattleState, reinforcements: Array[Reinforcement]) -> void:
	for reinforcement: Reinforcement in reinforcements:
		if reinforcement == null:
			continue
		for problem: String in reinforcement.validate():
			TacticsLog.warn("Reinforcements", problem)
		for placement: UnitPlacement in reinforcement.placements:
			if placement != null:
				state.pending_arrivals.append({"placement": placement, "turn": reinforcement.turn,
					"faction": reinforcement.faction_id, "telegraph": reinforcement.telegraph})


static func _faction_index(state: BattleState, faction_id: StringName) -> int:
	for i: int in state.factions.size():
		if state.factions[i].id == faction_id:
			return i
	return 0
