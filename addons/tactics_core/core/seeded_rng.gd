class_name SeededRng
extends RefCounted
## Deterministic random number service with independent named streams.
##
## Each stream is its own [RandomNumberGenerator] seeded from the master seed
## and the stream name, so the same master seed always produces the same
## sequence per stream, and draws on one stream never affect another.
## [method to_dict] / [method from_dict] capture the exact position of every
## stream, which is what rewind, replays and tests rely on.
##
## Stream states are serialized as strings because they are 64-bit integers
## and JSON numbers cannot hold them exactly.

var _master_seed: int = 0
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(master_seed: int = 0) -> void:
	reseed(master_seed)


## Resets every stream from [param master_seed]. Streams created later with
## [method ensure_stream] are also derived from this seed.
func reseed(master_seed: int) -> void:
	_master_seed = master_seed
	_streams.clear()
	for stream: StringName in TacticsIds.DEFAULT_STREAMS:
		ensure_stream(stream)


## The seed this service was last reseeded with.
func get_master_seed() -> int:
	return _master_seed


## Creates [param stream] if it does not exist. Safe to call repeatedly.
func ensure_stream(stream: StringName) -> void:
	if _streams.has(stream):
		return
	var generator := RandomNumberGenerator.new()
	generator.seed = _derive_seed(_master_seed, stream)
	_streams[stream] = generator


## Returns true if [param stream] exists.
func has_stream(stream: StringName) -> bool:
	return _streams.has(stream)


## Uniform integer in [code][from, to][/code] (inclusive) from [param stream].
func randi_range(stream: StringName, from: int, to: int) -> int:
	return _get(stream).randi_range(from, to)


## Uniform float in [code][0, 1][/code] from [param stream].
func randf(stream: StringName) -> float:
	return _get(stream).randf()


## Percentile roll: integer in [code][0, 99][/code]. A check with chance
## [code]p[/code] succeeds when [code]roll_100() < p[/code].
func roll_100(stream: StringName) -> int:
	return _get(stream).randi_range(0, 99)


## Serializes the master seed and the exact state of every stream.
func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for stream: StringName in _streams:
		states[String(stream)] = str(_streams[stream].state)
	return {
		"save_version": TacticsIds.SAVE_VERSION,
		"master_seed": str(_master_seed),
		"streams": states,
	}


## Restores state written by [method to_dict]. Returns false (and leaves the
## service unchanged) if [param data] is malformed.
func from_dict(data: Dictionary) -> bool:
	if not data.has("master_seed") or not data.has("streams") or not (data["streams"] is Dictionary):
		TacticsLog.warn("SeededRng", "from_dict: missing master_seed or streams")
		return false
	var master_text: String = str(data["master_seed"])
	if not master_text.is_valid_int():
		TacticsLog.warn("SeededRng", "from_dict: master_seed is not an integer: %s" % master_text)
		return false
	var raw_streams: Dictionary = data["streams"]
	var restored: Dictionary[StringName, RandomNumberGenerator] = {}
	for key: Variant in raw_streams:
		var state_text: String = str(raw_streams[key])
		if not state_text.is_valid_int():
			TacticsLog.warn("SeededRng", "from_dict: stream '%s' state is not an integer" % key)
			return false
		var generator := RandomNumberGenerator.new()
		generator.seed = _derive_seed(master_text.to_int(), StringName(str(key)))
		generator.state = state_text.to_int()
		restored[StringName(str(key))] = generator
	_master_seed = master_text.to_int()
	_streams = restored
	for stream: StringName in TacticsIds.DEFAULT_STREAMS:
		ensure_stream(stream)
	return true


## Returns an independent copy with identical state.
func duplicate_rng() -> SeededRng:
	var copy := SeededRng.new(_master_seed)
	copy.from_dict(to_dict())
	return copy


func _get(stream: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream):
		TacticsLog.warn("SeededRng", "Unknown stream '%s'; creating it" % stream)
		ensure_stream(stream)
	return _streams[stream]


static func _derive_seed(master_seed: int, stream: StringName) -> int:
	return hash("%d:%s" % [master_seed, stream])
