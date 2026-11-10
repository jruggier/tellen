@tool
extends EditorScript
## Editor tool: validates the default ruleset and all content data.
##
## Open this script in the Script editor and use File → Run (Ctrl+Shift+X).
## Problems are printed to the Output panel.


func _run() -> void:
	var path: String = str(ProjectSettings.get_setting(TacticsIds.SETTING_DEFAULT_RULESET, ""))
	var ruleset: Ruleset = load(path) as Ruleset if not path.is_empty() else null
	var problems: PackedStringArray = DataValidator.validate_project(ruleset)
	if problems.is_empty():
		print("[DataValidator] All content data is valid.")
		return
	for problem: String in problems:
		push_warning("[DataValidator] " + problem)
	print("[DataValidator] %d problem(s) found." % problems.size())
