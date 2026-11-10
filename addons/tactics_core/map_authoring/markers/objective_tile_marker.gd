@tool
class_name ObjectiveTileMarker
extends MapMarker
## Base for tiles that create objectives (seize, defend, escape).


## Optional translation key for the objective text (e.g. "Seize the toll camp").
@export var label: String = ""


## The objective this tile adds, or null.
func objective() -> Objective:
	var result: Objective = _make_objective()
	if result != null:
		result.label = label
	return result


## Subclasses create their objective here.
func _make_objective() -> Objective:
	return null
