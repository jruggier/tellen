class_name DialoguePlayer
extends CanvasLayer
## Plays a [DialogueScript] (spec §11.3): background, music, sound effects,
## up to three portraits, speaker name in the character's color, typewriter
## text, one item overlay, choices, a backlog, skip, fast-forward and auto.
##
## Controls: confirm = next line (or finish typing); cancel = skip to the
## next choice or the end; info = backlog; menu = auto-advance; hold
## speed_up = fast-forward. Mouse clicks work on lines and choices.
##
## Assets are looked up by id through path patterns (project settings
## [code]tactics_core/dialogue/*_path[/code]); missing art is drawn as a
## labelled placeholder, so scenes can be written before art exists.

signal finished

const SETTING_BACKGROUND_PATH: String = "tactics_core/dialogue/background_path"
const SETTING_MUSIC_PATH: String = "tactics_core/dialogue/music_path"
const SETTING_SFX_PATH: String = "tactics_core/dialogue/sfx_path"
const SETTING_PORTRAIT_PATH: String = "tactics_core/dialogue/portrait_path"

## Characters per second; 0 = show lines instantly.
@export var text_speed: float = 45.0
## Seconds a finished line stays up in auto mode.
@export var auto_delay: float = 1.4

var playing: bool = false
var auto_mode: bool = false
var runner: DialogueRunner

var _root := Control.new()
var _background := TextureRect.new()
var _placeholder_bg := ColorRect.new()
var _placeholder_bg_label := UiStyle.label("", 28, Color(1, 1, 1, 0.35))
var _portraits: Dictionary[String, Control] = {}
var _text_panel := PanelContainer.new()
var _name_label := UiStyle.label("", 34)
var _text := RichTextLabel.new()
var _item_panel := PanelContainer.new()
var _item_box := VBoxContainer.new()
var _choices := MenuList.new()
var _backlog := PanelContainer.new()
var _backlog_text := RichTextLabel.new()
var _hint := UiStyle.label("", 20, UiStyle.TEXT_DIM)
var _music := AudioStreamPlayer.new()
var _sfx := AudioStreamPlayer.new()
var _typing: bool = false
var _type_tween: Tween
var _skip_requested: bool = false
var _chosen: int = -1
var _warned_assets: Dictionary[String, bool] = {}

signal _advance
signal _choice_made


func _init() -> void:
	layer = 60
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_placeholder_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_placeholder_bg.color = Color(0.1, 0.11, 0.16)
	_root.add_child(_placeholder_bg)
	_placeholder_bg_label.position = Vector2(40, 30)
	_root.add_child(_placeholder_bg_label)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(_background)
	for slot: String in ["left", "center", "right"]:
		var holder := Control.new()
		holder.size = Vector2(440, 600)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(holder)
		_portraits[slot] = holder
	_item_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_item_panel.add_child(_item_box)
	_item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_item_panel)
	_text_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_root.add_child(_text_panel)
	var text_box := VBoxContainer.new()
	_text_panel.add_child(text_box)
	text_box.add_child(_name_label)
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(1700, 140)
	_text.add_theme_font_size_override("normal_font_size", 34)
	text_box.add_child(_text)
	text_box.add_child(_hint)
	_text_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			confirm())
	_root.add_child(_choices)
	_choices.chosen.connect(func(option_id: StringName) -> void:
		_chosen = int(String(option_id))
		_choice_made.emit())
	_backlog.add_theme_stylebox_override("panel", UiStyle.panel())
	_backlog_text.bbcode_enabled = true
	_backlog_text.scroll_following = true
	_backlog_text.custom_minimum_size = Vector2(1500, 760)
	_backlog_text.add_theme_font_size_override("normal_font_size", 28)
	_backlog.add_child(_backlog_text)
	_root.add_child(_backlog)
	add_child(_music)
	add_child(_sfx)
	visible = false


func _ready() -> void:
	_layout()
	get_viewport().size_changed.connect(_layout)


## Plays [param scene] to the end. Flags: [code]map.*[/code] go to
## [param map_flags], others to [param campaign_flags].
func play(scene: DialogueScript, map_flags: Dictionary, campaign_flags: Dictionary) -> void:
	if scene == null:
		return
	runner = DialogueRunner.new(scene, map_flags, campaign_flags)
	playing = true
	visible = true
	_backlog.visible = false
	_choices.close()
	_skip_requested = false
	var step: DialogueRunner.Step = runner.advance()
	while step.kind != DialogueRunner.Step.Kind.END:
		_apply_stage(step)
		match step.kind:
			DialogueRunner.Step.Kind.LINE:
				await _show_line(step)
			DialogueRunner.Step.Kind.CHOICE:
				_skip_requested = false
				step = runner.choose(await _ask(step.options))
				continue
			DialogueRunner.Step.Kind.WAIT:
				if not _skip_requested and step.seconds > 0.0 and is_inside_tree():
					await get_tree().create_timer(step.seconds / _speed()).timeout
		if _skip_requested:
			_skip_requested = false
			step = runner.skip()
			continue
		step = runner.advance()
	_apply_stage(step)
	_music.stop()
	playing = false
	visible = false
	finished.emit()


