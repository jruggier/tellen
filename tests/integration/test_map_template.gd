extends GutTest
## The map template is a playable starting point (§12.1, M7.2).


func test_template_structure() -> void:
	var map: BattleMap = (load("res://game/maps/_template/map_template.tscn") as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	assert_not_null(map.definition)
	assert_not_null(map.get_node_or_null("Terrain"))
	assert_not_null(map.get_node_or_null("Decoration"))
	for group: String in ["PlayerSlots", "Enemies", "Allies", "Reinforcements", "Objectives", "Regions", "EventTiles"]:
		assert_not_null(map.get_node_or_null("Markers/" + group), group)
	assert_eq(map.get_player_spawns().size(), 4)
	assert_eq(map.get_map_id(), &"map_template")


func test_template_plays_with_test_roster() -> void:
	var scene: BattleScene = (load("res://game/scenes/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	scene.map_scene = load("res://game/maps/_template/map_template.tscn") as PackedScene
	scene.phase_banner_seconds = 0.0
	add_child_autofree(scene)
	await wait_process_frames(1)
	var state: BattleState = scene.controller.state
	assert_eq(state.units_of(&"player").size(), 4, "test roster fills the four slots")
	assert_eq(state.units_of(&"enemy").size(), 1)
	assert_eq(scene.input.state, PlayerInputController.State.IDLE)
