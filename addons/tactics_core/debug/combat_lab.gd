extends Control
## Combat Lab: a debug tool for tuning combat numbers (spec §13.3).
##
## Pick two units (named units, or generic units of any class) with levels,
## weapons and terrain; every stat stays editable for ad-hoc tests. The
## forecast updates live, and "Simulate" runs N seeded combats to report
## win rate, damage, crit rate, Stagger rate and follow-up frequency.
##
## Game-agnostic: it lists whatever stats, units, classes, weapons and
## terrain the active ruleset and data folders contain. Debug builds only.
## The lab renders at native window resolution (not the game's low base
## resolution) so its many fields stay readable; the previous scaling is
## restored when it closes.

const FONT_SIZE: int = 16

var _ruleset: Ruleset
var _units: Array[UnitData] = []
var _classes: Array[ClassData] = []
var _weapons: Array[WeaponData] = []
var _terrains: Array[TerrainData] = []
var _attacker: LabSide
var _defender: LabSide
var _distance: SpinBox
var _forecast_label: RichTextLabel
var _sim_count: SpinBox
var _sim_seed: SpinBox
var _sim_label: RichTextLabel
var _saved_scale_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_DISABLED


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if not OS.is_debug_build():
		var label := Label.new()
		label.text = "The Combat Lab is only available in debug builds."
		add_child(label)
		return
	_saved_scale_mode = get_tree().root.content_scale_mode
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_apply_theme()
	_ruleset = RulesetProvider.get_ruleset()
	if _ruleset == null:
		var error_label := Label.new()
		error_label.text = "No active ruleset (set tactics_core/ruleset/default_path)."
		add_child(error_label)
		return
	_load_content()
	_build_ui()
	_attacker.select_source(_default_attacker_index())
	_defender.select_source(mini(_units.size(), _defender.source_count() - 1))
	_refresh()


## The lord (protagonist) if there is one, else the first unit.
func _default_attacker_index() -> int:
	for i: int in _units.size():
		if _units[i].is_lord:
			return i
	return 0


func _exit_tree() -> void:
	if OS.is_debug_build():
		get_tree().root.content_scale_mode = _saved_scale_mode


# Content -------------------------------------------------------------------------

func _load_content() -> void:
	var directories: PackedStringArray = ProjectSettings.get_setting(DataValidator.SETTING_DATA_DIRECTORIES, DataValidator.DEFAULT_DATA_DIRECTORIES)
	for directory: String in directories:
		_scan(directory)
	var by_id: Callable = func(a: TacticsData, b: TacticsData) -> bool: return String(a.id) < String(b.id)
	_units.sort_custom(by_id)
	_classes.sort_custom(by_id)
	_weapons.sort_custom(by_id)
	_terrains.sort_custom(by_id)


func _scan(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(directory.path_join(sub))
	for file: String in dir.get_files():
		var path: String = directory.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var resource: Resource = load(path)
		if resource is UnitData:
			_units.append(resource as UnitData)
		elif resource is ClassData:
			_classes.append(resource as ClassData)
		elif resource is WeaponData:
			_weapons.append(resource as WeaponData)
		elif resource is TerrainData:
			_terrains.append(resource as TerrainData)


# UI --------------------------------------------------------------------------------

func _apply_theme() -> void:
	var base_path: String = str(ProjectSettings.get_setting("gui/theme/custom", ""))
	var lab_theme: Theme = (load(base_path) as Theme).duplicate() as Theme if not base_path.is_empty() else Theme.new()
	lab_theme.default_font_size = FONT_SIZE
	theme = lab_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.1, 0.13)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Combat Lab  —  ruleset: %s" % (_ruleset.display_name if not _ruleset.display_name.is_empty() else String(_ruleset.ruleset_id))
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	_attacker = LabSide.new("Attacker", _ruleset, _units, _classes, _weapons, _terrains)
	_defender = LabSide.new("Defender", _ruleset, _units, _classes, _weapons, _terrains)
	_attacker.changed.connect(_refresh)
	_defender.changed.connect(_refresh)
	columns.add_child(_attacker)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_stretch_ratio = 1.4
	middle.add_theme_constant_override("separation", 8)
	columns.add_child(middle)
	columns.add_child(_defender)

	var controls := HBoxContainer.new()
	middle.add_child(controls)
	controls.add_child(_label("Distance"))
	_distance = _spin(1, 10, 1)
	_distance.value_changed.connect(func(_v: float) -> void: _refresh())
	controls.add_child(_distance)
	var swap := Button.new()
	swap.text = "Swap sides"
	swap.pressed.connect(_swap)
	controls.add_child(swap)

	_forecast_label = _rich_label()
	_forecast_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_forecast_label.size_flags_stretch_ratio = 3.0
	middle.add_child(_forecast_label)

	var sim_row := HBoxContainer.new()
	middle.add_child(sim_row)
	sim_row.add_child(_label("Combats"))
	_sim_count = _spin(1, 100000, 1000)
	sim_row.add_child(_sim_count)
	sim_row.add_child(_label("Seed"))
	_sim_seed = _spin(0, 999999, 1)
	sim_row.add_child(_sim_seed)
	var run_button := Button.new()
	run_button.text = "Simulate"
	run_button.pressed.connect(_simulate)
	sim_row.add_child(run_button)

	_sim_label = _rich_label()
	_sim_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_sim_label)
	_sim_label.text = "Press Simulate to run seeded combats with the current setup."


