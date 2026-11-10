extends GutTest
## CampaignState, unit progress records and SaveSystem (spec M8.2).

const DATA: String = "res://game/data/"
## A slot no player uses, so tests never touch a real save.
const TEST_SLOT: int = 99


func after_each() -> void:
	SaveSystem.delete_save(TEST_SLOT)


func _state(unit_ids: Array[String]) -> BattleState:
	var map := BattleMap.new()
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	for y: int in 4:
		for x: int in 6:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	map.add_child(layer)
	var factions: Array[FactionData] = [load(DATA + "factions/player.tres"), load(DATA + "factions/enemy.tres")]
	map.factions = factions
	var placements: Array[UnitPlacement] = []
	for i: int in unit_ids.size():
		var p := UnitPlacement.new()
		p.unit_data = load(DATA + "units/%s.tres" % unit_ids[i]) as UnitData
		p.faction_id = &"player"
		p.cell = Vector2i(i, 0)
		placements.append(p)
	map.placements = placements
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 5)
	return controller.state


func _data() -> CampaignData:
	return load(DATA + "campaign/crossroads_campaign.tres") as CampaignData


func test_record_round_trip_keeps_progress_and_refills_hp() -> void:
	var state: BattleState = _state(["sable"])
	var sable: UnitState = state.get_unit(&"sable")
	sable.level += 2
	sable.experience = 37
	sable.stats.set_value(&"str", sable.stats.get_value(&"str") + 3)
	sable.proficiency_points[&"knife"] = 4
	sable.inventory.remove_at(sable.inventory.size() - 1)
	sable.current_hp = 1
	var record: Dictionary = JSON.parse_string(JSON.stringify(sable.to_record()))
	var fresh: UnitState = _state(["sable"]).get_unit(&"sable")
	fresh.apply_record(record, BattleFixtures.ruleset())
	assert_eq(fresh.level, sable.level)
	assert_eq(fresh.experience, 37)
	assert_eq(fresh.stats.get_value(&"str"), sable.stats.get_value(&"str"))
	assert_eq(fresh.proficiency_points.get(&"knife", 0), 4)
	assert_eq(fresh.inventory.size(), sable.inventory.size())
	assert_eq(fresh.class_data, sable.class_data)
	assert_eq(fresh.current_hp, fresh.max_hp(BattleFixtures.ruleset()), "HP refills between maps")


func test_unknown_item_is_dropped_not_fatal() -> void:
	var unit: UnitState = _state(["gid"]).get_unit(&"gid")
	var record: Dictionary = unit.to_record()
	(record["inventory"] as Array).append(["no_such_item", 1])
	var count: int = unit.inventory.size()
	unit.apply_record(record, BattleFixtures.ruleset())
	assert_eq(unit.inventory.size(), count)


func test_start_and_joins() -> void:
	var data: CampaignData = _data()
	var campaign := CampaignState.new()
	campaign.start(data)
	assert_eq(campaign.roster, [&"tellen", &"sable", &"gid"] as Array[StringName])
	campaign.prepare_chapter(data)
	assert_eq(campaign.roster.size(), 3, "ch00 has no joins")
	campaign.chapter_index = 1
	campaign.prepare_chapter(data)
	assert_eq(campaign.roster.size(), 6, "ch01 brings three recruits")
	campaign.prepare_chapter(data)
	assert_eq(campaign.roster.size(), 6, "joining twice adds nobody")
	campaign.chapter_index = 2
	assert_null(campaign.current_chapter(data), "campaign finished")


func test_absorb_then_apply_carries_levels() -> void:
	var campaign := CampaignState.new()
	campaign.start(_data())
	var state: BattleState = _state(["tellen", "sable"])
	state.get_unit(&"tellen").level = 9
	state.get_unit(&"sable").retreated = true
	campaign.absorb_battle(state)
	assert_true(campaign.records.has("sable"), "retreated units still carry over")
	var next: BattleState = _state(["tellen", "sable"])
	campaign.apply_records(next)
	assert_eq(next.get_unit(&"tellen").level, 9)


func test_roster_units_resolve() -> void:
	var campaign := CampaignState.new()
	campaign.start(_data())
	var units: Array[UnitData] = campaign.roster_units()
	assert_eq(units.size(), 3)
	assert_eq(units[0].id, &"tellen")


func test_save_and_load_round_trip() -> void:
	var campaign := CampaignState.new()
	campaign.start(_data())
	campaign.chapter_index = 1
	campaign.flags["paid_toll"] = true
	campaign.absorb_battle(_state(["tellen"]))
	assert_eq(SaveSystem.save(campaign, TEST_SLOT), OK)
	assert_true(SaveSystem.has_save(TEST_SLOT))
	var loaded: CampaignState = SaveSystem.load_save(TEST_SLOT)
	assert_not_null(loaded)
	assert_eq(loaded.chapter_index, 1)
	assert_eq(loaded.roster, campaign.roster)
	assert_eq(loaded.flags.get("paid_toll"), true)
	assert_eq(int(loaded.records["tellen"]["level"]), int(campaign.records["tellen"]["level"]))


func test_corrupt_save_is_refused() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_DIR))
	var file := FileAccess.open(SaveSystem.path_for(TEST_SLOT), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(SaveSystem.load_save(TEST_SLOT))


func test_campaign_data_validates() -> void:
	assert_eq(_data().validate().size(), 0, str(_data().validate()))