## Next line, or finish the current line's typing.
func confirm() -> void:
	if not playing or _choices.visible:
		if _choices.visible:
			_choices.accept()
		return
	if _backlog.visible:
		_backlog.visible = false
		return
	if _typing:
		_finish_typing()
		return
	_advance.emit()


## Skip ahead to the next choice or the end of the scene.
func cancel() -> void:
	if not playing or _choices.visible:
		return
	if _backlog.visible:
		_backlog.visible = false
		return
	_skip_requested = true
	_finish_typing()
	_advance.emit()


## Show or hide every line so far.
func toggle_backlog() -> void:
	if not playing:
		return
	_backlog.visible = not _backlog.visible
	if _backlog.visible:
		var lines: PackedStringArray = []
		for entry: Dictionary in runner.history:
			var speaker: String = str(entry["speaker"])
			lines.append("[b]%s[/b]  %s" % [_speaker_name(speaker), entry["text"]] if not speaker.is_empty() else "[i]%s[/i]" % entry["text"])
		_backlog_text.text = "\n".join(lines)


## Auto-advance lines after a short pause.
func toggle_auto() -> void:
	auto_mode = not auto_mode
	_update_hint()
	if auto_mode and not _typing:
		_advance.emit()


## Picks choice [param index] (tests and mouse).
func choose_option(index: int) -> void:
	if _choices.visible:
		_chosen = index
		_choice_made.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	var handled: bool = true
	if event.is_action_pressed(&"confirm") and not event.is_echo():
		confirm()
	elif event.is_action_pressed(&"cancel") and not event.is_echo():
		cancel()
	elif event.is_action_pressed(&"info") and not event.is_echo():
		toggle_backlog()
	elif event.is_action_pressed(&"menu") and not event.is_echo():
		toggle_auto()
	elif _choices.visible and event.is_action_pressed(&"cursor_up", true):
		_choices.move(-1)
	elif _choices.visible and event.is_action_pressed(&"cursor_down", true):
		_choices.move(1)
	else:
		handled = event is InputEventKey or event is InputEventJoypadButton
	if handled:
		get_viewport().set_input_as_handled()


func _show_line(step: DialogueRunner.Step) -> void:
	var character: CharacterData = DataCatalog.character(step.speaker)
	_name_label.text = _speaker_name(step.speaker)
	_name_label.add_theme_color_override("font_color", character.name_color if character != null else Color.WHITE)
	_text.text = step.text
	_highlight_speaker(step.speaker)
	_update_hint()
	if text_speed > 0.0 and _speed() < 10.0 and is_inside_tree():
		_typing = true
		_text.visible_ratio = 0.0
		var characters: int = maxi(1, step.text.length())
		_type_tween = create_tween()
		_type_tween.tween_property(_text, "visible_ratio", 1.0, characters / (text_speed * _speed()))
		_type_tween.finished.connect(func() -> void: _typing = false)
		while _typing:
			await get_tree().process_frame
			if not is_inside_tree():
				return  # The scene changed mid-line.
			if _skip_requested:
				_finish_typing()
				return
		_text.visible_ratio = 1.0
	else:
		_text.visible_ratio = 1.0
	if _skip_requested:
		return
	if _fast_forward():
		await get_tree().create_timer(0.08).timeout
		return
	if auto_mode and is_inside_tree():
		var timer: SceneTreeTimer = get_tree().create_timer(auto_delay)
		var waiting: Array[bool] = [true]
		timer.timeout.connect(func() -> void:
			if waiting[0]:
				_advance.emit())
		await _advance
		waiting[0] = false
		return
	await _advance


func _finish_typing() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_typing = false
	_text.visible_ratio = 1.0


func _ask(options: PackedStringArray) -> int:
	var entries: Array[Dictionary] = []
	for i: int in options.size():
		entries.append({"id": StringName(str(i)), "text": options[i]})
	_chosen = -1
	var screen: Vector2 = _root.get_viewport_rect().size
	_choices.open(entries, Vector2(screen.x * 0.5 - 220, _text_panel.position.y - 70 - 52 * options.size()))
	await _choice_made
	_choices.close()
	return maxi(0, _chosen)


