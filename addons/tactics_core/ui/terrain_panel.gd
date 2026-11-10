class_name TerrainPanel
extends PanelContainer
## Shows the terrain under the cursor: name and bonuses (§14).

var _name_label := Label.new()
var _stats_label := Label.new()


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	_name_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_name_label)
	_stats_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_stats_label)
	custom_minimum_size = Vector2(220, 0)


## Shows [param terrain] (hidden for void cells).
func show_terrain(terrain: TerrainData) -> void:
	visible = terrain != null
	if terrain == null:
		return
	_name_label.text = terrain.get_display_name()
	var parts: PackedStringArray = ["%s %+d" % [tr("UI_TERRAIN_AVOID"), terrain.avoid_bonus], "%s %+d" % [tr("UI_TERRAIN_DEF"), terrain.defense_bonus]]
	if terrain.resistance_bonus != terrain.defense_bonus:
		parts.append("%s %+d" % [tr("UI_TERRAIN_RES"), terrain.resistance_bonus])
	if terrain.heal_percent > 0:
		parts.append("%s %d%%" % [tr("UI_TERRAIN_HEAL"), terrain.heal_percent])
	_stats_label.text = "   ".join(parts)
