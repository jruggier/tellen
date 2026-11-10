class_name CampaignFlow
extends RefCounted
## Moves the game between the title, chapters and the ending, saving at
## the start of every chapter (spec M8). Scene paths and the campaign come
## from project settings so the framework stays game-agnostic.

const SETTING_CAMPAIGN: String = "tactics_core/flow/campaign"
const DEFAULT_CAMPAIGN: String = "res://game/data/campaign/crossroads_campaign.tres"
const SETTING_TITLE_SCENE: String = "tactics_core/flow/title_scene"
const DEFAULT_TITLE_SCENE: String = "res://game/scenes/title.tscn"
## The save slot used by the prototype (one slot).
const SLOT: int = 1


## The project's campaign, or null.
static func campaign_data() -> CampaignData:
	var path: String = str(ProjectSettings.get_setting(SETTING_CAMPAIGN, DEFAULT_CAMPAIGN))
	return load(path) as CampaignData if ResourceLoader.exists(path) else null


## Starts a new campaign and its first chapter.
static func new_game() -> void:
	var data: CampaignData = campaign_data()
	if data == null:
		TacticsLog.error("CampaignFlow", "No campaign data")
		return
	var campaign := CampaignState.new()
	campaign.start(data)
	play_current_chapter(campaign, data)


## Continues from the save, or starts a new game if there is none.
static func continue_game() -> void:
	var data: CampaignData = campaign_data()
	var campaign: CampaignState = SaveSystem.load_save(SLOT)
	if campaign == null or data == null:
		new_game()
		return
	play_current_chapter(campaign, data)


## Saves and opens the current chapter (or the ending when none are left).
static func play_current_chapter(campaign: CampaignState, data: CampaignData) -> void:
	var chapter: ChapterData = campaign.current_chapter(data)
	if chapter == null:
		SaveSystem.save(campaign, SLOT)  # remember the campaign is finished
		go_to_title({"completed": true})
		return
	campaign.prepare_chapter(data)
	SaveSystem.save(campaign, SLOT)
	var battle_path: String = str(ProjectSettings.get_setting(BattleMap.SETTING_BATTLE_SCENE, BattleMap.DEFAULT_BATTLE_SCENE))
	SceneRouter.go_to(battle_path, {"campaign": campaign, "campaign_data": data, "map_path": chapter.map_path})


## After a victory: keep the units' progress, advance, save, continue.
static func complete_chapter(campaign: CampaignState, data: CampaignData, state: BattleState) -> void:
	campaign.absorb_battle(state)
	campaign.chapter_index += 1
	play_current_chapter(campaign, data)


## After a defeat: reload the chapter's starting save and try again.
static func retry_chapter(data: CampaignData) -> void:
	var campaign: CampaignState = SaveSystem.load_save(SLOT)
	if campaign == null:
		new_game()
		return
	play_current_chapter(campaign, data)


static func go_to_title(params: Dictionary = {}) -> void:
	SceneRouter.go_to(str(ProjectSettings.get_setting(SETTING_TITLE_SCENE, DEFAULT_TITLE_SCENE)), params)