func _swap() -> void:
	var a_state: Dictionary = _attacker.get_state()
	_attacker.set_state(_defender.get_state())
	_defender.set_state(a_state)
	_refresh()


# Forecast and simulation ----------------------------------------------------------

func _refresh() -> void:
	if _attacker == null or _defender == null:
		return
	var a: CombatParticipant = _attacker.build_participant()
	var d: CombatParticipant = _defender.build_participant()
	var rules: CombatRules = _ruleset.combat_rules
	var distance: int = int(_distance.value)
	var forecast: CombatForecast = CombatForecast.calculate(rules, a, d, distance)
	var text: String = "[b]Forecast[/b]  (distance %d)\n[table=3]" % distance
	text += _row("", "[b]%s[/b]" % _attacker.unit_name(), "[b]%s[/b]" % _defender.unit_name())
	text += _row("HP", "%d → %d" % [forecast.attacker.hp, forecast.attacker.hp_after_all_hits], "%d → %d" % [forecast.defender.hp, forecast.defender.hp_after_all_hits])
	text += _row("Damage", _dmg(forecast.attacker), _dmg(forecast.defender))
	text += _row("Hit", _pct(forecast.attacker, forecast.attacker.hit), _pct(forecast.defender, forecast.defender.hit))
	text += _row("Crit", _pct(forecast.attacker, forecast.attacker.crit), _pct(forecast.defender, forecast.defender.crit))
	text += _row("Strikes", str(forecast.attacker.total_strikes), str(forecast.defender.total_strikes))
	text += _row("Follow-up", _follow(forecast.attacker), _follow(forecast.defender))
	text += _row("Effective", "yes" if forecast.attacker.effective else "", "yes" if forecast.defender.effective else "")
	text += _row("Staggered (carried)", "yes" if forecast.attacker.staggered else "", "yes" if forecast.defender.staggered else "")
	text += _row("Expected dmg taken", "%.1f" % forecast.attacker.expected_damage_taken, "%.1f" % forecast.defender.expected_damage_taken)
	text += "[/table]\n"
	text += "[b]Stagger on hit:[/b] %s\n\n" % ("YES — defender cannot follow up this combat or its next" if forecast.stagger_on_hit else "no")
	var a_details: Dictionary[String, String] = rules.debug_details(a, d)
	var d_details: Dictionary[String, String] = rules.debug_details(d, a)
	if not a_details.is_empty():
		text += "[b]Details[/b]\n[table=3]"
		for key: String in a_details:
			text += _row(key, a_details[key], d_details.get(key, ""))
		text += "[/table]"
	_forecast_label.text = text


func _simulate() -> void:
	var a: CombatParticipant = _attacker.build_participant()
	var d: CombatParticipant = _defender.build_participant()
	var count: int = int(_sim_count.value)
	var started: int = Time.get_ticks_msec()
	var s: CombatSimulation.Summary = CombatSimulation.run(_ruleset.combat_rules, a, d, int(_distance.value), count, int(_sim_seed.value))
	var elapsed: int = Time.get_ticks_msec() - started
	var text: String = "[b]Simulation[/b]  %d combats, seeds %d–%d (%d ms)\n[table=3]" % [count, int(_sim_seed.value), int(_sim_seed.value) + count - 1, elapsed]
	text += _row("", "[b]%s[/b]" % _attacker.unit_name(), "[b]%s[/b]" % _defender.unit_name())
	text += _row("Kills (win rate)", "%.1f%%" % s.attacker_win_pct(), "%.1f%%" % s.defender_win_pct())
	text += _row("Avg damage dealt", "%.2f" % s.attacker_avg_damage(), "%.2f" % s.defender_avg_damage())
	text += _row("Crit rate (of hits)", "%.1f%%" % s.attacker_crit_pct(), "%.1f%%" % s.defender_crit_pct())
	text += _row("Followed up", "%.1f%%" % s.attacker_follow_up_pct(), "%.1f%%" % s.defender_follow_up_pct())
	text += "[/table]\n"
	text += "Both survive: %.1f%%    Stagger rate: %.1f%%" % [s.both_survive_pct(), s.stagger_pct()]
	_sim_label.text = text


