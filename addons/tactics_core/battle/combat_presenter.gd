class_name CombatPresenter
extends Node
## Replays a resolved combat on the map (spec §14): bump, damage numbers,
## MISS / CRIT / STAGGER popups, HP drain, defeat fade. The battle state has
## already changed; this only animates the recorded [Strike]s.
##
## [member seconds_per_strike] = 0 makes everything instant (tests).
## Holding the [code]speed_up[/code] action plays faster.

## Base duration of one strike.
@export var seconds_per_strike: float = 0.45
## Multiplier while [code]speed_up[/code] is held.
@export var fast_forward: float = 3.0

var popup_parent: Node
var zoom: float = 4.0
var cell_size: int = 16


## Plays [param result] between the attacker and defender views.
## [param hp_max] maps "attacker"/"defender" to max HP for the HP strips.
func play_combat(result: CombatResult, attacker_view: UnitView, defender_view: UnitView, attacker_cell: Vector2i,
		defender_cell: Vector2i, attacker_max_hp: int, defender_max_hp: int, effective_marks: bool = true) -> void:
	for strike: Strike in result.strikes:
		var by_attacker: bool = strike.actor == Strike.Role.ATTACKER
		var actor: UnitView = attacker_view if by_attacker else defender_view
		var target: UnitView = defender_view if by_attacker else attacker_view
		var target_cell: Vector2i = defender_cell if by_attacker else attacker_cell
		var actor_cell: Vector2i = attacker_cell if by_attacker else defender_cell
		var target_max: int = defender_max_hp if by_attacker else attacker_max_hp
		var step: float = _step()
		actor.bump(target_cell, step * 0.5)
		await _wait(step * 0.22)
		var above: Vector2 = Vector2(target_cell * cell_size) + Vector2(cell_size * 0.5, -1.0)
		if strike.hit:
			target.flash()
			target.animate_hp(float(strike.target_hp_after) / maxf(1.0, target_max), step * 0.5)
			var text: String = str(strike.damage)
			var color: Color = Color.WHITE
			if strike.crit:
				text = "%s %d" % [tr("POPUP_CRIT"), strike.damage]
				color = UiStyle.WARN
			elif strike.effective and effective_marks:
				text += "!"
			_popup(above, text, color, 8.0 if strike.crit else 7.0)
			if strike.staggered:
				_popup(above + Vector2(0, -7), tr("POPUP_STAGGER"), Color(1.0, 0.6, 0.2), 5.5)
		else:
			_popup(above, tr("POPUP_MISS"), UiStyle.TEXT_DIM, 6.0)
		if strike.kind == Strike.Kind.FOLLOW_UP and step > 0.0:
			_popup(Vector2(actor_cell * cell_size) + Vector2(cell_size * 0.5, -1.0), tr("POPUP_FOLLOW_UP"), UiStyle.GOOD, 4.0)
		await _wait(step * 0.78)
	if result.defender_defeated():
		defender_view.fade_out(_step() * 0.9)
	if result.attacker_defeated():
		attacker_view.fade_out(_step() * 0.9)
	await _wait(_step() * 0.9 if result.defender_defeated() or result.attacker_defeated() else 0.0)


## A floating number over [param cell] (heals, EXP).
func popup_at_cell(cell: Vector2i, text: String, color: Color, size: float = 6.0) -> void:
	_popup(Vector2(cell * cell_size) + Vector2(cell_size * 0.5, -1.0), text, color, size)


## Waits [param seconds] scaled by the current speed (no wait when instant).
func pause(seconds: float) -> void:
	await _wait(seconds * _speed_scale())


func _popup(world_position: Vector2, text: String, color: Color, size: float) -> void:
	if popup_parent == null or seconds_per_strike <= 0.0:
		return
	FloatingText.spawn(popup_parent, world_position, text, color, zoom, size, maxf(0.5, 0.9 * _speed_scale()))


func _step() -> float:
	return seconds_per_strike * _speed_scale()


func _speed_scale() -> float:
	if seconds_per_strike <= 0.0:
		return 0.0
	return 1.0 / fast_forward if InputMap.has_action(&"speed_up") and Input.is_action_pressed(&"speed_up") else 1.0


func _wait(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
