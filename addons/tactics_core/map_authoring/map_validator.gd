class_name MapValidator
extends RefCounted
## Checks a map for authoring mistakes (spec §12.4). Each problem is one
## readable line. Used by tests (every shipped map must validate cleanly)
## and by the editor script [code]debug/validate_map.gd[/code].
##
## Does not need autoloads, so it runs inside the editor.


## Problems with [param map] (empty = valid). [param roster] fills player
## spawn slots as in play; [param dialogues] defaults to the project's.
static func validate(map: BattleMap, ruleset: Ruleset, roster: Array[UnitData] = [], dialogues: DialogueLibrary = null) -> PackedStringArray:
	var problems := PackedStringArray()
	if ruleset == null:
		problems.append("No ruleset")
		return problems
	var layer: TileMapLayer = map.get_node_or_null(map.terrain_layer_path) as TileMapLayer
	if layer == null:
		problems.append("No terrain layer at '%s'" % map.terrain_layer_path)
		return problems
	_check_terrain(layer, ruleset, problems)
	var grid: BattleGrid = BattleGrid.from_tile_map_layer(layer, ruleset)
	var factions: Array[FactionData] = map.get_factions()
	if factions.is_empty():
		problems.append("No factions (set them in the MapDefinition)")
		return problems
	if factions[0].controller != FactionData.Controller.HUMAN:
		problems.append("The first faction should be the player's (human-controlled)")

	# Markers -----------------------------------------------------------------
	var occupied: Dictionary[Vector2i, String] = {}
	for marker: MapMarker in map.get_markers():
		problems.append_array(marker.validate_marker())
		if not marker.is_on_grid():
			problems.append("%s is not on the grid" % marker.describe())
		var cell: Vector2i = marker.get_cell()
		if marker is RegionMarker or marker is ReinforcementGroup:
			continue
		if not grid.in_bounds(cell):
			problems.append("%s is outside the map" % marker.describe())
			continue
		if grid.terrain_at(cell) == null:
			problems.append("%s is on a cell with no terrain" % marker.describe())
		if marker is UnitMarker or marker is PlayerSpawn:
			var in_group: bool = marker.get_parent() is ReinforcementGroup
			if not in_group:
				if occupied.has(cell):
					problems.append("%s shares its cell with %s" % [marker.describe(), occupied[cell]])
				occupied[cell] = marker.describe()

	# Units ---------------------------------------------------------------------
	var state := BattleState.new(ruleset, grid)
	state.factions = factions
	var spawns: Array[PlayerSpawn] = map.get_player_spawns()
	for placement: UnitPlacement in map.get_placements(roster):
		if state.get_faction(placement.faction_id) == null:
			problems.append("Unit at %s uses faction '%s', which the map does not list" % [placement.cell, placement.faction_id])
			continue
		var unit: UnitState = UnitFactory.from_placement(state, placement)
		if unit == null:
			continue
		state.add_unit(unit)
		if grid.move_cost(unit.cell, unit.movement_type_id()) < 1:
			problems.append("'%s' at %s stands on terrain it cannot occupy" % [unit.id, unit.cell])
		_check_armed(state, unit, placement, problems)
	for spawn: PlayerSpawn in spawns:
		if grid.move_cost(spawn.get_cell(), &"foot") < 1:
			problems.append("%s is on terrain foot units cannot stand on" % spawn.describe())
	var player_units: int = state.units_of(factions[0].id).size()
	if player_units == 0:
		problems.append("No player units: add PlayerSpawn markers (or player placements)")
	if map.definition != null and map.definition.deploy_count > spawns.size() and not spawns.is_empty():
		problems.append("deploy_count %d is more than the %d spawn slots" % [map.definition.deploy_count, spawns.size()])

	# Reinforcements ----------------------------------------------------------------
	for reinforcement: Reinforcement in map.get_reinforcements():
		for placement: UnitPlacement in reinforcement.placements:
			var probe: UnitState = UnitFactory.from_placement(state, placement, reinforcement.faction_id)
			if probe == null:
				continue
			if grid.move_cost(placement.cell, probe.movement_type_id()) < 1:
				problems.append("Turn %d reinforcement tile %s is impassable for its unit" % [reinforcement.turn, placement.cell])
			elif state.unit_at(placement.cell) != null:
				problems.append("Turn %d reinforcement tile %s is blocked by '%s' at the start" % [reinforcement.turn, placement.cell, state.unit_at(placement.cell).id])

	# Objectives ----------------------------------------------------------------------
	var reachable: Dictionary[Vector2i, bool] = _reachable_from_spawns(grid, state, factions[0].id)
	var objectives: Array[Objective] = map.get_objectives()
	for objective: Objective in objectives:
		problems.append_array(objective.validate())
		var targets: Array[Vector2i] = []
		if objective is SeizeObjective:
			targets.append((objective as SeizeObjective).cell)
		elif objective is DefendTileObjective:
			targets.append((objective as DefendTileObjective).cell)
		elif objective is EscapeObjective:
			targets.append_array((objective as EscapeObjective).cells)
		for target: Vector2i in targets:
			if not reachable.has(target):
				problems.append("Objective tile %s cannot be reached from the player's start" % target)
		if objective is DefeatBossObjective:
			var boss_objective: DefeatBossObjective = objective as DefeatBossObjective
			var found: bool = false
			for unit: UnitState in state.all_units():
				if (boss_objective.unit_id != &"" and unit.id == boss_objective.unit_id) or (boss_objective.unit_id == &"" and unit.is_boss):
					found = true
			if not found:
				problems.append("Defeat Boss objective has no boss (mark an enemy as boss or set unit_id)")

	# Events and dialogue -----------------------------------------------------------
	var library: DialogueLibrary = dialogues if dialogues != null else DialogueLibrary.load_project("en")
	problems.append_array(library.errors)
	var seen_ids: Dictionary[StringName, bool] = {}
	for event: MapEvent in map.get_events():
		if event == null:
			continue
		problems.append_array(event.validate())
		if seen_ids.has(event.id):
			problems.append("Two events share the id '%s'" % event.id)
		seen_ids[event.id] = true
		if event.dialogue_id != &"" and not library.has_scene(event.dialogue_id):
			problems.append("Event '%s' uses unknown dialogue '%s'" % [event.id, event.dialogue_id])
		for unit_id: StringName in [event.unit_id, event.other_unit_id]:
			if unit_id != &"" and event.trigger in [MapEvent.Trigger.TALK, MapEvent.Trigger.UNIT_DEFEATED, MapEvent.Trigger.BATTLE_QUOTE] \
					and state.get_unit(unit_id) == null:
				problems.append("Event '%s' refers to unit '%s', which isn't on the map (ids: %s)" % [event.id, unit_id, _unit_ids(state)])
		if event.trigger == MapEvent.Trigger.VISIT and not reachable.has(event.cell):
			problems.append("Visit tile %s (event '%s') cannot be reached" % [event.cell, event.id])
	return problems


