@tool
class_name TacticsData
extends Resource
## Base class for every authored content resource (stats, classes, weapons,
## terrain, units...).
##
## [member display_name] and [member description] hold translation keys
## (e.g. [code]WEAPON_IRON_SWORD_NAME[/code]); read them through
## [method get_display_name] / [method get_description] so they are localized.
##
## Subclasses override [method validate] and append their own problems after
## calling [code]super()[/code]. The data validator runs it on all content.

## Stable identifier used in saves, references and logs. Never shown to players.
@export var id: StringName = &""

## Translation key for the player-facing name.
@export var display_name: String = ""

## Translation key for the player-facing description.
@export_multiline var description: String = ""


## The localized name (falls back to the id if no name key is set).
func get_display_name() -> String:
	if display_name.is_empty():
		return String(id)
	return tr(display_name)


## The localized description.
func get_description() -> String:
	return tr(description) if not description.is_empty() else ""


## Returns a list of problems (empty when valid). Each line names the resource.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("%s: missing id" % _label())
	return problems


## A short label for validation messages: "ClassName 'id' (path)".
func _label() -> String:
	var script_name: String = "TacticsData"
	var script: Script = get_script() as Script
	if script != null and not script.get_global_name().is_empty():
		script_name = script.get_global_name()
	var where: String = (" (%s)" % resource_path) if not resource_path.is_empty() else ""
	return "%s '%s'%s" % [script_name, id, where]
