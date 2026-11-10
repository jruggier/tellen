extends Node
## Global access to the active [SeededRng], registered as the
## [code]TacticsRng[/code] autoload.
##
## Battle code should prefer the RNG owned by its battle state (so snapshots
## capture it); this autoload exists for systems outside a battle and holds
## whichever [SeededRng] is current. Call [method set_rng] when a battle
## starts so both point at the same instance.

## Emitted after [method reseed] or [method set_rng].
signal rng_replaced(rng: SeededRng)

var _rng: SeededRng = SeededRng.new(0)


func _ready() -> void:
	reseed(_initial_seed())


## The active RNG service.
func get_rng() -> SeededRng:
	return _rng


## Replaces the active RNG (e.g. with the one owned by a loaded battle).
func set_rng(rng: SeededRng) -> void:
	if rng == null:
		TacticsLog.error("TacticsRng", "set_rng called with null")
		return
	_rng = rng
	rng_replaced.emit(_rng)


## Starts a fresh RNG from [param master_seed].
func reseed(master_seed: int) -> void:
	_rng = SeededRng.new(master_seed)
	TacticsLog.debug("TacticsRng", "Seed %d" % master_seed)
	rng_replaced.emit(_rng)


## Uniform integer in [code][from, to][/code] from [param stream].
func randi_range(stream: StringName, from: int, to: int) -> int:
	return _rng.randi_range(stream, from, to)


## Percentile roll in [code][0, 99][/code] from [param stream].
func roll_100(stream: StringName) -> int:
	return _rng.roll_100(stream)


func _initial_seed() -> int:
	# Unseeded runs vary; tests and replays always reseed explicitly.
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator.randi()