static func _check_terrain(layer: TileMapLayer, ruleset: Ruleset, problems: PackedStringArray) -> void:
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name(ruleset.terrain_id_layer):
		problems.append("Terrain tileset has no '%s' custom data layer" % ruleset.terrain_id_layer)
		return
	if layer.get_used_cells().is_empty():
		problems.append("The terrain layer is empty")
	var unknown: Dictionary[String, int] = {}
	for cell: Vector2i in layer.get_used_cells():
		var tile: TileData = layer.get_cell_tile_data(cell)
		var terrain_id: String = str(tile.get_custom_data(ruleset.terrain_id_layer)) if tile != null else ""
		if terrain_id.is_empty() or ruleset.get_terrain(StringName(terrain_id)) == null:
			unknown[terrain_id] = unknown.get(terrain_id, 0) + 1
	for terrain_id: String in unknown:
		problems.append("%d tile(s) with unknown terrain id '%s'" % [unknown[terrain_id], terrain_id])


static func _check_armed(state: BattleState, unit: UnitState, placement: UnitPlacement, problems: PackedStringArray) -> void:
	var faction: FactionData = state.get_faction(unit.faction_id)
	if faction == null or faction.controller == FactionData.Controller.HUMAN:
		return
	if unit.equipped_weapon() != null:
		return
	var healer: bool = placement.ai_profile != null and placement.ai_profile.behavior == AIProfile.Behavior.HEALER and not unit.heal_slot_indices().is_empty()
	if not healer:
		problems.append("'%s' at %s has no weapon it can use" % [unit.id, unit.cell])


## Cells a foot unit could reach from any player unit, ignoring other units.
static func _reachable_from_spawns(grid: BattleGrid, state: BattleState, player_faction: StringName) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	var always: Callable = func(_cell: Vector2i) -> bool: return true
	for unit: UnitState in state.units_of(player_faction):
		var flood: MoveRange = Pathfinder.flood(grid, unit.cell, 9999, &"foot", always, always)
		for cell: Vector2i in flood.costs:
			result[cell] = true
	return result


static func _unit_ids(state: BattleState) -> String:
	var ids: PackedStringArray = []
	for unit: UnitState in state.all_units():
		ids.append(String(unit.id))
	return ", ".join(ids)
