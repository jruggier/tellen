class_name ExpPanel
extends PanelContainer
## The EXP bar shown after a unit gains experience: it fills with a rising
## tick sound, chimes and wraps each time it reaches a level, then closes.
## Level-up details follow in [LevelUpPanel].

## Seconds to fill a whole level's worth of EXP (scaled by animation speed).
@export var seconds_per_level: float = 1.1
## Seconds the full result stays on screen.
@export var hold_seconds: float = 0.45

var bar := StatBar.new()
var _name := UiStyle.label("", 28)
var _amount := UiStyle.label("", 26, Color(0.6, 0.85, 1.0))
var _gained := UiStyle.label("", 24, UiStyle.TEXT_DIM)
var _per_level: int = 100
var _tick_count: int = 0


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var top := HBoxContainer.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	top.add_child(_gained)
	box.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiStyle.label(tr("UI_EXP"), 24, Color(0.6, 0.85, 1.0)))
	bar.custom_minimum_size = Vector2(440, 24)
	bar.fill_color = Color(0.4, 0.75, 1.0)
	bar.segment = 10.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_amount.custom_minimum_size = Vector2(56, 0)
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_amount)
	box.add_child(row)
	bar.value_ticked.connect(_on_tick)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Animates [param gained] EXP from [param old_exp] for [param unit_name].
## [param time_scale] is the animation-speed multiplier (0 = instant).
func play(unit_name: String, old_exp: int, gained: int, per_level: int, time_scale: float = 1.0) -> void:
	_per_level = maxi(1, per_level)
	_name.text = unit_name
	_gained.text = tr("UI_EXP_GAINED") % gained
	bar.set_values(old_exp, _per_level)
	_amount.text = str(old_exp)
	visible = true
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, get_viewport_rect().size.y - size.y - 150).floor()
	var remaining: int = gained
	var current: int = old_exp
	_tick_count = 0
	while remaining > 0:
		var step: int = mini(remaining, _per_level - current)
		var seconds: float = seconds_per_level * float(step) / _per_level * time_scale
		if time_scale > 0.0:
			seconds = maxf(seconds, 0.2 * time_scale)
		await bar.animate_to(current + step, seconds)
		remaining -= step
		current += step
		_amount.text = str(current % _per_level if current >= _per_level else current)
		if current >= _per_level:
			Sfx.play(&"exp_full")
			await _wait(0.3 * time_scale)
			current = 0
			bar.set_values(0, _per_level)
			_amount.text = "0"
	await _wait(hold_seconds * time_scale)
	visible = false


func _on_tick(shown: int) -> void:
	_amount.text = str(shown)
	_tick_count += 1
	if _tick_count % 2 == 0:
		Sfx.play(&"exp_tick", 1.0 + float(shown) / _per_level)


func _wait(seconds: float) -> void:
	if seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(seconds).timeout
