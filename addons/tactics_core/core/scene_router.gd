extends Node
## Scene navigation, registered as the [code]SceneRouter[/code] autoload.
##
## Scenes are addressed by route id (registered by the game) or by path.
## Parameters for the next scene are stored here and read once by that scene
## with [method take_params], so scenes never reach into each other.
##
## Extension point: transitions (fades, loading screens) hook in through
## [signal route_requested] and [signal route_changed].

## Emitted before a scene change starts.
signal route_requested(scene_path: String, params: Dictionary)

## Emitted after the scene change has been requested from the tree.
signal route_changed(scene_path: String)

var _routes: Dictionary[StringName, String] = {}
var _pending_params: Dictionary = {}
var _current_path: String = ""


## Registers [param route_id] as an alias for [param scene_path].
func register_route(route_id: StringName, scene_path: String) -> void:
	_routes[route_id] = scene_path


## Returns the scene path for [param route_id], or an empty string.
func resolve(route_id: StringName) -> String:
	return _routes.get(route_id, "")


## Changes to the scene registered as [param route_id].
func go_to_route(route_id: StringName, params: Dictionary = {}) -> Error:
	var path: String = resolve(route_id)
	if path.is_empty():
		TacticsLog.warn("SceneRouter", "Unknown route '%s'" % route_id)
		return ERR_DOES_NOT_EXIST
	return go_to(path, params)


## Changes to the scene at [param scene_path], passing [param params].
func go_to(scene_path: String, params: Dictionary = {}) -> Error:
	if not ResourceLoader.exists(scene_path):
		TacticsLog.warn("SceneRouter", "Scene not found: %s" % scene_path)
		return ERR_FILE_NOT_FOUND
	_pending_params = params.duplicate(true)
	route_requested.emit(scene_path, _pending_params)
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		TacticsLog.error("SceneRouter", "change_scene_to_file failed (%d): %s" % [result, scene_path])
		return result
	_current_path = scene_path
	route_changed.emit(scene_path)
	return OK


## Returns the parameters passed to the current scene and clears them.
func take_params() -> Dictionary:
	var params: Dictionary = _pending_params
	_pending_params = {}
	return params


## Path of the last scene changed to through the router.
func get_current_path() -> String:
	return _current_path
