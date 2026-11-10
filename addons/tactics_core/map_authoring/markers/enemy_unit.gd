@tool
class_name EnemyUnit
extends UnitMarker
## An enemy unit (faction "enemy" by default).


func _init() -> void:
	faction_id = &"enemy"
	marker_color = Color(0.85, 0.25, 0.25)
