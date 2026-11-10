@tool
class_name UnitRoster
extends TacticsData
## A list of units available to deploy (test rosters; the campaign roster
## in M8 is built from the same units).

@export var units: Array[UnitData] = []


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	if units.has(null):
		problems.append("%s: contains an empty entry" % _label())
	return problems
