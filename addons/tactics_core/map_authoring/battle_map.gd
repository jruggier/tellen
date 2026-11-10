@tool
class_name BattleMap
extends Node2D
## Root of a map scene: the terrain layer plus what to place on it.
##
## A map scene is a BattleMap with a child [TileMapLayer] named "Terrain"
## (TileSet with a [code]terrain_id[/code] custom data layer), a
## [MapDefinition], and [MapMarker]s placed on it (see the map template). The battle
## scene instances it and builds the battle from it. Running a map scene
## directly (F6) hosts it inside the battle scene named by the project
## setting [code]tactics_core/battle/scene[/code].
##
## The [code]get_*[/code] accessors merge the definition, the markers and
## the plain lists below (kept for maps built before markers existed).

const SETTING_BATTLE_SCENE: String = "tactics_core/battle/scene"
const DEFAULT_BATTLE_SCENE: String = "res://game/scenes/battle_scene.tscn"

@export var map_id: StringName = &""
## Factions in phase order (first is the player).
@export var factions: Array[FactionData] = []
## Units placed when the battle starts.
@export var placements: Array[UnitPlacement] = []
## Units that arrive later.
@export var reinforcements: Array[Reinforcement] = []
## Victory objectives (all must be met; empty = Rout).
@export var objectives: Array[Objective] = []
## Ways to lose (empty = protagonist defeated, or all units defeated).
@export var defeat_conditions: Array[DefeatCondition] = []
## Regions that fire events when units stop inside.
@export var trigger_regions: Array[TriggerRegion] = []
## Story and gameplay events (dialogue, talk, visits, quotes...).
@export var events: Array[MapEvent] = []
## Path to the terrain layer.
@export var terrain_layer_path: NodePath = ^"Terrain"
## Map settings (name, factions, objectives, deployment, story). Markers
## placed under the map add units, spawn slots, reinforcements, objective
## tiles, regions and villages.
@export var definition: MapDefinition


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if get_tree().current_scene == self:
		_host_in_battle_scene.call_deferred()


## The terrain layer, or null (logged) if missing.
func get_terrain_layer() -> TileMapLayer:
	var layer: TileMapLayer = get_node_or_null(terrain_layer_path) as TileMapLayer
	if layer == null:
		TacticsLog.warn("BattleMap", "%s: no TileMapLayer at '%s'" % [name, terrain_layer_path])
	return layer


## Ran directly: move this map into a battle scene so it can be played.
func _host_in_battle_scene() -> void:
	var path: String = str(ProjectSettings.get_setting(SETTING_BATTLE_SCENE, DEFAULT_BATTLE_SCENE))
	if not ResourceLoader.exists(path):
		TacticsLog.warn("BattleMap", "Battle scene not found: %s" % path)
		return
	var battle: Node = (load(path) as PackedScene).instantiate()
	var tree: SceneTree = get_tree()
	var root: Window = tree.root
	root.remove_child(self)
	battle.set(&"map_instance", self)
	root.add_child(battle)
	tree.current_scene = battle


## Map id: the definition's, else [member map_id], else the scene file name.
func get_map_id() -> StringName:
	if definition != null and definition.map_id != &"":
		return definition.map_id
	if map_id != &"":
		return map_id
	return StringName(scene_file_path.get_file().get_basename()) if not scene_file_path.is_empty() else StringName(name)


## Factions in phase order.
func get_factions() -> Array[FactionData]:
	if definition != null and not definition.factions.is_empty():
		return definition.factions.duplicate()
	return factions.duplicate()


## Every marker on the map (any depth), in scene order.
func get_markers() -> Array[MapMarker]:
	var result: Array[MapMarker] = []
	_collect_markers(self, result)
	return result


## Player spawn slots ordered by slot number.
func get_player_spawns() -> Array[PlayerSpawn]:
	var spawns: Array[PlayerSpawn] = []
	for marker: MapMarker in get_markers():
		if marker is PlayerSpawn:
			spawns.append(marker as PlayerSpawn)
	spawns.sort_custom(func(a: PlayerSpawn, b: PlayerSpawn) -> bool: return a.slot < b.slot)
	return spawns


