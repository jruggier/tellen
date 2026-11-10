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
	scene.input.action_finished.connect(func() -> void: _after_player_action())
	scene.input.before_attack = play_battle_quotes
	scene.input.present_event = present_outcome


## Starts turn 1 (map-start events, then the first phase).
func start() -> void:
	var report: TurnManager.PhaseReport = scene.controller.start()
	scene.input.disable()
	await run_events(MapEvent.Trigger.MAP_START)
	await _begin_phase(report)


## Fires every available event with [param trigger] and presents each one.
## Returns true if any fired.
func run_events(trigger: MapEvent.Trigger, context: Dictionary = {}) -> bool:
	var state: BattleState = scene.controller.state
	var fired: bool = false
	for event: MapEvent in MapEventRules.matching(state, state.map_events, trigger, context):
		var command := EventCommands.Trigger.new(event, context)
		if scene.controller.execute(command):
			fired = true
			await present_outcome(command.outcome)
	return fired


## Shows what an event did: new units, items, recruits, objectives, dialogue.
func present_outcome(outcome: MapEventRules.Outcome) -> void:
	if outcome == null:
		return
	var state: BattleState = scene.controller.state
	for unit_id: StringName in outcome.spawned:
		scene.add_unit_view(state.get_unit(unit_id))
	if outcome.recruited != &"":
		scene.recolor_unit_view(state.get_unit(outcome.recruited))
	scene.objectives.append_array(outcome.objectives_added)
	scene.refresh_views()
	await play_dialogue(outcome.dialogue_id)
	for item: ItemData in outcome.items_given:
		scene.toast.show_message(tr("UI_ITEM_OBTAINED") % item.get_display_name())
	for item: ItemData in outcome.items_lost:
		scene.toast.show_message(tr("UI_ITEM_LOST") % item.get_display_name())
	scene.update_turn_label()


## Plays dialogue scene [param scene_id] (no-op when empty or missing).
func play_dialogue(scene_id: StringName) -> void:
	if scene_id == &"":
		return
	var script: DialogueScript = scene.dialogues.get_script_by_id(scene_id)
	if script == null:
		TacticsLog.warn("BattleFlow", "Dialogue scene '%s' not found" % scene_id)
		return
	var state: BattleState = scene.controller.state
	await scene.dialogue_player.play(script, state.flags, state.campaign.flags)


## Battle quotes before a combat between [param attacker] and [param defender].
func play_battle_quotes(attacker: UnitState, defender: UnitState) -> void:
	await run_events(MapEvent.Trigger.BATTLE_QUOTE, {"unit": attacker, "other": defender})


## Defeat and region events after any unit's action.
func after_unit_action() -> void:
	var state: BattleState = scene.controller.state
	await run_events(MapEvent.Trigger.UNIT_DEFEATED)
	for unit: UnitState in state.all_units():
		if unit.is_alive():
			await run_events(MapEvent.Trigger.REGION, {"unit": unit})


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
	await run_events(MapEvent.Trigger.TURN)
	if not report.spawned.is_empty():
		await run_events(MapEvent.Trigger.REINFORCEMENT)
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


func _after_player_action() -> void:
	scene.input.suspend()
	await after_unit_action()
	scene.input.resume()
	_on_player_action_finished()


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
