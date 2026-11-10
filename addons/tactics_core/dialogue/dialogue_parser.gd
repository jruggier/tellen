class_name DialogueParser
extends RefCounted
## Parses screenplay-style .dlg text into [DialogueScript]s (spec §11.2).
## See docs/DIALOGUE.md for the full syntax.
##
## One file may hold several scenes, each starting with [code]=== id ===[/code].
## Errors carry line numbers ("line 14: unknown command @shwo"); a scene
## with errors is still returned so the rest of the file stays usable.

const POSITIONS: PackedStringArray = ["left", "center", "right"]

## Result of parsing one source.
class Result:
	extends RefCounted
	var scripts: Dictionary[StringName, DialogueScript] = {}
	var errors: PackedStringArray = []

	func ok() -> bool:
		return errors.is_empty()


static var _speaker_line := RegEx.create_from_string("^([A-Z][A-Z0-9_]*)\\s*(?:\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*\\))?\\s*:\\s*(.*)$")
static var _header := RegEx.create_from_string("^===\\s*([A-Za-z0-9_]+)\\s*===$")
static var _option := RegEx.create_from_string("^-\\s*\"(.*)\"\\s*->\\s*([A-Za-z0-9_]+)\\s*$")
static var _if := RegEx.create_from_string("^(!?)([A-Za-z0-9_.]+)\\s*->\\s*([A-Za-z0-9_]+)$")
static var _set := RegEx.create_from_string("^([A-Za-z0-9_.]+)\\s*=\\s*(.+)$")


## Parses [param text]; [param source] names it in error messages.
static func parse(text: String, source: String = "<text>") -> Result:
	var result := Result.new()
	var script: DialogueScript = null
	var lines: PackedStringArray = text.replace("\r\n", "\n").split("\n")
	var pending_choice: DialogueCommand = null
	for index: int in lines.size():
		var number: int = index + 1
		var raw: String = lines[index]
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var header: RegExMatch = _header.search(line)
		if header != null:
			_finish(script, result, pending_choice, source)
			pending_choice = null
			script = DialogueScript.new()
			script.id = StringName(header.get_string(1))
			script.source = source
			if result.scripts.has(script.id):
				_error(result, source, number, "scene '%s' is defined twice" % script.id)
			result.scripts[script.id] = script
			continue
		if script == null:
			_error(result, source, number, "text before the first '=== scene_id ===' header")
			continue
		if line.begins_with("-") and pending_choice != null:
			var option: RegExMatch = _option.search(line)
			if option == null:
				_error(result, source, number, "choice options look like: - \"Text\" -> label")
			else:
				pending_choice.options.append({"text": option.get_string(1), "label": option.get_string(2), "line": number})
			continue
		if pending_choice != null:
			if pending_choice.options.is_empty():
				_error(result, source, pending_choice.line_number, "@choice has no options")
			pending_choice = null
		if line.begins_with("@"):
			var command: DialogueCommand = _parse_command(line, number, result, source)
			if command == null:
				continue
			if command.type == DialogueCommand.Type.CHOICE:
				pending_choice = command
			if command.type == DialogueCommand.Type.LABEL:
				if script.labels.has(command.target):
					_error(result, source, number, "label '%s' is defined twice" % command.target)
				script.labels[command.target] = script.commands.size()
			script.commands.append(command)
			continue
		var speaker: RegExMatch = _speaker_line.search(line)
		if speaker == null:
			_error(result, source, number, "expected 'NAME: text', 'NAME (expression): text' or an @command")
			continue
		var spoken := DialogueCommand.new()
		spoken.type = DialogueCommand.Type.LINE
		spoken.line_number = number
		spoken.speaker = speaker.get_string(1)
		spoken.expression = speaker.get_string(2) if not speaker.get_string(2).is_empty() else "neutral"
		spoken.text = speaker.get_string(3).strip_edges()
		if spoken.text.is_empty():
			_error(result, source, number, "%s has no line to say" % spoken.speaker)
		script.commands.append(spoken)
	_finish(script, result, pending_choice, source)
	return result


## Reads and parses the file at [param path].
static func parse_file(path: String) -> Result:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var failed := Result.new()
		failed.errors.append("%s: cannot open file" % path)
		return failed
	return parse(file.get_as_text(), path)


