extends GutTest
## Movement ranges with terrain costs per movement type, paths, attack
## ranges, occupancy rules, zone of control and the threat map (§7.3).


func _cells(dict: Dictionary) -> Array[Vector2i]:
	return MoveRange._sorted(dict.keys())


func test_open_field_diamond() -> void:
	var battle: BattleState = BattleFixtures.state([".........", ".........", ".........", ".........", "........."])
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(4, 2))
	var move_range: MoveRange = RangeCalculator.movement(battle, unit)
	assert_eq(unit.mov(battle.ruleset), 4)
	# Manhattan diamond of radius 4 clipped to 9x5: count cells with distance <= 4
	var expected: int = 0
	for y: int in 5:
		for x: int in 9:
			if BattleGrid.distance(Vector2i(x, y), Vector2i(4, 2)) <= 4:
				expected += 1
	assert_eq(move_range.stop_cells().size(), expected)
	assert_eq(move_range.cost_to(Vector2i(0, 2)), 4)
	assert_false(move_range.can_reach(Vector2i(0, 1)), "distance 5")


func test_forest_costs_differ_by_movement_type() -> void:
	# start on the left, forest strip in the middle
	var rows: PackedStringArray = ["..FF.."]
	var battle: BattleState = BattleFixtures.state(rows)
	var foot: UnitState = BattleFixtures.add(battle, &"foot", "sellsword", &"player", Vector2i(0, 0))
	var foot_range: MoveRange = RangeCalculator.movement(battle, foot)
	assert_eq(foot_range.cost_to(Vector2i(2, 0)), 3, "1 + forest 2 (foot)")
	assert_eq(foot_range.cost_to(Vector2i(3, 0)), -1, "1 + 2 + 2 = 5 > 4")

	var battle2: BattleState = BattleFixtures.state(rows)
	var rider: UnitState = BattleFixtures.add(battle2, &"rider", "outrider", &"player", Vector2i(0, 0))
	var rider_range: MoveRange = RangeCalculator.movement(battle2, rider)
	assert_eq(rider.mov(battle2.ruleset), 5)
	assert_eq(rider_range.cost_to(Vector2i(2, 0)), 4, "1 + forest 3 (ground)")
	assert_false(rider_range.can_reach(Vector2i(3, 0)))

	var battle3: BattleState = BattleFixtures.state(rows)
	var flier: UnitState = BattleFixtures.add(battle3, &"flier", "wingrider", &"player", Vector2i(0, 0))
	assert_eq(RangeCalculator.movement(battle3, flier).cost_to(Vector2i(5, 0)), 5, "sky pays 1 everywhere")


func test_water_wall_doorway() -> void:
	var rows: PackedStringArray = [".~.", ".#.", ".D."]
	var battle: BattleState = BattleFixtures.state(rows)
	var flier: UnitState = BattleFixtures.add(battle, &"flier", "wingrider", &"player", Vector2i(0, 0))
	var sky: MoveRange = RangeCalculator.movement(battle, flier)
	assert_true(sky.can_reach(Vector2i(1, 0)), "sky crosses water")
	assert_false(sky.can_reach(Vector2i(1, 1)), "nobody enters walls")
	assert_false(sky.can_reach(Vector2i(1, 2)), "sky cannot use doorways")
	var foot: UnitState = BattleFixtures.add(battle, &"foot", "sellsword", &"player", Vector2i(0, 2))
	var walk: MoveRange = RangeCalculator.movement(battle, foot)
	assert_false(walk.can_reach(Vector2i(1, 0)), "foot cannot swim")
	assert_true(walk.can_reach(Vector2i(1, 2)), "foot uses doorways")
	assert_true(walk.can_reach(Vector2i(2, 0)), "around through the doorway: 4 steps")


func test_heavy_pays_three_on_hills() -> void:
	var battle: BattleState = BattleFixtures.state([".HH"])
	var armor: UnitState = BattleFixtures.add(battle, &"armor", "bulwark", &"player", Vector2i(0, 0))
	var move_range: MoveRange = RangeCalculator.movement(battle, armor)
	assert_eq(move_range.cost_to(Vector2i(1, 0)), 3)
	assert_false(move_range.can_reach(Vector2i(2, 0)))