func _row(label: String, a: String, b: String) -> String:
	return "[cell]%s   [/cell][cell]%s   [/cell][cell]%s[/cell]" % [label, a, b]


func _dmg(side: CombatForecast.SideForecast) -> String:
	if not side.can_strike:
		return "—"
	var text: String = str(side.damage)
	if side.strikes_per_turn > 1:
		text += " ×%d" % side.strikes_per_turn
	return text + "  (crit %d)" % side.crit_damage


func _pct(side: CombatForecast.SideForecast, value: int) -> String:
	return "%d%%" % value if side.can_strike else "—"


func _follow(side: CombatForecast.SideForecast) -> String:
	if side.follow_up_percent <= 0:
		return "—"
	var text: String = "+%d (%d%%)" % [side.follow_up_damage, side.follow_up_percent]
	if side.follow_up_cancelled_by_stagger:
		text += " [color=orange]only if not Staggered[/color]"
	return text


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


static func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size.x = 110
	return spin


static func _rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.custom_minimum_size.y = 200
	return label


## One column of the lab: a unit source, level, weapon, terrain and stats.
class LabSide:
	extends VBoxContainer

	signal changed

	var _ruleset: Ruleset
	var _units: Array[UnitData]
	var _classes: Array[ClassData]
	var _weapons: Array[WeaponData]
	var _terrains: Array[TerrainData]
	var _sources: Array[TacticsData] = []
	var _source: OptionButton
	var _level: SpinBox
	var _weapon: OptionButton
	var _terrain: OptionButton
	var _hp: SpinBox
	var _staggered: CheckBox
	var _stats: Dictionary[StringName, SpinBox] = {}
	var _quiet: bool = false

	func _init(title: String, ruleset: Ruleset, units: Array[UnitData], classes: Array[ClassData], weapons: Array[WeaponData], terrains: Array[TerrainData]) -> void:
		_ruleset = ruleset
		_units = units
		_classes = classes
		_weapons = weapons
		_terrains = terrains
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("separation", 6)
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 20)
		add_child(heading)

		var grid := GridContainer.new()
		grid.columns = 2
		add_child(grid)
		_source = OptionButton.new()
		for unit: UnitData in units:
			_sources.append(unit)
			_source.add_item("Unit: %s" % unit.get_display_name() if unit.character != null else "Unit: %s (%s)" % [unit.get_display_name(), unit.id])
		for class_data: ClassData in classes:
			_sources.append(class_data)
			_source.add_item("Generic: %s" % class_data.get_display_name())
		_source.item_selected.connect(func(index: int) -> void: select_source(index))
		_add_field(grid, "Source", _source)
		_level = CombatLabSpin.make(1, ruleset.level_cap, 1)
		_level.value_changed.connect(func(_v: float) -> void: _recompute_stats())
		_add_field(grid, "Level", _level)
		_weapon = OptionButton.new()
		_weapon.add_item("(unarmed)")
		for weapon: WeaponData in weapons:
			_weapon.add_item("%s  [%s]" % [weapon.get_display_name(), weapon.weapon_type.id if weapon.weapon_type != null else &"?"])
		_weapon.item_selected.connect(func(_i: int) -> void: _emit())
		_add_field(grid, "Weapon", _weapon)
		_terrain = OptionButton.new()
		_terrain.add_item("(none)")
		for terrain: TerrainData in terrains:
			_terrain.add_item(terrain.get_display_name())
		_terrain.item_selected.connect(func(_i: int) -> void: _emit())
		_add_field(grid, "Terrain", _terrain)
		_hp = CombatLabSpin.make(1, 999, 20)
		_hp.value_changed.connect(func(_v: float) -> void: _emit())
		_add_field(grid, "Current HP", _hp)
		_staggered = CheckBox.new()
		_staggered.text = "Staggered from previous combat"
		_staggered.toggled.connect(func(_on: bool) -> void: _emit())
		_add_field(grid, "", _staggered)

		var stats_heading := Label.new()
		stats_heading.text = "Stats (editable)"
		add_child(stats_heading)
		var stat_grid := GridContainer.new()
		stat_grid.columns = 4
		add_child(stat_grid)
		for definition: StatDefinition in ruleset.stats:
			var spin: SpinBox = CombatLabSpin.make(-99, 999, 0)
			spin.value_changed.connect(func(_v: float) -> void: _on_stat_changed(definition.id))
			_stats[definition.id] = spin
			_add_field(stat_grid, definition.get_abbreviation(), spin)

	func source_count() -> int:
		return _sources.size()

	func unit_name() -> String:
		if _sources.is_empty():
			return "?"
		return (_sources[_source.selected] as TacticsData).get_display_name()

	## Selects source [param index] and resets level, weapon and stats from data.
	func select_source(index: int) -> void:
		if index < 0 or index >= _sources.size():
			return
		_quiet = true
		_source.select(index)
		var source: TacticsData = _sources[index]
		var class_data: ClassData = _class_of(source)
		if source is UnitData:
			_level.value = (source as UnitData).level
		_select_weapon(_default_weapon(source, class_data))
		_quiet = false
		_recompute_stats()

	func _recompute_stats() -> void:
		var source: TacticsData = _sources[_source.selected]
		var stats: StatBlock
		if source is UnitData:
			stats = UnitStats.average_at_level(source as UnitData, _ruleset, int(_level.value))
		else:
			stats = UnitStats.generic(source as ClassData, _ruleset, int(_level.value))
		_quiet = true
		for stat_id: StringName in _stats:
			_stats[stat_id].value = stats.get_value(stat_id)
		_hp.value = maxi(1, stats.get_value(_ruleset.hp_stat))
		_quiet = false
		_emit()

	func _on_stat_changed(stat_id: StringName) -> void:
		if stat_id == _ruleset.hp_stat and not _quiet:
			_hp.value = _stats[stat_id].value
		_emit()

	func build_participant() -> CombatParticipant:
		var participant := CombatParticipant.new()
		var source: TacticsData = _sources[_source.selected]
		var class_data: ClassData = _class_of(source)
		for stat_id: StringName in _stats:
			participant.stats.set_value(stat_id, int(_stats[stat_id].value))
		participant.weapon = _weapons[_weapon.selected - 1] if _weapon.selected > 0 else null
		participant.terrain = _terrains[_terrain.selected - 1] if _terrain.selected > 0 else null
		participant.movement_type = class_data.movement_type if class_data != null else null
		var unit_tags: Array[StringName] = []
		if source is UnitData:
			unit_tags = (source as UnitData).tags
		participant.tags = UnitStats.tags_for(class_data, unit_tags)
		participant.current_hp = int(_hp.value)
		participant.level = int(_level.value)
		participant.tier = class_data.tier if class_data != null else 0
		participant.staggered = _staggered.button_pressed
		return participant

	func get_state() -> Dictionary:
		var stats: Dictionary = {}
		for stat_id: StringName in _stats:
			stats[stat_id] = _stats[stat_id].value
		return {
			"source": _source.selected, "level": _level.value, "weapon": _weapon.selected, "terrain": _terrain.selected,
			"hp": _hp.value, "staggered": _staggered.button_pressed, "stats": stats,
		}

	func set_state(state: Dictionary) -> void:
		_quiet = true
		_source.select(state["source"])
		_level.value = state["level"]
		_weapon.select(state["weapon"])
		_terrain.select(state["terrain"])
		var stats: Dictionary = state["stats"]
		for stat_id: StringName in _stats:
			_stats[stat_id].value = stats.get(stat_id, 0)
		_hp.value = state["hp"]
		_staggered.button_pressed = state["staggered"]
		_quiet = false

	func _emit() -> void:
		if not _quiet:
			changed.emit()

	func _select_weapon(weapon: WeaponData) -> void:
		_weapon.select(_weapons.find(weapon) + 1 if weapon != null else 0)

	func _default_weapon(source: TacticsData, class_data: ClassData) -> WeaponData:
		if source is UnitData:
			for item: ItemData in (source as UnitData).inventory:
				if item is WeaponData and not (item as WeaponData).heals:
					return item as WeaponData
		if class_data != null:
			for weapon: WeaponData in _weapons:
				if class_data.can_use_weapon_type(weapon.weapon_type) and not weapon.heals and weapon.required_proficiency == 0:
					return weapon
		return null

	static func _class_of(source: TacticsData) -> ClassData:
		if source is UnitData:
			return (source as UnitData).class_data
		return source as ClassData

	static func _add_field(grid: GridContainer, label_text: String, control: Control) -> void:
		var label := Label.new()
		label.text = label_text
		grid.add_child(label)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(control)


## SpinBox factory shared with the inner class (inner classes cannot call the
## outer script's static functions).
class CombatLabSpin:
	static func make(min_value: int, max_value: int, value: int) -> SpinBox:
		var spin := SpinBox.new()
		spin.min_value = min_value
		spin.max_value = max_value
		spin.step = 1
		spin.value = value
		spin.custom_minimum_size.x = 90
		return spin
