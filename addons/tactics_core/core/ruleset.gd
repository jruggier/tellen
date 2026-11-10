@tool
class_name Ruleset
extends Resource
## The complete set of rules and tuning numbers for one game.
##
## A game ships one Ruleset resource (.tres) that wires together its concrete
## rule classes ([code]CombatRules[/code], [code]GrowthRules[/code],
## [code]ExpRules[/code], [code]AwakeningRule[/code], [code]EnemyStatRules[/code])
## and every tuning constant. Framework logic reads numbers from here and
## never hardcodes them. A different game swaps the Ruleset, not the engine.
##
## Fields are added milestone by milestone as the systems that read them are
## built (combat and progression in M1).

## Stable identifier, e.g. [code]&"crossroads"[/code].
@export var ruleset_id: StringName = &""

## Human-readable name shown in debug tools.
@export var display_name: String = ""


## Returns a list of problems with this ruleset (empty when valid). Used by
## [code]DataValidator[/code] and when a ruleset is activated.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if ruleset_id == &"":
		problems.append("Ruleset has no ruleset_id")
	return problems