func test_cheapest_path_avoids_forest() -> void:
	# through three forests costs 2+2+2+1 = 7; around them costs 1+4+1 = 6
	var battle: BattleState = BattleFixtures.state([".FFF.", "....."])
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(0, 0))
	unit.stats.set_value(&"mov", 10)
	var move_range: MoveRange = RangeCalculator.movement(battle, unit)
	assert_eq(move_range.cost_to(Vector2i(4, 0)), 6)
	var path: Array[Vector2i] = move_range.path_to(Vector2i(4, 0))
	assert_eq(path.front(), Vector2i(0, 0))
	assert_eq(path.back(), Vector2i(4, 0))
	var total: int = 0
	for i: int in range(1, path.size()):
		assert_eq(BattleGrid.distance(path[i - 1], path[i]), 1, "contiguous")
		total += battle.grid.move_cost(path[i], &"foot")
		assert_ne(battle.grid.terrain_at(path[i]).id, &"forest", "path avoids forest")
	assert_eq(total, 6, "path cost matches")
	assert_eq(move_range.path_to(Vector2i(9, 9)), [] as Array[Vector2i])


func test_paths_are_deterministic() -> void:
	var rows: PackedStringArray = [".....", ".....", "....."]
	var a: BattleState = BattleFixtures.state(rows)
	var b: BattleState = BattleFixtures.state(rows)
	var ua: UnitState = BattleFixtures.add(a, &"u", "sellsword", &"player", Vector2i(0, 0))
	var ub: UnitState = BattleFixtures.add(b, &"u", "sellsword", &"player", Vector2i(0, 0))
	assert_eq(RangeCalculator.movement(a, ua).path_to(Vector2i(2, 2)), RangeCalculator.movement(b, ub).path_to(Vector2i(2, 2)))


func test_allies_passable_not_stoppable_enemies_block() -> void:
	var battle: BattleState = BattleFixtures.state(["......"])
	var unit: UnitState = BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0))
	BattleFixtures.add(battle, &"friend", "sellsword", &"player", Vector2i(1, 0))
	var move_range: MoveRange = RangeCalculator.movement(battle, unit)
	assert_true(move_range.can_reach(Vector2i(1, 0)))
	assert_false(move_range.can_stop_at(Vector2i(1, 0)), "cannot stop on an ally")
	assert_true(move_range.can_stop_at(Vector2i(2, 0)), "passes through the ally")
	assert_true(move_range.can_stop_at(Vector2i(0, 0)), "can stay put")
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(3, 0))
	move_range = RangeCalculator.movement(battle, unit)
	assert_false(move_range.can_reach(Vector2i(3, 0)), "enemy blocks")
	assert_false(move_range.can_reach(Vector2i(4, 0)), "cannot pass the enemy")


func test_allied_faction_is_passable() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	var unit: UnitState = BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0))
	BattleFixtures.add(battle, &"npc", "sellsword", &"ally", Vector2i(1, 0))
	assert_true(RangeCalculator.movement(battle, unit).can_stop_at(Vector2i(2, 0)))


func test_zone_of_control() -> void:
	var ruleset: Ruleset = BattleFixtures.ruleset().duplicate() as Ruleset
	ruleset.zone_of_control = true
	var battle: BattleState = BattleFixtures.state([".....", "....."], ruleset)
	var unit: UnitState = BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(2, 1))
	assert_true(RangeCalculator.movement(battle, unit).can_reach(Vector2i(4, 0)), "foe without zoc tag: free movement")
	foe.tags.append(&"zoc")
	battle.mark_changed()
	var move_range: MoveRange = RangeCalculator.movement(battle, unit)
	assert_true(move_range.can_stop_at(Vector2i(2, 0)), "may enter the zone")
	assert_false(move_range.can_reach(Vector2i(3, 0)), "but must stop there")