## Every unit placed at the start: the plain list, unit markers (outside
## reinforcement groups) and the player's deployment from [param roster].
func get_placements(roster: Array[UnitData] = []) -> Array[UnitPlacement]:
	var result: Array[UnitPlacement] = placements.duplicate()
	for marker: MapMarker in get_markers():
		if marker is UnitMarker and not (marker.get_parent() is ReinforcementGroup):
			result.append((marker as UnitMarker).placement())
	result.append_array(deploy(roster))
	return result


## Places the player's units on the spawn slots: forced units first (their
## own slot, else the first free one), then [param roster] in order, up to
## the definition's deploy count (0 = every slot).
func deploy(roster: Array[UnitData]) -> Array[UnitPlacement]:
	var result: Array[UnitPlacement] = []
	var spawns: Array[PlayerSpawn] = get_player_spawns()
	if spawns.is_empty():
		return result
	var player: StringName = get_factions()[0].id if not get_factions().is_empty() else &"player"
	var limit: int = definition.deploy_count if definition != null and definition.deploy_count > 0 else spawns.size()
	limit = mini(limit, spawns.size())
	var assigned: Dictionary[PlayerSpawn, UnitData] = {}
	var used: Array[UnitData] = []
	for spawn: PlayerSpawn in spawns:
		if spawn.forced_unit != null and not used.has(spawn.forced_unit):
			assigned[spawn] = spawn.forced_unit
			used.append(spawn.forced_unit)
	var queue: Array[UnitData] = []
	if definition != null:
		queue.append_array(definition.forced_units)
	queue.append_array(roster)
	for unit: UnitData in queue:
		if unit == null or used.has(unit) or assigned.size() >= limit:
			continue
		for spawn: PlayerSpawn in spawns:
			if not assigned.has(spawn) and spawn.forced_unit == null:
				assigned[spawn] = unit
				used.append(unit)
				break
	for spawn: PlayerSpawn in spawns:
		if assigned.has(spawn):
			var placement := UnitPlacement.new()
			placement.unit_data = assigned[spawn]
			placement.faction_id = player
			placement.cell = spawn.get_cell()
			result.append(placement)
	return result


## Objectives: definition, plain list and objective tile markers.
func get_objectives() -> Array[Objective]:
	var result: Array[Objective] = objectives.duplicate()
	if definition != null:
		result.append_array(definition.objectives)
	var escape_cells: Array[Vector2i] = []
	var escape_count: int = 0
	for marker: MapMarker in get_markers():
		if marker is EscapeTile:
			escape_cells.append(marker.get_cell())
			escape_count = maxi(escape_count, (marker as EscapeTile).count)
		elif marker is ObjectiveTileMarker:
			var objective: Objective = (marker as ObjectiveTileMarker).objective()
			if objective != null:
				result.append(objective)
	if not escape_cells.is_empty():
		var escape := EscapeObjective.new()
		escape.cells = escape_cells
		escape.count = escape_count
		result.append(escape)
	return result


func get_defeat_conditions() -> Array[DefeatCondition]:
	var result: Array[DefeatCondition] = defeat_conditions.duplicate()
	if definition != null:
		result.append_array(definition.all_defeat_conditions())
	return result


func get_reinforcements() -> Array[Reinforcement]:
	var result: Array[Reinforcement] = reinforcements.duplicate()
	for marker: MapMarker in get_markers():
		if marker is ReinforcementGroup:
			result.append((marker as ReinforcementGroup).reinforcement())
	return result


## Events: plain list, definition (story + events), regions and villages.
func get_events() -> Array[MapEvent]:
	var result: Array[MapEvent] = events.duplicate()
	if definition != null:
		result.append_array(definition.story_events())
		result.append_array(definition.events)
	for marker: MapMarker in get_markers():
		var event: MapEvent = null
		if marker is RegionMarker:
			event = (marker as RegionMarker).map_event()
		elif marker is VillageMarker:
			event = (marker as VillageMarker).map_event()
		if event != null:
			result.append(event)
	return result


func _collect_markers(node: Node, into: Array[MapMarker]) -> void:
	for child: Node in node.get_children():
		if child is MapMarker:
			into.append(child as MapMarker)
		_collect_markers(child, into)
