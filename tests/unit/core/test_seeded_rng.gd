extends GutTest
## SeededRng: determinism, stream independence and exact serialization.


func _draw(rng: SeededRng, stream: StringName, count: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.randi_range(stream, 0, 1_000_000))
	return values


func test_same_seed_gives_same_sequence() -> void:
	var a := SeededRng.new(1234)
	var b := SeededRng.new(1234)
	assert_eq(_draw(a, TacticsIds.STREAM_COMBAT, 20), _draw(b, TacticsIds.STREAM_COMBAT, 20))


func test_different_seeds_differ() -> void:
	var a := SeededRng.new(1)
	var b := SeededRng.new(2)
	assert_ne(_draw(a, TacticsIds.STREAM_COMBAT, 20), _draw(b, TacticsIds.STREAM_COMBAT, 20))


func test_streams_are_independent() -> void:
	var a := SeededRng.new(99)
	var b := SeededRng.new(99)
	_draw(b, TacticsIds.STREAM_GROWTH, 50)  # extra draws on another stream
	assert_eq(_draw(a, TacticsIds.STREAM_COMBAT, 20), _draw(b, TacticsIds.STREAM_COMBAT, 20))


func test_streams_produce_different_sequences() -> void:
	var rng := SeededRng.new(7)
	var copy := SeededRng.new(7)
	assert_ne(_draw(rng, TacticsIds.STREAM_COMBAT, 20), _draw(copy, TacticsIds.STREAM_AI, 20))


func test_default_streams_exist() -> void:
	var rng := SeededRng.new(0)
	for stream: StringName in TacticsIds.DEFAULT_STREAMS:
		assert_true(rng.has_stream(stream), "missing stream %s" % stream)


func test_roll_100_range() -> void:
	var rng := SeededRng.new(5)
	for i: int in 2000:
		var roll: int = rng.roll_100(TacticsIds.STREAM_COMBAT)
		assert_between(roll, 0, 99)
		if roll < 0 or roll > 99:
			return


func test_round_trip_restores_exact_position() -> void:
	var rng := SeededRng.new(424242)
	_draw(rng, TacticsIds.STREAM_COMBAT, 13)
	_draw(rng, TacticsIds.STREAM_GROWTH, 4)
	var saved: Dictionary = rng.to_dict()
	var expected_combat: Array[int] = _draw(rng, TacticsIds.STREAM_COMBAT, 10)
	var expected_growth: Array[int] = _draw(rng, TacticsIds.STREAM_GROWTH, 10)

	var restored := SeededRng.new(0)
	assert_true(restored.from_dict(saved))
	assert_eq(restored.get_master_seed(), 424242)
	assert_eq(_draw(restored, TacticsIds.STREAM_COMBAT, 10), expected_combat)
	assert_eq(_draw(restored, TacticsIds.STREAM_GROWTH, 10), expected_growth)


func test_round_trip_survives_json() -> void:
	var rng := SeededRng.new(-987654321)
	_draw(rng, TacticsIds.STREAM_MISC, 7)
	var json: String = JSON.stringify(rng.to_dict())
	var expected: Array[int] = _draw(rng, TacticsIds.STREAM_MISC, 10)

	var parsed: Variant = JSON.parse_string(json)
	assert_true(parsed is Dictionary)
	var restored := SeededRng.new(0)
	assert_true(restored.from_dict(parsed))
	assert_eq(_draw(restored, TacticsIds.STREAM_MISC, 10), expected)


func test_to_dict_has_save_version() -> void:
	assert_eq(SeededRng.new(1).to_dict().get("save_version"), TacticsIds.SAVE_VERSION)


func test_from_dict_rejects_malformed_and_keeps_state() -> void:
	var rng := SeededRng.new(55)
	var before: Dictionary = rng.to_dict()
	assert_false(rng.from_dict({}))
	assert_false(rng.from_dict({"master_seed": "abc", "streams": {}}))
	assert_false(rng.from_dict({"master_seed": "1", "streams": {"combat": "not a number"}}))
	assert_eq(rng.to_dict(), before)
	assert_push_warning_count(3)


func test_duplicate_is_independent_copy() -> void:
	var rng := SeededRng.new(31)
	_draw(rng, TacticsIds.STREAM_COMBAT, 3)
	var copy: SeededRng = rng.duplicate_rng()
	var expected: Array[int] = _draw(rng, TacticsIds.STREAM_COMBAT, 5)
	assert_eq(_draw(copy, TacticsIds.STREAM_COMBAT, 5), expected)


func test_unknown_stream_is_created_with_warning() -> void:
	var rng := SeededRng.new(3)
	rng.roll_100(&"custom")
	assert_true(rng.has_stream(&"custom"))
	assert_push_warning_count(1)
