class_name CombatHud
extends PanelContainer
## Both combatants' names and HP bars during a map combat, draining in step
## with the strikes (spec §14 HP drain). Driven by [CombatPresenter].

var _sides: Array[Dictionary] = []


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	add_child(row)
	for i: int in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		var name_label := UiStyle.label("", 28)
		column.add_child(name_label)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var hp := UiStyle.label("", 30)
		hp.custom_minimum_size = Vector2(52, 0)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(hp)
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(360, 22)
		bar.color_by_ratio = true
		bar.segment = 5.0
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		column.add_child(line)
		row.add_child(column)
		bar.value_ticked.connect(func(shown: int) -> void: hp.text = str(shown))
		_sides.append({"name": name_label, "hp": hp, "bar": bar})
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the attacker (index 0) and defender (index 1).
func open(names: Array[String], colors: Array[Color], hp: Array[int], max_hp: Array[int]) -> void:
	for i: int in 2:
		var side: Dictionary = _sides[i]
		(side["name"] as Label).text = names[i]
		(side["name"] as Label).add_theme_color_override("font_color", colors[i])
		(side["hp"] as Label).text = str(hp[i])
		(side["bar"] as StatBar).set_values(hp[i], max_hp[i])
	visible = true
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, get_viewport_rect().size.y - size.y - 60).floor()


## Drains or fills side [param index] (0 attacker, 1 defender) to [param hp].
func set_hp(index: int, hp: int, seconds: float) -> void:
	var bar: StatBar = _sides[index]["bar"]
	(_sides[index]["hp"] as Label).text = str(hp) if seconds <= 0.0 else (_sides[index]["hp"] as Label).text
	bar.animate_to(hp, seconds)
	if seconds <= 0.0:
		(_sides[index]["hp"] as Label).text = str(hp)


func close() -> void:
	visible = false
