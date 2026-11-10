@tool
class_name BattleMap
extends Node2D
## Root of a map scene: the terrain layer plus what to place on it.
##
## A map scene is a BattleMap with a child [TileMapLayer] named "Terrain"
## (TileSet with a [code]terrain_id[/code] custom data layer). The battle
## scene instances it and builds the battle from it. Running a map scene
## directly (F6) hosts it inside the battle scene named by the project
## setting [code]tactics_core/battle/scene[/code].
##
## M7 replaces the [member placements] list with editor markers and a
## [code]MapDefinition[/code]; the battle reads placements either way.

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
## Path to the terrain layer.
@export var terrain_layer_path: NodePath = ^"Terrain"


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
