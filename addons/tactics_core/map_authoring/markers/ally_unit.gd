@tool
class_name AllyUnit
extends UnitMarker
## An allied NPC unit (faction "ally" by default).


func _init() -> void:
	faction_id = &"ally"
	marker_color = Color(0.3, 0.75, 0.35)
