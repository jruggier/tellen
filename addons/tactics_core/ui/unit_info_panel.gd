class_name UnitInfoPanel
extends PanelContainer
## Unit info (spec §14): name, class, level, HP, equipped weapon and status.
## Expanded (the [code]info[/code] action) it adds every stat, inventory and
## proficiencies. Reads only [UnitState] and the ruleset.

var expanded: bool = false
var _box := VBoxContainer.new()


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param unit] (null hides the panel).
func show_unit(unit: UnitState, state: BattleState) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	visible = unit != null
	if unit == null:
		return
	var ruleset: Ruleset = state.ruleset
	var faction: FactionData = state.get_faction(unit.faction_id)
	_box.add_child(UiStyle.label(unit.get_display_name(), 32, faction.color.lightened(0.35) if faction != null else Color.WHITE))
	var class_text: String = unit.class_data.get_display_name() if unit.class_data != null else ""
	var exp_text: String = ("   %s %d" % [tr("UI_EXP"), unit.experience]) if faction != null and faction.gains_experience else ""
	_box.add_child(UiStyle.label("%s   %s %d%s" % [class_text, tr("UI_LEVEL"), unit.level, exp_text], 24, UiStyle.TEXT_DIM))
	var hp_color: Color = UiStyle.GOOD if unit.current_hp * 2 > unit.max_hp(ruleset) else UiStyle.WARN if unit.current_hp * 4 > unit.max_hp(ruleset) else UiStyle.BAD
	_box.add_child(UiStyle.label("%s %d / %d" % [tr("FORECAST_HP"), unit.current_hp, unit.max_hp(ruleset)], 26, hp_color))
	var weapon: WeaponData = unit.equipped_weapon()
	_box.add_child(UiStyle.label(weapon.get_display_name() if weapon != null else tr("UI_UNARMED"), 24))
	if unit.is_staggered():
		_box.add_child(UiStyle.label(tr("UI_STATUS_STAGGERED"), 24, UiStyle.WARN))
	if unit.is_boss:
		_box.add_child(UiStyle.label(tr("UI_BOSS"), 24, UiStyle.BAD))
	if expanded:
		_add_details(unit, ruleset)
	reset_size()


func _add_details(unit: UnitState, ruleset: Ruleset) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	for definition: StatDefinition in ruleset.stats:
		grid.add_child(UiStyle.label(definition.get_abbreviation(), 22, UiStyle.TEXT_DIM))
		grid.add_child(UiStyle.label(str(unit.stats.get_value(definition.id)), 24))
	_box.add_child(grid)
	_box.add_child(UiStyle.label(tr("UI_INVENTORY"), 22, UiStyle.TEXT_DIM))
	for slot: InventorySlot in unit.inventory:
		var text: String = slot.item.get_display_name()
		if slot.uses >= 0:
			text += "  %d" % slot.uses
		if slot.drops:
			text += "  (%s)" % tr("UI_DROPS")
		_box.add_child(UiStyle.label(text, 22))
	if not unit.proficiencies.is_empty():
		var parts: PackedStringArray = []
		for proficiency_id: StringName in unit.proficiencies:
			parts.append("%s %d" % [proficiency_id, unit.proficiencies[proficiency_id]])
		_box.add_child(UiStyle.label("%s: %s" % [tr("UI_PROFICIENCY"), ", ".join(parts)], 20, UiStyle.TEXT_DIM))
