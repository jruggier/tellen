class_name ForecastPanel
extends PanelContainer
## Combat forecast panel (spec §14). Reads only [CombatForecast] (plus
## names, weapons, terrain and rule details), so it always matches the
## resolver. A details toggle adds weapon and rule internals.
##
## Also shows a healing preview through [method show_heal].

var _grid := GridContainer.new()
var _footer := UiStyle.label("", 22, UiStyle.TEXT_DIM)


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var box := VBoxContainer.new()
	add_child(box)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 2)
	box.add_child(_grid)
	box.add_child(_footer)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param forecast]. [param sides] holds per-side display data:
## [code]{"name", "color", "weapon", "terrain": TerrainData}[/code] for
## "attacker" and "defender". [param details] are label key → value pairs
## for each side, shown when [param show_details] is set.
func show_forecast(forecast: CombatForecast, sides: Dictionary, details: Array[Dictionary], show_details: bool) -> void:
	_clear()
	var a: CombatForecast.SideForecast = forecast.attacker
	var d: CombatForecast.SideForecast = forecast.defender
	var a_info: Dictionary = sides["attacker"]
	var d_info: Dictionary = sides["defender"]
	_row("", str(a_info["name"]), str(d_info["name"]), 30, a_info["color"], d_info["color"])
	_row("", str(a_info["weapon"]), str(d_info["weapon"]), 22, UiStyle.TEXT_DIM, UiStyle.TEXT_DIM)
	_grid.add_child(UiStyle.label(tr("FORECAST_HP"), 22, UiStyle.TEXT_DIM))
	_grid.add_child(_hp_cell(a.hp, a.hp_after_all_hits, int(a_info.get("max_hp", a.hp))))
	_grid.add_child(_hp_cell(d.hp, d.hp_after_all_hits, int(d_info.get("max_hp", d.hp))))
	_row(tr("FORECAST_DAMAGE"), _damage(a), _damage(d), 28, UiStyle.WARN if a.effective else Color.WHITE, UiStyle.WARN if d.effective else Color.WHITE)
	_row(tr("FORECAST_HIT"), _pct(a, a.hit), _pct(d, d.hit))
	_row(tr("FORECAST_CRIT"), _pct(a, a.crit), _pct(d, d.crit))
	_row(tr("FORECAST_FOLLOW_UP"), _follow(a), _follow(d))
	var a_status: String = tr("FORECAST_STAGGER_ON_HIT") if forecast.stagger_on_hit else ""
	var d_status: String = ""
	if a.staggered:
		a_status = tr("FORECAST_STAGGERED")
	if d.staggered or forecast.stagger_on_hit:
		d_status = tr("FORECAST_CANT_FOLLOW_UP") if d.staggered else tr("FORECAST_CANT_FOLLOW_UP_IF_HIT")
	if not a_status.is_empty() or not d_status.is_empty():
		_row("", a_status, d_status, 22, UiStyle.WARN, UiStyle.WARN)
	_row(tr("FORECAST_TERRAIN"), _terrain(a_info.get("terrain")), _terrain(d_info.get("terrain")), 22, UiStyle.TEXT_DIM, UiStyle.TEXT_DIM)
	if int(a_info.get("awaken_gain", 0)) > 0:
		_row(tr("FORECAST_AWAKEN"), "+%d" % int(a_info["awaken_gain"]), "", 22, Color(0.6, 0.9, 1.0), Color.WHITE)
	if int(a_info.get("chain", 0)) > 0:
		_row(tr("FORECAST_CHAIN"), tr("FORECAST_CHAIN_VALUE") % [int(a_info["chain"]), int(a_info.get("chain_count", 0))], "", 22, UiStyle.GOOD, Color.WHITE)
	if show_details and details.size() == 2:
		for key: String in details[0]:
			_row(tr(key), str(details[0][key]), str(details[1].get(key, "")), 22, UiStyle.TEXT_DIM, UiStyle.TEXT_DIM)
	_footer.text = InputHints.fill(tr("FORECAST_FOOTER_DETAILS_ON") if show_details else tr("FORECAST_FOOTER_DETAILS_OFF"))
	if a.follow_up_cancelled_by_stagger or d.follow_up_cancelled_by_stagger:
		_footer.text += "      " + tr("FORECAST_FOOTNOTE_STAGGER")
	visible = true
	size = Vector2.ZERO
	reset_size()


## Shows a healing preview: [param name] goes from [param hp_before] to [param hp_after].
func show_heal(target_name: String, color: Color, hp_before: int, hp_after: int, max_hp: int) -> void:
	_clear()
	_row("", target_name, "", 30, color, color)
	_grid.add_child(UiStyle.label(tr("FORECAST_HP"), 22, UiStyle.TEXT_DIM))
	_grid.add_child(_hp_cell(hp_before, hp_after, max_hp))
	_grid.add_child(Control.new())
	_footer.text = ""
	visible = true
	reset_size()


func _clear() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


## "HP → after" over an HP bar whose predicted change pulses.
func _hp_cell(hp: int, after: int, max_hp: int) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var color: Color = UiStyle.BAD if after == 0 else (UiStyle.GOOD if after > hp else Color.WHITE)
	cell.add_child(UiStyle.label("%d → %d" % [hp, after], 28, color))
	var bar := StatBar.new()
	bar.custom_minimum_size = Vector2(200, 14)
	bar.color_by_ratio = true
	bar.set_values(hp, maxi(1, max_hp))
	bar.set_preview(after)
	cell.add_child(bar)
	return cell


func _row(label_text: String, a: String, b: String, size: int = 26, a_color: Color = Color.WHITE, b_color: Color = Color.WHITE) -> void:
	_grid.add_child(UiStyle.label(label_text, 22, UiStyle.TEXT_DIM))
	_grid.add_child(UiStyle.label(a, size, a_color))
	_grid.add_child(UiStyle.label(b, size, b_color))


static func _damage(side: CombatForecast.SideForecast) -> String:
	if not side.can_strike:
		return "—"
	var text: String = str(side.damage)
	if side.strikes_per_turn > 1:
		text += " ×%d" % side.strikes_per_turn
	if side.effective:
		text += "  !"
	return text


static func _pct(side: CombatForecast.SideForecast, value: int) -> String:
	return "%d%%" % value if side.can_strike else "—"


static func _follow(side: CombatForecast.SideForecast) -> String:
	if side.follow_up_percent <= 0:
		return "—"
	var text: String = "+%d (%d%%)" % [side.follow_up_damage, side.follow_up_percent]
	return text + " *" if side.follow_up_cancelled_by_stagger else text


func _terrain(terrain: Variant) -> String:
	var data: TerrainData = terrain as TerrainData
	if data == null:
		return "—"
	var bonuses: PackedStringArray = []
	if data.avoid_bonus != 0:
		bonuses.append("%s %+d" % [tr("UI_TERRAIN_AVOID"), data.avoid_bonus])
	if data.defense_bonus != 0:
		bonuses.append("%s %+d" % [tr("UI_TERRAIN_DEF"), data.defense_bonus])
	return data.get_display_name() + ("  " + " ".join(bonuses) if not bonuses.is_empty() else "")
