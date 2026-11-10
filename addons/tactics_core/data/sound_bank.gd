@tool
class_name SoundBank
extends Resource
## Maps sound ids (e.g. [code]confirm[/code], [code]hit_slash[/code]) to
## audio files, with an optional volume per sound. The framework plays
## sounds only by id through [Sfx]; a game swaps sounds by editing its bank
## (project setting [code]tactics_core/audio/sound_bank[/code]). Ids missing
## from the bank are simply silent.

## Sound id → audio stream.
@export var sounds: Dictionary[StringName, AudioStream] = {}
## Sound id → volume offset in dB (missing = 0).
@export var volumes_db: Dictionary[StringName, float] = {}


func get_stream(sound_id: StringName) -> AudioStream:
	return sounds.get(sound_id, null)


func get_volume_db(sound_id: StringName) -> float:
	return volumes_db.get(sound_id, 0.0)
