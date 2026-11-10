extends GutTest
## Sound effects, HP/EXP bars, the EXP panel and level-up reveal.


func before_each() -> void:
	Sfx.recent.clear()


func test_bank_has_every_sound_the_game_uses() -> void:
	for sound_id: StringName in [&"cursor_move", &"menu_move", &"confirm", &"cancel", &"error", &"menu_open", &"text_blip",
			&"exp_tick", &"exp_full", &"level_up", &"stat_up", &"item_get", &"hit", &"miss", &"crit", &"stagger", &"defeat",
			&"heal", &"chain", &"awaken", &"rewind", &"phase_player", &"phase_enemy", &"victory", &"game_over"]:
		assert_true(Sfx.has_sound(sound_id), "missing sound '%s'" % sound_id)
	for path: String in DataCatalog.all_of("WeaponType").values().map(func(w: WeaponType) -> String: return w.resource_path):
		var weapon_type: WeaponType = load(path)
		assert_true(Sfx.has_sound(weapon_type.hit_sound), "%s hit sound '%s'" % [weapon_type.id, weapon_type.hit_sound])


func test_unknown_sound_is_silent_but_recorded() -> void:
	Sfx.play(&"no_such_sound")
	assert_eq(Sfx.recent.back(), &"no_such_sound")


func test_hit_sound_follows_weapon_type() -> void:
	var unit := UnitState.new()
	assert_eq(CombatPresenter.hit_sound(unit), &"hit", "unarmed")
	var sword: WeaponData = load("res://game/data/weapons/iron_sword.tres")
	assert_eq(sword.weapon_type.hit_sound, &"hit_slash", "swords slash")


func test_stat_bar_values_and_preview() -> void:
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.set_values(30, 20)
	assert_eq(bar.value, 20.0, "clamped to max")
	bar.set_preview(5)
	assert_eq(bar.loss_to, 5.0)
	assert_eq(bar.gain_to, -1.0)
	bar.set_values(10, 20)
	bar.set_preview(18)
	assert_eq(bar.gain_to, 18.0)
	watch_signals(bar)
	await bar.animate_to(4, 0.0)
	assert_eq(bar.value, 4.0)
	assert_signal_emitted(bar, "value_ticked")


func test_stat_bar_animates_over_time() -> void:
	var bar := StatBar.new()
	add_child_autofree(bar)
	bar.set_values(0, 100)
	var ticks: Array[int] = []
	bar.value_ticked.connect(func(shown: int) -> void: ticks.append(shown))
	await bar.animate_to(100, 0.3)
	assert_eq(bar.value, 100.0)
	assert_gt(ticks.size(), 3, "ticks along the way")
	assert_eq(ticks.back(), 100)


func test_exp_panel_wraps_and_chimes() -> void:
	var panel := ExpPanel.new()
	add_child_autofree(panel)
	await panel.play("Tellen", 90, 25, 100, 0.0)
	assert_true(Sfx.recent.has(&"exp_full"), "chimes when the bar fills")
	assert_eq(panel.bar.value, 15.0, "wrapped into the next level")
	assert_false(panel.visible)


func test_exp_panel_ticks_while_animating() -> void:
	var panel := ExpPanel.new()
	add_child_autofree(panel)
	panel.hold_seconds = 0.0
	await panel.play("Tellen", 10, 20, 100, 0.2)
	assert_true(Sfx.recent.has(&"exp_tick"))
	assert_false(Sfx.recent.has(&"exp_full"))
	assert_eq(panel.bar.value, 30.0)


func test_level_up_reveal() -> void:
	var panel := LevelUpPanel.new()
	add_child_autofree(panel)
	var ruleset: Ruleset = BattleFixtures.ruleset()
	var unit := UnitState.new()
	unit.stats = StatBlock.from_values({&"hp": 22, &"str": 7})
	var gains := StatBlock.from_values({&"hp": 1, &"str": 1})
	panel.show_level_up(unit, 2, gains, ruleset)
	await panel.reveal(0.0)
	assert_eq(Sfx.recent.front(), &"level_up")
	panel.close()
	assert_false(panel.visible)


func test_dialogue_voice_blips() -> void:
	var parsed: DialogueParser.Result = DialogueParser.parse("=== t ===\nTELLEN: Hello there, friend of mine.\n@end\n")
	assert_true(parsed.ok(), str(parsed.errors))
	var player := DialoguePlayer.new()
	player.text_speed = 200.0
	add_child_autofree(player)
	player.play(parsed.scripts[&"t"], {}, {})
	await wait_seconds(0.4)
	assert_true(Sfx.recent.has(&"text_blip"), "typing plays the speaker's voice")
	player.confirm()
	player.confirm()
