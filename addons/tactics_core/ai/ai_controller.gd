class_name AIController
extends Node
## Runs an AI faction's phase on screen: picks the next unit in §10 order,
## plans its turn with [AIPlanner], executes the commands and plays the
## animations. Re-plans every unit against the current state, so earlier
## actions in the phase are taken into account.

## Pause between units (seconds; 0 = none).
@export var seconds_between_units: float = 0.25

var scene: BattleScene
var flow: BattleFlow


## Plays every unit of [param faction_id], one at a time.
func run_phase(faction_id: StringName) -> void:
	var state: BattleState = scene.controller.state
	var safety: int = state.units_of(faction_id).size() + 8
	while safety > 0:
		safety -= 1
		AIRules.wake_by_regions(state)
		var order: Array[UnitState] = AIPlanner.turn_order(state, faction_id)
		if order.is_empty():
			return
		await _run_unit(order[0])
		if flow != null and flow.check_end():
			return
		await scene.presenter.pause(seconds_between_units)


func _run_unit(unit: UnitState) -> void:
	var state: BattleState = scene.controller.state
	var started: int = Time.get_ticks_usec()
	var plan: AIPlanner.Plan = AIPlanner.plan(state, unit)
	TacticsLog.debug("AI", "%s plans %s → %s (%s, score %.1f) in %.1f ms" % [unit.id, unit.cell, plan.destination,
		AIPlanner.Action.keys()[plan.action], plan.score, (Time.get_ticks_usec() - started) / 1000.0])
	scene.cursor.set_cell(unit.cell, false)
	scene.camera.follow(scene.cursor.cell_center(unit.cell))
	if plan.destination != unit.cell:
		var move := MoveCommand.new(unit.id, plan.destination)
		if scene.controller.execute(move):
			var view: UnitView = scene.unit_views.get(unit.id)
			scene.camera.follow(scene.cursor.cell_center(plan.destination))
			if view != null and view.seconds_per_cell > 0.0:
				view.walk(move.path)
				await view.walk_finished
			elif view != null:
				view.place_at(plan.destination)
	match plan.action:
		AIPlanner.Action.ATTACK:
			await _attack(unit, plan)
		AIPlanner.Action.HEAL:
			var heal := HealCommand.new(unit.id, plan.target_id, plan.slot)
			if scene.controller.execute(heal):
				var target: UnitState = state.get_unit(plan.target_id)
				scene.presenter.popup_at_cell(target.cell, "+%d" % heal.amount, UiStyle.GOOD, 7.0)
				await scene.presenter.pause(0.5)
	if unit.is_ready():
		scene.controller.execute(WaitCommand.new(unit.id))
	scene.refresh_views()


func _attack(unit: UnitState, plan: AIPlanner.Plan) -> void:
	var state: BattleState = scene.controller.state
	var target: UnitState = state.get_unit(plan.target_id)
	var ruleset: Ruleset = state.ruleset
	var unit_cell: Vector2i = unit.cell
	var target_cell: Vector2i = target.cell
	var attack := AttackCommand.new(unit.id, target.id, plan.slot)
	if not scene.controller.execute(attack):
		return
	await scene.presenter.play_combat(attack.result, scene.unit_views[unit.id], scene.unit_views[target.id],
		unit_cell, target_cell, unit.max_hp(ruleset), target.max_hp(ruleset))
	for effect: Dictionary in attack.skill_effects:
		var owner: UnitState = state.get_unit(StringName(effect["unit"]))
		if owner != null and int(effect.get("heal", 0)) > 0:
			scene.presenter.popup_at_cell(owner.cell, "%s +%d" % [tr(str(effect.get("text", ""))), int(effect["heal"])], UiStyle.GOOD, 5.0)
	scene.refresh_views()
	await scene.input.show_progress(attack.reports.values())
