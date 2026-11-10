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
	_box.add_child(UiStyle.label("%s   %s %d" % [class_text, tr("UI_LEVEL"), unit.level], 24, UiStyle.TEXT_DIM))
	var max_hp: int = unit.max_hp(ruleset)
	_box.add_child(_bar_row(tr("FORECAST_HP"), unit.current_hp, max_hp, "%d / %d" % [unit.current_hp, max_hp], Color(), true, 26))
	if faction != null and faction.gains_experience:
		_box.add_child(_bar_row(tr("UI_EXP"), unit.experience, ruleset.exp_per_level, str(unit.experience), Color(0.4, 0.75, 1.0), false, 22))
	var weapon: WeaponData = unit.equipped_weapon()
	_box.add_child(UiStyle.label(weapon.get_display_name() if weapon != null else tr("UI_UNARMED"), 24))
	var skills: Array[SkillData] = SkillRunner.active_skills(unit)
	if not skills.is_empty():
		var names: PackedStringArray = []
		for skill: SkillData in skills:
			names.append(skill.get_display_name())
		_box.add_child(UiStyle.label("%s: %s" % [tr("UI_SKILLS"), ", ".join(names)], 22, UiStyle.TEXT_DIM))
	if unit.awakening != null and state.ruleset.awakening_rule != null:
		var status: String = state.ruleset.awakening_rule.status_text(state, unit)
		if not status.is_empty():
			_box.add_child(UiStyle.label("%s: %s" % [unit.awakening.get_display_name(), status], 22, unit.awakening.color))
	if unit.is_staggered():
		_box.add_child(UiStyle.label(tr("UI_STATUS_STAGGERED"), 24, UiStyle.WARN))
	if unit.is_boss:
		_box.add_child(UiStyle.label(tr("UI_BOSS"), 24, UiStyle.BAD))
	if expanded:
		_add_details(unit, ruleset)
	reset_size()


## A label, a bar and its numbers on one line.
func _bar_row(caption: String, value: int, max_value: int, numbers: String, color: Color, by_ratio: bool, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var caption_label := UiStyle.label(caption, font_size - 2, UiStyle.TEXT_DIM)
	caption_label.custom_minimum_size = Vector2(46, 0)
	row.add_child(caption_label)
	var bar := StatBar.new()
	bar.custom_minimum_size = Vector2(190, 16 if by_ratio else 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.color_by_ratio = by_ratio
	if not by_ratio:
		bar.fill_color = color
	bar.set_values(value, maxi(1, max_value))
	row.add_child(bar)
	var ratio: float = float(value) / maxf(1.0, max_value)
	row.add_child(UiStyle.label(numbers, font_size, StatBar.hp_color(ratio) if by_ratio else color))
	return row


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
