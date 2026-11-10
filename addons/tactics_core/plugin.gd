@tool
extends EditorPlugin
## Editor entry point for Tactics Core.
##
## Enabling the plugin registers the framework autoloads and project
## settings, so the framework can be dropped into another project by copying
## [code]addons/tactics_core[/code] and enabling it. Custom types and editor
## tools (map markers, validator) are registered here as they are built.

const _AUTOLOADS: Array[Array] = [
	["TacticsEvents", "res://addons/tactics_core/core/events.gd"],
	["TacticsRng", "res://addons/tactics_core/core/tactics_rng.gd"],
	["RulesetProvider", "res://addons/tactics_core/core/ruleset_provider.gd"],
	["SceneRouter", "res://addons/tactics_core/core/scene_router.gd"],
]


func _enable_plugin() -> void:
	for entry: Array in _AUTOLOADS:
		var autoload_name: String = entry[0]
		if not ProjectSettings.has_setting("autoload/" + autoload_name):
			add_autoload_singleton(autoload_name, entry[1])
	_register_setting(TacticsIds.SETTING_DEFAULT_RULESET, "", TYPE_STRING, PROPERTY_HINT_FILE, "*.tres,*.res")
	_register_setting(TacticsIds.SETTING_LOG_LEVEL, TacticsLog.Level.DEBUG, TYPE_INT, PROPERTY_HINT_ENUM, "Debug,Info,Warn,Error,None")
	ProjectSettings.save()


func _disable_plugin() -> void:
	for i: int in range(_AUTOLOADS.size() - 1, -1, -1):
		remove_autoload_singleton(_AUTOLOADS[i][0])


func _register_setting(path: String, default_value: Variant, type: Variant.Type, hint: PropertyHint, hint_string: String) -> void:
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, default_value)
	ProjectSettings.set_initial_value(path, default_value)
	ProjectSettings.add_property_info({"name": path, "type": type, "hint": hint, "hint_string": hint_string})
