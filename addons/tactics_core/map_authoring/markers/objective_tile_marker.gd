@tool
class_name ObjectiveTileMarker
extends MapMarker
## Base for tiles that create objectives (seize, defend, escape).


## The objective this tile adds, or null.
func objective() -> Objective:
	return null
