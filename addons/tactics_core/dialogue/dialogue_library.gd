class_name DialogueLibrary
extends RefCounted
## Loads every scene from the dialogue folders, choosing each file's best
## locale: files are named [code]name.<locale>.dlg[/code]; for each name the
## current locale wins, then the fallback locale, then an unsuffixed
## [code]name.dlg[/code].

## Project setting listing the dialogue folders.
const SETTING_DIRECTORIES: String = "tactics_core/dialogue/directories"
const DEFAULT_DIRECTORIES: PackedStringArray = ["res://game/dialogue"]
const FALLBACK_LOCALE: String = "en"

var scripts: Dictionary[StringName, DialogueScript] = {}
var errors: PackedStringArray = []


## Loads the configured folders for [param locale] (default: current locale).
static func load_project(locale: String = "") -> DialogueLibrary:
	var library := DialogueLibrary.new()
	var directories: PackedStringArray = ProjectSettings.get_setting(SETTING_DIRECTORIES, DEFAULT_DIRECTORIES)
	var language: String = locale if not locale.is_empty() else TranslationServer.get_locale().get_slice("_", 0)
	for directory: String in directories:
		library.load_directory(directory, language)
	return library


## Loads [param directory] (and subfolders) for [param locale].
func load_directory(directory: String, locale: String) -> void:
	var chosen: Dictionary[String, String] = {}
	var rank: Dictionary[String, int] = {}
	for path: String in _dlg_files(directory):
		var file: String = path.get_file().trim_suffix(".dlg")
		var parts: PackedStringArray = file.rsplit(".", true, 1)
		var base: String = parts[0] if parts.size() == 2 else file
		var file_locale: String = parts[1] if parts.size() == 2 else ""
		var score: int = 3 if file_locale == locale else 2 if file_locale == FALLBACK_LOCALE else 1 if file_locale.is_empty() else 0
		var key: String = path.get_base_dir().path_join(base)
		if score > 0 and score > rank.get(key, 0):
			rank[key] = score
			chosen[key] = path
	for key: String in chosen:
		var parsed: DialogueParser.Result = DialogueParser.parse_file(chosen[key])
		errors.append_array(parsed.errors)
		for scene_id: StringName in parsed.scripts:
			if scripts.has(scene_id):
				errors.append("%s: scene '%s' already defined in %s" % [chosen[key], scene_id, scripts[scene_id].source])
			scripts[scene_id] = parsed.scripts[scene_id]


func get_script_by_id(scene_id: StringName) -> DialogueScript:
	return scripts.get(scene_id, null)


func has_scene(scene_id: StringName) -> bool:
	return scripts.has(scene_id)


static func _dlg_files(directory: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	for sub: String in dir.get_directories():
		result.append_array(_dlg_files(directory.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".dlg"):
			result.append(directory.path_join(file))
	return result
