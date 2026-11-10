class_name DialogueRunner
extends RefCounted
## Steps through a [DialogueScript] (pure logic, no Nodes). The scene being
## run is [member dialogue].
##
## [method advance] runs commands until something must be shown: a line, a
## choice, a wait, or the end. Stage commands (@bg, @show, @item...) update
## [member stage] along the way and are reported in the returned step so a
## player can animate them. Flags named [code]map.*[/code] go to the map's
## flags; all others to the campaign's.

## What the player must present next.
class Step:
	extends RefCounted
	enum Kind { LINE, CHOICE, WAIT, END }
	var kind: Kind = Kind.END
	var speaker: String = ""
	var expression: String = ""
	var text: String = ""
	## CHOICE: option texts.
	var options: PackedStringArray = []
	var seconds: float = 0.0
	## Sound effects triggered since the previous step.
	var sfx: PackedStringArray = []
	## True if the background, music, portraits or item changed.
	var stage_changed: bool = false


## Current stage: what is on screen.
class Stage:
	extends RefCounted
	var background: String = ""
	var music: String = ""
	## Position (left/center/right) → {"speaker", "expression"}.
	var actors: Dictionary[String, Dictionary] = {}
	var item: String = ""

	## Position of [param speaker] on stage, or "".
	func position_of(speaker: String) -> String:
		for slot: String in actors:
			if str(actors[slot]["speaker"]) == speaker:
				return slot
		return ""


## Guard against @goto loops that never reach a line.
const MAX_STEPS_PER_ADVANCE: int = 10000

var dialogue: DialogueScript
var stage := Stage.new()
var map_flags: Dictionary = {}
var campaign_flags: Dictionary = {}
## Every line shown so far: {"speaker", "text"} (for the backlog).
var history: Array[Dictionary] = []
var _index: int = 0
var _pending_choice: DialogueCommand = null
var _finished: bool = false


func _init(scene: DialogueScript = null, map_flag_store: Dictionary = {}, campaign_flag_store: Dictionary = {}) -> void:
	dialogue = scene
	map_flags = map_flag_store
	campaign_flags = campaign_flag_store


func is_finished() -> bool:
	return _finished


## Runs until the next thing to show.
func advance() -> Step:
	var step := Step.new()
	if _pending_choice != null:
		TacticsLog.warn("Dialogue", "advance() called while a choice is pending; choose() first")
		step.kind = Step.Kind.CHOICE
		step.options = _option_texts(_pending_choice)
		return step
	var guard: int = 0
	while not _finished:
		guard += 1
		if guard > MAX_STEPS_PER_ADVANCE:
			TacticsLog.warn("Dialogue", "%s: stopped an endless @goto loop" % dialogue.id)
			_finished = true
			break
		if dialogue == null or _index >= dialogue.commands.size():
			_finished = true
			break
		var command: DialogueCommand = dialogue.commands[_index]
		_index += 1
		match command.type:
			DialogueCommand.Type.LINE:
				step.kind = Step.Kind.LINE
				step.speaker = command.speaker
				step.expression = command.expression
				step.text = command.text
				var slot: String = stage.position_of(command.speaker)
				if not slot.is_empty() and stage.actors[slot]["expression"] != command.expression:
					stage.actors[slot]["expression"] = command.expression
					step.stage_changed = true
				history.append({"speaker": command.speaker, "text": command.text})
				return step
			DialogueCommand.Type.BG:
				stage.background = command.target
				step.stage_changed = true
			DialogueCommand.Type.MUSIC:
				stage.music = "" if command.target == "stop" else command.target
				step.stage_changed = true
			DialogueCommand.Type.SFX:
				step.sfx.append(command.target)
			DialogueCommand.Type.SHOW:
				var existing: String = stage.position_of(command.speaker)
				if not existing.is_empty():
					stage.actors.erase(existing)
				stage.actors[command.position] = {"speaker": command.speaker, "expression": command.expression}
				step.stage_changed = true
			DialogueCommand.Type.HIDE:
				var shown: String = stage.position_of(command.speaker)
				if not shown.is_empty():
					stage.actors.erase(shown)
					step.stage_changed = true
			DialogueCommand.Type.EXPR:
				var slot: String = stage.position_of(command.speaker)
				if not slot.is_empty():
					stage.actors[slot]["expression"] = command.expression
					step.stage_changed = true
			DialogueCommand.Type.ITEM:
				stage.item = command.target
				step.stage_changed = true
			DialogueCommand.Type.HIDE_ITEM:
				stage.item = ""
				step.stage_changed = true
			DialogueCommand.Type.CHOICE:
				_pending_choice = command
				step.kind = Step.Kind.CHOICE
				step.options = _option_texts(command)
				return step
			DialogueCommand.Type.LABEL:
				pass
			DialogueCommand.Type.GOTO:
				_jump(command.target)
			DialogueCommand.Type.IF:
				if is_truthy(get_flag(command.flag)) != command.negate:
					_jump(command.target)
			DialogueCommand.Type.SET:
				set_flag(command.flag, command.value)
			DialogueCommand.Type.WAIT:
				step.kind = Step.Kind.WAIT
				step.seconds = command.seconds
				return step
			DialogueCommand.Type.END:
				_finished = true
	step.kind = Step.Kind.END
	return step


## Picks option [param index] of the pending choice and continues.
func choose(index: int) -> Step:
	if _pending_choice == null or index < 0 or index >= _pending_choice.options.size():
		TacticsLog.warn("Dialogue", "choose(%d) without a matching pending choice" % index)
		return advance()
	var option: Dictionary = _pending_choice.options[index]
	history.append({"speaker": "", "text": "> " + str(option["text"])})
	_pending_choice = null
	_jump(str(option["label"]))
	return advance()


## Skips forward until the next choice or the end (no lines are shown).
func skip() -> Step:
	var step: Step = advance()
	while step.kind == Step.Kind.LINE or step.kind == Step.Kind.WAIT:
		step = advance()
	return step


## Reads a flag ([code]map.*[/code] from the map, others from the campaign).
func get_flag(flag: String) -> Variant:
	if flag.begins_with("map."):
		return map_flags.get(flag.trim_prefix("map."), null)
	return campaign_flags.get(flag, null)


func set_flag(flag: String, value: Variant) -> void:
	if flag.begins_with("map."):
		map_flags[flag.trim_prefix("map.")] = value
	else:
		campaign_flags[flag] = value


## A flag counts as set unless it is missing, false, 0 or empty text.
static func is_truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(value).is_empty()
	return true


func _jump(label: String) -> void:
	if dialogue.labels.has(label):
		_index = dialogue.labels[label]
	else:
		TacticsLog.warn("Dialogue", "%s: unknown label '%s'" % [dialogue.id, label])
		_finished = true


static func _option_texts(command: DialogueCommand) -> PackedStringArray:
	var texts := PackedStringArray()
	for option: Dictionary in command.options:
		texts.append(str(option["text"]))
	return texts
