class_name DebugConsole
extends PanelContainer
## In-battle debug console (spec §14), toggled with the
## [code]debug_console[/code] action (F4). Debug builds only.
##
## Commands: [code]kill <unit>[/code], [code]heal all[/code] (or
## [code]heal <unit>[/code]), [code]level <unit> <n>[/code],
## [code]give <unit> <item>[/code], [code]win[/code], [code]lose[/code],
## [code]seed <n>[/code], [code]awaken <unit>[/code], [code]units[/code],
## [code]help[/code]. Warnings from [TacticsLog] also appear here.
## [method run] is usable headlessly (tests).

const MAX_LINES: int = 12
const HELP: String = "kill <unit> | heal all | heal <unit> | level <unit> <n> | give <unit> <item> | win | lose | seed <n> | awaken <unit> | units"

var battle: BattleScene
var _line := LineEdit.new()
var _output := Label.new()
var _lines: PackedStringArray = []


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var box := VBoxContainer.new()
	add_child(box)
	_output.add_theme_font_size_override("font_size", 20)
	_output.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_output)
	_line.placeholder_text = "help"
	_line.add_theme_font_size_override("font_size", 24)
	_line.text_submitted.connect(_on_submitted)
	box.add_child(_line)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_left = 400
	offset_right = -400
	offset_top = 80
	TacticsEvents.log_emitted.connect(_on_log)


func _exit_tree() -> void:
	if TacticsEvents.log_emitted.is_connected(_on_log):
		TacticsEvents.log_emitted.disconnect(_on_log)


func toggle() -> void:
	visible = not visible
	if visible:
		battle.input.suspend()
		_line.clear()
		_line.grab_focus()
		_print(HELP)
	else:
		_line.release_focus()
		battle.input.resume()
		battle.input.refresh_info()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_console") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE and event.is_pressed():
		toggle()
		get_viewport().set_input_as_handled()


func _on_submitted(text: String) -> void:
	_line.clear()
	if text.strip_edges().is_empty():
		return
	_print("> " + text)
	_print(run(text))


func _on_log(_level: int, line: String) -> void:
	_print(line)


func _print(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_output.text = "\n".join(_lines)


## Runs one command line and returns the reply.
func run(line: String) -> String:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	var state: BattleState = battle.controller.state
	var command: String = words[0].to_lower()
	match command:
		"help":
			return HELP
		"units":
			var names: PackedStringArray = []
			for unit: UnitState in state.all_units():
				if unit.is_alive():
					names.append("%s (%s)" % [unit.id, unit.faction_id])
			return ", ".join(names)
		"win", "lose":
			toggle_off()
			battle.flow.force_end(command == "win")
			return "Battle ended"
		"seed":
			if words.size() < 2 or not words[1].is_valid_int():
				return "Usage: seed <n>"
			state.rng.reseed(int(words[1]))
			return "RNG reseeded with %d" % int(words[1])
		"heal":
			if words.size() >= 2 and words[1] == "all":
				for unit: UnitState in state.all_units():
					if unit.is_alive() and state.are_allied(unit.faction_id, Objective.player_faction_id(state)):
						unit.current_hp = unit.max_hp(state.ruleset)
				battle.refresh_views()
				return "Healed the player's side"
	if words.size() < 2:
		return "Unknown command. " + HELP
	var unit: UnitState = state.get_unit(StringName(words[1]))
	if unit == null:
		return "No unit '%s' (try: units)" % words[1]
	match command:
		"heal":
			unit.current_hp = unit.max_hp(state.ruleset)
			battle.refresh_views()
			return "%s healed" % unit.id
		"kill":
			if not unit.is_alive():
				return "%s is already down" % unit.id
			DefeatRules.apply(state, unit, null)
			TacticsEvents.unit_defeated.emit(unit.id, &"")
			battle.rebuild_unit_views()
			battle.update_turn_label()
			battle.flow.check_end()
			return "%s defeated" % unit.id
		"level":
			var count: int = int(words[2]) if words.size() >= 3 and words[2].is_valid_int() else 1
			for i: int in clampi(count, 0, state.ruleset.level_cap - unit.level):
				ProgressionService.level_up(state, unit)
			battle.refresh_views()
			return "%s is now level %d" % [unit.id, unit.level]
		"give":
			if words.size() < 3:
				return "Usage: give <unit> <item>"
			var item: ItemData = DataCatalog.item(words[2])
			if item == null:
				return "No item '%s'" % words[2]
			if not unit.has_inventory_space(state.ruleset):
				return "%s's inventory is full" % unit.id
			unit.inventory.append(InventorySlot.of(item))
			battle.refresh_views()
			return "Gave %s to %s" % [item.id, unit.id]
		"awaken":
			var awaken := AwakenCommand.new(unit.id)
			if not awaken.can_execute(state):
				return "%s can't awaken now" % unit.id
			battle.controller.execute(awaken)
			battle.refresh_views()
			return "%s awakened" % unit.id
	return "Unknown command. " + HELP


func toggle_off() -> void:
	if visible:
		toggle()
