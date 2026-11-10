@tool
class_name StatDefinition
extends TacticsData
## Defines one stat a game uses (e.g. HP, Strength, Movement).
##
## The framework never assumes a particular stat exists; rule classes read
## the stats they need by [member TacticsData.id]. The active [Ruleset] lists
## every StatDefinition the game uses.

## Translation key for the short label shown in tight UI (e.g. "Str").
@export var abbreviation: String = ""

## True if level-ups can raise this stat (rolled from growths).
@export var growable: bool = true

## Cap used when a class does not define one for this stat.
@export var default_cap: int = 99

## Lowest value the stat can have after modifiers.
@export var min_value: int = 0


## The localized abbreviation (falls back to the id).
func get_abbreviation() -> String:
	return tr(abbreviation) if not abbreviation.is_empty() else String(id)


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if default_cap < min_value:
		problems.append("%s: default_cap %d is below min_value %d" % [_label(), default_cap, min_value])
	return problems
