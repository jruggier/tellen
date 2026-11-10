class_name RewindService
extends RefCounted
## Rewind (spec §9.6): return the battle to the start of any earlier player
## action this map.
##
## Before the first command of each player action (and before the player
## ends a phase) the service stores a snapshot: a deep copy of the battle
## state (including the RNG position), the campaign flags and the map's
## objectives. Rewinding restores one exactly, drops every later snapshot
## and log entry, and uses a charge ([member Ruleset.rewind_charges_per_map]).
## Enemy turns in between are undone; they replay only if the player
## re-issues commands, and RNG state comes back with the snapshot.


## One place the player can rewind to.
class Point:
	extends RefCounted
	var state: BattleState
	var campaign_flags: Dictionary
	var objectives: Array[Objective]
	var log_size: int
	var turn: int
	## Unit whose action starts here (empty = ending the phase).
	var actor_id: StringName
	var actor_name: String


var controller: BattleController
var points: Array[Point] = []
var charges_left: int = 0
## Returns the map's current objectives (they can change through events).
var objectives_provider: Callable = Callable()
## "unit@turn" of the action whose snapshot is already taken.
var _open_action: String = ""


func _init(battle_controller: BattleController = null, charges: int = 0) -> void:
	controller = battle_controller
	charges_left = charges
	if controller != null:
		controller.before_command.connect(_on_before_command)
		controller.command_undone.connect(_on_command_undone)


## True if the player can rewind now.
func can_rewind() -> bool:
	return charges_left > 0 and not points.is_empty()


## Rewinds to [param index] in [member points]. Returns the restored point.
func rewind_to(index: int) -> Point:
	if not can_rewind() or index < 0 or index >= points.size():
		return null
	var point: Point = points[index]
	var restored: BattleState = point.state.copy()
	restored.campaign = controller.state.campaign
	restored.campaign.flags = point.campaign_flags.duplicate(true)
	controller.restore_state(restored, point.log_size)
	points.resize(index)
	charges_left -= 1
	_open_action = ""
	TacticsLog.info("Rewind", "Rewound to turn %d (%s); %d charge(s) left" % [point.turn, point.actor_name, charges_left])
	return point


func _on_before_command(command: Command) -> void:
	var state: BattleState = controller.state
	var faction: FactionData = state.current_faction()
	if faction == null or faction.controller != FactionData.Controller.HUMAN:
		return
	if command is EndPhaseCommand:
		_capture(&"", tr("UI_REWIND_END_TURN"))
		return
	var actor: StringName = command.actor_id()
	var unit: UnitState = state.get_unit(actor)
	if unit == null or unit.faction_id != faction.id or unit.has_acted:
		return
	var key: String = "%s@%d" % [actor, state.turn]
	if unit.has_moved or _open_action == key:
		return
	_open_action = key
	_capture(actor, unit.get_display_name())


func _capture(actor: StringName, label: String) -> void:
	var point := Point.new()
	point.state = controller.state.copy()
	point.campaign_flags = controller.state.campaign.flags.duplicate(true)
	if objectives_provider.is_valid():
		point.objectives.assign(objectives_provider.call())
	point.log_size = controller.action_log.size()
	point.turn = controller.state.turn
	point.actor_id = actor
	point.actor_name = label
	points.append(point)


func _on_command_undone(_command: Command) -> void:
	# A cancelled move: forget the snapshot taken for it.
	if not points.is_empty() and points.back().log_size >= controller.action_log.size():
		points.pop_back()
		_open_action = ""
