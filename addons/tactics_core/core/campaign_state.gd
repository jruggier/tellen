class_name CampaignState
extends Resource
## Everything that persists between maps (spec M8): campaign flags, the
## roster, each named unit's progress, and the current chapter.
##
## Progress records are plain dictionaries (see [method UnitState.to_record])
## keyed by unit id, so the whole state saves as JSON. Generic units (no
## [UnitData]) aren't carried between maps.

## Version for save migration (see [SaveMigrator]).
@export var save_version: int = TacticsIds.SAVE_VERSION
## Flag name → value (dialogue flags without the map. prefix).
@export var flags: Dictionary = {}
## Campaign id (which [CampaignData] this follows).
@export var campaign_id: StringName = &""
## Index of the next chapter to play.
@export var chapter_index: int = 0
## Unit ids in roster order.
@export var roster: Array[StringName] = []
## Unit id → progress record.
@export var records: Dictionary = {}


## Starts a new run of [param data].
func start(data: CampaignData) -> void:
	campaign_id = data.id
	chapter_index = 0
	flags = {}
	records = {}
	roster.clear()
	for unit: UnitData in data.starting_units:
		_add_to_roster(unit.id)


## Adds the units joining before the current chapter.
func prepare_chapter(data: CampaignData) -> void:
	if chapter_index < data.chapters.size():
		for unit: UnitData in data.chapters[chapter_index].joins:
			_add_to_roster(unit.id)


## The current chapter, or null when the campaign is finished.
func current_chapter(data: CampaignData) -> ChapterData:
	return data.chapters[chapter_index] if chapter_index < data.chapters.size() else null


## Roster as [UnitData] (deployment order).
func roster_units() -> Array[UnitData]:
	var result: Array[UnitData] = []
	var catalog: Dictionary = DataCatalog.all_of("UnitData")
	for unit_id: StringName in roster:
		var unit: UnitData = catalog.get(unit_id, null) as UnitData
		if unit != null:
			result.append(unit)
		else:
			TacticsLog.warn("Campaign", "Roster unit '%s' not found in the data folders" % unit_id)
	return result


## Copies saved progress onto the matching player units of [param state].
func apply_records(state: BattleState) -> void:
	for unit: UnitState in state.all_units():
		if unit.unit_data != null and records.has(String(unit.unit_data.id)):
			unit.apply_record(records[String(unit.unit_data.id)], state.ruleset)


## Records the progress of every named unit of the human faction after a
## battle (retreated units included; they return next map).
func absorb_battle(state: BattleState) -> void:
	var human: FactionData = state.human_faction()
	if human == null:
		return
	for unit: UnitState in state.all_units():
		if unit.faction_id == human.id and unit.unit_data != null:
			records[String(unit.unit_data.id)] = unit.to_record()
			_add_to_roster(unit.unit_data.id)


## JSON-safe form.
func to_dict() -> Dictionary:
	var roster_strings: Array[String] = []
	for unit_id: StringName in roster:
		roster_strings.append(String(unit_id))
	return {
		"save_version": TacticsIds.SAVE_VERSION,
		"campaign_id": String(campaign_id),
		"chapter_index": chapter_index,
		"roster": roster_strings,
		"records": records.duplicate(true),
		"flags": flags.duplicate(true),
	}


## Builds a campaign from [method to_dict] output (already migrated).
static func from_dict(data: Dictionary) -> CampaignState:
	var campaign := CampaignState.new()
	campaign.campaign_id = StringName(str(data.get("campaign_id", "")))
	campaign.chapter_index = int(data.get("chapter_index", 0))
	for unit_id: Variant in data.get("roster", []):
		campaign.roster.append(StringName(str(unit_id)))
	campaign.records = (data.get("records", {}) as Dictionary).duplicate(true)
	campaign.flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	return campaign


func _add_to_roster(unit_id: StringName) -> void:
	if not roster.has(unit_id):
		roster.append(unit_id)
