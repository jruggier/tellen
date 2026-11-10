class_name TradePanel
extends PanelContainer
## Two-column trade screen (spec §9.1). Pick an item in either column, then
## a destination slot in the other column (an item to swap with, or the
## empty slot to give it). Emits [signal trade_requested]; the owner runs
## the trade command and calls [method refresh].

## Swap/give between [code]left[/code] slot and [code]right[/code] slot
## (an index equal to the inventory size means "the empty slot").
signal trade_requested(left_slot: int, right_slot: int)

var column: int = 0
var row: int = 0
## Picked slot as Vector2i(column, row), or (-1, -1).
var picked := Vector2i(-1, -1)
var _units: Array[UnitState] = []
var _ruleset: Ruleset
var _columns: Array[VBoxContainer] = []


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 40)
	add_child(line)
	for i: int in 2:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(360, 0)
		line.add_child(box)
		_columns.append(box)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Opens the trade between [param left] (acting unit) and [param right].
func open(left: UnitState, right: UnitState, ruleset: Ruleset) -> void:
	_units = [left, right]
	_ruleset = ruleset
	column = 0
	row = 0
	picked = Vector2i(-1, -1)
	visible = true
	refresh()


func close() -> void:
	visible = false


## Moves the highlight; [param delta] (x = column, y = row).
func move(delta: Vector2i) -> void:
	column = clampi(column + delta.x, 0, 1)
	row = clampi(row + delta.y, 0, _row_count(column) - 1)
	refresh()


## Picks the highlighted item, or completes a trade if one is picked.
func accept() -> void:
	if picked.x < 0:
		if row < _units[column].inventory.size():
			picked = Vector2i(column, row)
			column = 1 - column
			row = mini(row, _row_count(column) - 1)
	elif column == picked.x:
		picked = Vector2i(column, row) if row < _units[column].inventory.size() else picked
	else:
		var left_slot: int = picked.y if picked.x == 0 else row
		var right_slot: int = row if picked.x == 0 else picked.y
		picked = Vector2i(-1, -1)
		trade_requested.emit(left_slot, right_slot)
	refresh()


## Clears a picked item. Returns false if nothing was picked (close instead).
func cancel_pick() -> bool:
	if picked.x < 0:
		return false
	column = picked.x
	row = picked.y
	picked = Vector2i(-1, -1)
	refresh()
	return true


func refresh() -> void:
	for i: int in 2:
		var box: VBoxContainer = _columns[i]
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
		var unit: UnitState = _units[i]
		box.add_child(UiStyle.label(unit.get_display_name(), 30, UiStyle.PANEL_BORDER))
		for r: int in _row_count(i):
			var text: String = "—"
			if r < unit.inventory.size():
				var slot: InventorySlot = unit.inventory[r]
				text = slot.item.get_display_name() + ("  %d" % slot.uses if slot.uses >= 0 else "")
			var color: Color = Color.WHITE
			if picked == Vector2i(i, r):
				color = UiStyle.WARN
			var marker: String = "▶ " if (i == column and r == row) else "   "
			box.add_child(UiStyle.label(marker + text, 26, color))
	row = clampi(row, 0, _row_count(column) - 1)
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5


## Rows in a column: its items plus one empty slot if it has room.
func _row_count(index: int) -> int:
	var unit: UnitState = _units[index]
	return unit.inventory.size() + (1 if unit.has_inventory_space(_ruleset) else 0)