func _apply_stage(step: DialogueRunner.Step) -> void:
	for sfx_id: String in step.sfx:
		var stream: AudioStream = _load_asset(SETTING_SFX_PATH, "res://game/audio/sfx/%s.wav", sfx_id) as AudioStream
		if stream != null:
			_sfx.stream = stream
			_sfx.play()
	if not step.stage_changed:
		return
	var stage: DialogueRunner.Stage = runner.stage
	var texture: Texture2D = _load_asset(SETTING_BACKGROUND_PATH, "res://game/dialogue/backgrounds/%s.png", stage.background) as Texture2D
	_background.texture = texture
	_placeholder_bg_label.text = ("[%s]" % stage.background) if texture == null and not stage.background.is_empty() else ""
	var music: AudioStream = _load_asset(SETTING_MUSIC_PATH, "res://game/audio/music/%s.ogg", stage.music) as AudioStream
	if music == null:
		_music.stop()
	elif _music.stream != music or not _music.playing:
		_music.stream = music
		_music.play()
	for slot: String in _portraits:
		_draw_portrait(slot, stage.actors.get(slot, {}))
	_draw_item(stage.item)


func _draw_portrait(slot: String, actor: Dictionary) -> void:
	var holder: Control = _portraits[slot]
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	holder.set_meta(&"speaker", str(actor.get("speaker", "")))
	if actor.is_empty():
		return
	var speaker: String = str(actor["speaker"])
	var expression: String = str(actor["expression"])
	var character: CharacterData = DataCatalog.character(speaker)
	var texture: Texture2D = character.get_portrait(StringName(expression)) if character != null else null
	if texture == null:
		texture = _load_asset(SETTING_PORTRAIT_PATH, "res://game/dialogue/portraits/%s.png", "%s_%s" % [speaker.to_lower(), expression]) as Texture2D
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.size = holder.size
		image.flip_h = slot == "right"
		holder.add_child(image)
		return
	# Placeholder portrait: a tinted card with the name and expression.
	var color: Color = character.name_color if character != null else Color(0.6, 0.6, 0.7)
	var card := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.size = holder.size
	holder.add_child(card)
	var initial := UiStyle.label(_speaker_name(speaker).left(1), 220, color.lightened(0.2))
	initial.size = Vector2(holder.size.x, 360)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(initial)
	var caption := UiStyle.label("%s\n(%s)" % [_speaker_name(speaker), expression], 30, Color.WHITE)
	caption.position = Vector2(0, 380)
	caption.size = Vector2(holder.size.x, 140)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(caption)


func _draw_item(item_id: String) -> void:
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()
	_item_panel.visible = not item_id.is_empty()
	if item_id.is_empty():
		return
	var item: ItemData = DataCatalog.item(item_id)
	var icon: Texture2D = item.icon if item != null else null
	if icon != null:
		var image := TextureRect.new()
		image.texture = icon
		image.custom_minimum_size = Vector2(160, 160)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_item_box.add_child(image)
	else:
		var box := ColorRect.new()
		box.color = Color(0.85, 0.75, 0.45, 0.35)
		box.custom_minimum_size = Vector2(160, 160)
		_item_box.add_child(box)
	var label := UiStyle.label(item.get_display_name() if item != null else item_id.capitalize(), 30, UiStyle.PANEL_BORDER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_box.add_child(label)
	_item_panel.reset_size()
	_item_panel.position = Vector2((_root.size.x - _item_panel.size.x) * 0.5, 180)


func _highlight_speaker(speaker: String) -> void:
	for slot: String in _portraits:
		var holder: Control = _portraits[slot]
		var shown: String = str(holder.get_meta(&"speaker", ""))
		holder.modulate = Color.WHITE if shown == speaker or shown.is_empty() else Color(0.55, 0.55, 0.6)


func _speaker_name(speaker: String) -> String:
	var character: CharacterData = DataCatalog.character(speaker)
	return character.get_display_name() if character != null else speaker.capitalize()


func _load_asset(setting: String, default_pattern: String, asset_id: String) -> Resource:
	if asset_id.is_empty():
		return null
	var path: String = str(ProjectSettings.get_setting(setting, default_pattern)) % asset_id
	if ResourceLoader.exists(path):
		return load(path)
	if not _warned_assets.has(path):
		_warned_assets[path] = true
		TacticsLog.info("Dialogue", "No asset at %s; using a placeholder" % path)
	return null


func _update_hint() -> void:
	_hint.text = tr("DIALOGUE_HINT") + ("    " + tr("DIALOGUE_AUTO_ON") if auto_mode else "")


func _speed() -> float:
	return 4.0 if _fast_forward() else 1.0


func _fast_forward() -> bool:
	return InputMap.has_action(&"speed_up") and Input.is_action_pressed(&"speed_up")


func _layout() -> void:
	var screen: Vector2 = _root.get_viewport_rect().size if _root.is_inside_tree() else Vector2(1920, 1080)
	_text_panel.position = Vector2(60, screen.y - 330)
	_text_panel.size = Vector2(screen.x - 120, 290)
	var y: float = screen.y - 330 - 600
	_portraits["left"].position = Vector2(120, y)
	_portraits["center"].position = Vector2((screen.x - 440) * 0.5, y)
	_portraits["right"].position = Vector2(screen.x - 560, y)
	_backlog.position = Vector2((screen.x - 1560) * 0.5, 80)
