class_name TitleScreen
extends Control
## Title screen: New Game, Continue, Settings, Quit (spec M8.3). Starting a
## new game over an existing save asks first. Scene paths and the campaign
## come from [CampaignFlow], so the screen itself is game-agnostic.

## Translation key of the game title.
@export var title_key: String = "UI_GAME_TITLE"
## Translation key of the line under the title.
@export var subtitle_key: String = "UI_GAME_SUBTITLE"
## Background color behind everything.
@export var background_color: Color = Color(0.06, 0.07, 0.1)

var menu := MenuList.new()
var settings_panel := SettingsPanel.new()
var _message := UiStyle.label("", 28, UiStyle.GOOD)
var _confirming_new: bool = false
var _heading := VBoxContainer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = background_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var heading: VBoxContainer = _heading
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 200
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)
	var title := UiStyle.label(tr(title_key), 120, UiStyle.PANEL_BORDER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(title)
	var subtitle := UiStyle.label(tr(subtitle_key), 36, UiStyle.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(subtitle)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(_message)
	add_child(menu)
	menu.chosen.connect(_on_chosen)
	add_child(settings_panel)
	settings_panel.closed.connect(_open_main_menu)
	var params: Dictionary = SceneRouter.take_params()
	if bool(params.get("completed", false)):
		_message.text = tr("UI_TITLE_COMPLETED")
	_open_main_menu()


func _open_main_menu() -> void:
	_confirming_new = false
	_heading.visible = true
	var has_save: bool = SaveSystem.has_save(CampaignFlow.SLOT)
	var options: Array[Dictionary] = []
	if has_save:
		options.append({"id": &"continue", "text": tr("UI_TITLE_CONTINUE")})
	options.append({"id": &"new_game", "text": tr("UI_TITLE_NEW_GAME")})
	options.append({"id": &"settings", "text": tr("UI_TITLE_SETTINGS")})
	if not OS.has_feature("web"):
		options.append({"id": &"quit", "text": tr("UI_TITLE_QUIT")})
	_open_menu(options, "")


func _open_menu(options: Array[Dictionary], heading: String) -> void:
	menu.open(options, Vector2.ZERO, heading)
	_center_menu.call_deferred()


func _center_menu() -> void:
	menu.position = Vector2((size.x - menu.size.x) * 0.5, 620).floor()


func _on_chosen(option_id: StringName) -> void:
	match option_id:
		&"continue":
			menu.close()
			CampaignFlow.continue_game()
		&"new_game":
			if SaveSystem.has_save(CampaignFlow.SLOT) and not _confirming_new:
				_confirming_new = true
				var options: Array[Dictionary] = [{"id": &"confirm_new", "text": tr("UI_TITLE_CONFIRM_NEW")}, {"id": &"back", "text": tr("UI_TITLE_BACK")}]
				_open_menu(options, tr("UI_TITLE_OVERWRITE"))
				return
			menu.close()
			CampaignFlow.new_game()
		&"confirm_new":
			menu.close()
			CampaignFlow.new_game()
		&"back":
			_open_main_menu()
		&"settings":
			menu.close()
			_heading.visible = false
			settings_panel.open()
		&"quit":
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not menu.visible:
		return
	if event.is_action_pressed(&"cursor_up", true):
		menu.move(-1)
	elif event.is_action_pressed(&"cursor_down", true):
		menu.move(1)
	elif event.is_action_pressed(&"confirm") and not event.is_echo():
		menu.accept()
	elif event.is_action_pressed(&"cancel") and not event.is_echo() and _confirming_new:
		_open_main_menu()
	else:
		return
	get_viewport().set_input_as_handled()