func test_attack_cells_from_every_stop_cell() -> void:
	var battle: BattleState = BattleFixtures.state(["......."])
	var archer: UnitState = BattleFixtures.add(battle, &"archer", "hunter", &"player", Vector2i(0, 0), ["iron_bow"])
	archer.stats.set_value(&"mov", 1)
	var move_range: MoveRange = RangeCalculator.movement(battle, archer)
	var attack: Dictionary[Vector2i, bool] = RangeCalculator.attack_cells(battle, archer, move_range)
	# stop cells x=0 and x=1; a bow hits exactly 2 away → x=2 and x=3
	assert_eq(_cells(attack), [Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i])


func test_unarmed_unit_has_no_attack_range() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(0, 0))
	assert_eq(RangeCalculator.attack_cells(battle, unit, RangeCalculator.movement(battle, unit)).size(), 0)


func test_unusable_weapon_gives_no_range() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(0, 0), ["iron_axe"])
	assert_null(unit.equipped_weapon(), "sellswords cannot use axes")
	assert_eq(unit.attack_ranges().size(), 0)


func test_cells_at_range_ring() -> void:
	var grid: BattleGrid = BattleFixtures.state([".....", ".....", "....."]).grid
	assert_eq(RangeCalculator.cells_at_range(grid, Vector2i(2, 1), 2, 2).size(), 6, "ring of radius 2 clipped to 5x3")
	assert_eq(RangeCalculator.cells_at_range(grid, Vector2i(2, 1), 1, 1).size(), 4)


func test_threat_map_union_and_cache() -> void:
	var battle: BattleState = BattleFixtures.state(["..........", ".........."])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0), ["iron_sword"])
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(9, 0), ["iron_axe"])
	var threat := ThreatMap.new()
	var danger: Dictionary[Vector2i, bool] = threat.for_enemies_of(battle, &"player")
	assert_true(danger.has(Vector2i(5, 0)), "move 4 → x=5")
	assert_true(danger.has(Vector2i(4, 0)), "+1 attack range → x=4")
	assert_false(danger.has(Vector2i(3, 0)))
	var entry: ThreatMap.Entry = threat.for_unit(battle, &"foe")
	assert_same(threat.for_unit(battle, &"foe"), entry, "cached while nothing changes")
	battle.move_unit(&"foe", Vector2i(8, 0))
	var moved: ThreatMap.Entry = threat.for_unit(battle, &"foe")
	assert_ne(moved, entry, "recomputed after a move")
	assert_true(threat.for_enemies_of(battle, &"player").has(Vector2i(3, 0)))
	assert_eq(threat.for_enemies_of(battle, &"enemy").size(), threat.for_unit(battle, &"me").all_cells().size(), "viewer's own side excluded")


func test_threat_ignores_defeated_units() -> void:
	var battle: BattleState = BattleFixtures.state(["....."])
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(4, 0), ["iron_axe"])
	foe.current_hp = 0
	battle.remove_from_map(&"foe")
	assert_eq(ThreatMap.new().for_enemies_of(battle, &"player").size(), 0)


func test_large_map_performance() -> void:
	var rows: PackedStringArray = []
	for y: int in 40:
		rows.append(".F.H.R.U..".repeat(4))
	var battle: BattleState = BattleFixtures.state(rows)
	for i: int in 40:
		var faction: StringName = &"player" if i < 20 else &"enemy"
		BattleFixtures.add(battle, StringName("u%d" % i), "outrider", faction, Vector2i((i * 7) % 40, (i * 3) % 40 if i < 20 else 39 - (i % 20)), ["javelin"])
	var started: int = Time.get_ticks_usec()
	var threat: Dictionary[Vector2i, bool] = ThreatMap.new().for_enemies_of(battle, &"player")
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	assert_gt(threat.size(), 0)
	assert_lt(elapsed_ms, 200.0, "20 enemy ranges on 40x40 in %.1f ms" % elapsed_ms)
