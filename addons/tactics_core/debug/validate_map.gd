@tool
extends EditorScript
## Editor tool: validates the map scene currently open in the editor.
##
## Open the map, then open this script in the Script editor and use
## File → Run (Ctrl/Cmd+Shift+X). Problems are printed to the Output panel.


func _run() -> void:
	var map: BattleMap = get_scene() as BattleMap
	if map == null:
		push_warning("[MapValidator] The open scene's root is not a BattleMap.")
		return
	var ruleset_path: String = str(ProjectSettings.get_setting(TacticsIds.SETTING_DEFAULT_RULESET, ""))
	var ruleset: Ruleset = load(ruleset_path) as Ruleset if not ruleset_path.is_empty() else null
	var roster_path: String = str(ProjectSettings.get_setting("tactics_core/maps/test_roster", "res://game/data/units/test_roster.tres"))
	var roster: Array[UnitData] = []
	if ResourceLoader.exists(roster_path):
		var test_roster: UnitRoster = load(roster_path) as UnitRoster
		if test_roster != null:
			roster = test_roster.units
	var problems: PackedStringArray = MapValidator.validate(map, ruleset, roster)
	if problems.is_empty():
		print("[MapValidator] %s: no problems found." % map.name)
		return
	for problem: String in problems:
		push_warning("[MapValidator] " + problem)
	print("[MapValidator] %s: %d problem(s); see the warnings above." % [map.name, problems.size()])
