extends Node
## Holds the active [Ruleset], registered as the [code]RulesetProvider[/code]
## autoload.
##
## On startup it loads the ruleset named by the project setting
## [code]tactics_core/ruleset/default_path[/code] (see [TacticsIds]). Games
## or tests can swap rulesets at runtime with [method set_ruleset]; listeners
## are notified through [signal TacticsEvents.ruleset_changed].

var _ruleset: Ruleset = null


func _ready() -> void:
	var path: String = str(ProjectSettings.get_setting(TacticsIds.SETTING_DEFAULT_RULESET, ""))
	if path.is_empty():
		TacticsLog.info("RulesetProvider", "No default ruleset configured")
		return
	load_ruleset(path)


## Loads the ruleset at [param path] and makes it active. Returns false if
## the file is missing or is not a [Ruleset].
func load_ruleset(path: String) -> bool:
	if not ResourceLoader.exists(path):
		TacticsLog.warn("RulesetProvider", "Ruleset not found: %s" % path)
		return false
	var loaded: Resource = ResourceLoader.load(path)
	if not (loaded is Ruleset):
		TacticsLog.warn("RulesetProvider", "Resource is not a Ruleset: %s" % path)
		return false
	set_ruleset(loaded as Ruleset)
	return true


## Makes [param ruleset] active. Validation problems are logged but do not
## block activation, so content errors degrade instead of crashing.
func set_ruleset(ruleset: Ruleset) -> void:
	if ruleset == null:
		TacticsLog.error("RulesetProvider", "set_ruleset called with null")
		return
	for problem: String in ruleset.validate():
		TacticsLog.warn("RulesetProvider", problem)
	_ruleset = ruleset
	TacticsEvents.ruleset_changed.emit(_ruleset)


## Returns true once a ruleset is active.
func has_ruleset() -> bool:
	return _ruleset != null


## The active ruleset, or null (with an error) if none is set.
func get_ruleset() -> Ruleset:
	if _ruleset == null:
		TacticsLog.error("RulesetProvider", "No ruleset is active")
	return _ruleset
