class_name BattleFlow
extends Node
## Sequences a battle: phase banners, the player's phase, AI phases,
## phase-start effects (healing, reinforcements), objectives and the end of
## the battle (spec §8).
##
## Logic stays in commands; this node only decides what happens next and
## waits for presentation to finish.

## A new phase started (after its banner).
signal phase_began(faction_id: StringName)
## The battle ended.
signal battle_finished(victory: bool)

## End the player's phase automatically once every unit has acted.
@export var auto_end_turn: bool = true

var scene: BattleScene
var ai: AIController
var finished: bool = false
var _ending_phase: bool = false


func _ready() -> void:
	scene.input.end_turn_requested.connect(func() -> void: end_phase())
	scene.input.action_finished.connect(_on_player_action_finished)


## Starts turn 1.
func start() -> void:
	var report: TurnManager.PhaseReport = scene.controller.start()
	await _begin_phase(report)


## Ends the current phase and runs the next one.
func end_phase() -> void:
	if finished or _ending_phase:
		return
	_ending_phase = true
	scene.input.disable()
	var state: BattleState = scene.controller.state
	var command := EndPhaseCommand.new(state.current_faction().id)
	scene.controller.execute(command)
	_ending_phase = false
	await _begin_phase(command.report)


func _begin_phase(report: TurnManager.PhaseReport) -> void:
	var state: BattleState = scene.controller.state
	scene.input.disable()
	for unit_id: StringName in report.spawned:
		scene.add_unit_view(state.get_unit(unit_id))
	scene.refresh_views()
	for unit_id: StringName in report.healed:
		scene.presenter.popup_at_cell(state.get_unit(unit_id).cell, "+%d" % report.healed[unit_id], UiStyle.GOOD, 6.0)
	scene.update_turn_label()
	scene.overlay.show_warnings(ReinforcementRules.telegraphed_cells(state))
	var faction: FactionData = state.current_faction()
	await scene.banner.play(tr("UI_PHASE_BANNER") % faction.get_display_name(), faction.color)
	if check_end():
		return
	phase_began.emit(faction.id)
	if faction.controller == FactionData.Controller.HUMAN:
		scene.input.begin_player_phase()
		_on_player_action_finished()
	else:
		await _run_ai_phase(faction)
		if not check_end():
			await end_phase()


func _run_ai_phase(faction: FactionData) -> void:
	var state: BattleState = scene.controller.state
	if ai == null:
		for unit: UnitState in state.units_of(faction.id):
			if unit.is_ready():
				scene.controller.execute(WaitCommand.new(unit.id))
		return
	await ai.run_phase(faction.id)


func _on_player_action_finished() -> void:
	scene.update_turn_label()
	if finished or check_end():
		return
	var state: BattleState = scene.controller.state
	var faction: FactionData = state.current_faction()
	if auto_end_turn and faction != null and faction.controller == FactionData.Controller.HUMAN \
			and TurnManager.all_acted(state, faction.id):
		end_phase.call_deferred()


## Checks objectives and defeat conditions; ends the battle if decided.
func check_end() -> bool:
	if finished:
		return true
	var outcome: ObjectiveRules.Outcome = ObjectiveRules.evaluate(scene.controller.state, scene.objectives, scene.defeat_conditions)
	if outcome == ObjectiveRules.Outcome.ONGOING:
		return false
	finished = true
	scene.input.disable()
	var victory: bool = outcome == ObjectiveRules.Outcome.VICTORY
	TacticsEvents.battle_ended.emit(scene.controller.state.map_id, victory)
	battle_finished.emit(victory)
	return true