static func _parse_command(line: String, number: int, result: Result, source: String) -> DialogueCommand:
	var space: int = line.find(" ")
	var keyword: String = (line.substr(1, space - 1) if space > 0 else line.substr(1)).to_lower()
	var rest: String = line.substr(space + 1).strip_edges() if space > 0 else ""
	var args: PackedStringArray = rest.split(" ", false)
	var command := DialogueCommand.new()
	command.line_number = number
	match keyword:
		"bg", "music", "sfx", "item":
			command.type = {"bg": DialogueCommand.Type.BG, "music": DialogueCommand.Type.MUSIC,
				"sfx": DialogueCommand.Type.SFX, "item": DialogueCommand.Type.ITEM}[keyword]
			if args.size() != 1:
				return _arg_error(result, source, number, "@%s needs one id" % keyword)
			command.target = args[0]
		"show":
			command.type = DialogueCommand.Type.SHOW
			if args.size() < 2 or args.size() > 3:
				return _arg_error(result, source, number, "@show NAME position [expression]")
			command.speaker = args[0].to_upper()
			command.position = args[1].to_lower()
			if not POSITIONS.has(command.position):
				return _arg_error(result, source, number, "position must be left, center or right (got '%s')" % args[1])
			command.expression = args[2] if args.size() == 3 else "neutral"
		"hide":
			command.type = DialogueCommand.Type.HIDE
			if args.size() != 1:
				return _arg_error(result, source, number, "@hide NAME")
			command.speaker = args[0].to_upper()
		"expr":
			command.type = DialogueCommand.Type.EXPR
			if args.size() != 2:
				return _arg_error(result, source, number, "@expr NAME expression")
			command.speaker = args[0].to_upper()
			command.expression = args[1]
		"hide_item":
			command.type = DialogueCommand.Type.HIDE_ITEM
		"choice":
			command.type = DialogueCommand.Type.CHOICE
		"label", "goto":
			command.type = DialogueCommand.Type.LABEL if keyword == "label" else DialogueCommand.Type.GOTO
			if args.size() != 1:
				return _arg_error(result, source, number, "@%s needs one label name" % keyword)
			command.target = args[0]
		"if":
			command.type = DialogueCommand.Type.IF
			var condition: RegExMatch = _if.search(rest)
			if condition == null:
				return _arg_error(result, source, number, "@if flag -> label (or @if !flag -> label)")
			command.negate = condition.get_string(1) == "!"
			command.flag = condition.get_string(2)
			command.target = condition.get_string(3)
		"set":
			command.type = DialogueCommand.Type.SET
			var assignment: RegExMatch = _set.search(rest)
			if assignment == null:
				return _arg_error(result, source, number, "@set flag = value")
			command.flag = assignment.get_string(1)
			command.value = _value(assignment.get_string(2).strip_edges())
		"wait":
			command.type = DialogueCommand.Type.WAIT
			if args.size() != 1 or not args[0].is_valid_float():
				return _arg_error(result, source, number, "@wait seconds")
			command.seconds = args[0].to_float()
		"end":
			command.type = DialogueCommand.Type.END
		_:
			return _arg_error(result, source, number, "unknown command @%s" % keyword)
	return command


static func _value(text: String) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text.trim_prefix("\"").trim_suffix("\"")


## Checks jump targets once a scene is complete.
static func _finish(script: DialogueScript, result: Result, pending_choice: DialogueCommand, source: String) -> void:
	if pending_choice != null and pending_choice.options.is_empty():
		_error(result, source, pending_choice.line_number, "@choice has no options")
	if script == null:
		return
	for command: DialogueCommand in script.commands:
		match command.type:
			DialogueCommand.Type.GOTO, DialogueCommand.Type.IF:
				if not script.labels.has(command.target):
					_error(result, source, command.line_number, "unknown label '%s'" % command.target)
			DialogueCommand.Type.CHOICE:
				for option: Dictionary in command.options:
					if not script.labels.has(str(option["label"])):
						_error(result, source, int(option["line"]), "unknown label '%s'" % option["label"])


static func _error(result: Result, source: String, number: int, message: String) -> void:
	result.errors.append("%s: line %d: %s" % [source, number, message])


static func _arg_error(result: Result, source: String, number: int, message: String) -> DialogueCommand:
	_error(result, source, number, message)
	return null
