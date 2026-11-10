class_name Sfx
extends RefCounted
## Plays sound effects by id from the project's [SoundBank], on the
## [code]SFX[/code] bus (spec §2a.5 volumes).
##
## [code]Sfx.play(&"confirm")[/code] works from anywhere: the first call adds
## a small pool of players under the scene tree root, which survives scene
## changes. Unknown ids are silent (logged once in debug builds), so content
## can reference sounds that don't exist yet. The last plays are kept in
## [member recent] for tests and the debug overlay.

const SETTING_BANK: String = "tactics_core/audio/sound_bank"
const DEFAULT_BANK: String = "res://game/audio/sound_bank.tres"
## Simultaneous sounds before the oldest is cut off.
const POOL_SIZE: int = 12
const RECENT_SIZE: int = 32

## Ids played most recently (oldest first).
static var recent: Array[StringName] = []
## False mutes everything played through [Sfx] (e.g. headless tools).
static var enabled: bool = true

static var _bank: SoundBank = null
static var _bank_loaded: bool = false
static var _pool: Node = null
static var _next: int = 0
static var _warned: Dictionary[StringName, bool] = {}


## Plays [param sound_id]. [param pitch] scales playback speed (and pitch);
## [param volume_db] is added to the bank's volume.
static func play(sound_id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if sound_id == &"" or not enabled:
		return
	recent.append(sound_id)
	if recent.size() > RECENT_SIZE:
		recent.remove_at(0)
	var bank: SoundBank = get_bank()
	var stream: AudioStream = bank.get_stream(sound_id) if bank != null else null
	if stream == null:
		if OS.is_debug_build() and not _warned.has(sound_id):
			_warned[sound_id] = true
			TacticsLog.debug("Sfx", "No sound for '%s'" % sound_id)
		return
	var player: AudioStreamPlayer = _take_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.05, 8.0)
	player.volume_db = bank.get_volume_db(sound_id) + volume_db
	if player.is_inside_tree():
		player.play()
	else:
		player.play.call_deferred()  # the pool joins the tree at the end of this frame


## True if [param sound_id] has a sound in the bank.
static func has_sound(sound_id: StringName) -> bool:
	var bank: SoundBank = get_bank()
	return bank != null and bank.get_stream(sound_id) != null


## The active bank (loaded on first use), or null.
static func get_bank() -> SoundBank:
	if not _bank_loaded:
		_bank_loaded = true
		var path: String = str(ProjectSettings.get_setting(SETTING_BANK, DEFAULT_BANK))
		if ResourceLoader.exists(path):
			_bank = load(path) as SoundBank
		if _bank == null:
			TacticsLog.warn("Sfx", "No SoundBank at %s; sounds are off" % path)
	return _bank


## Replaces the bank (tests, or a game switching sound sets).
static func set_bank(bank: SoundBank) -> void:
	_bank = bank
	_bank_loaded = true


static func _take_player() -> AudioStreamPlayer:
	if _pool == null or not is_instance_valid(_pool):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return null
		_pool = Node.new()
		_pool.name = "SfxPool"
		_pool.process_mode = Node.PROCESS_MODE_ALWAYS
		for i: int in POOL_SIZE:
			var player := AudioStreamPlayer.new()
			player.bus = GameSettings.SFX_BUS
			_pool.add_child(player)
		tree.root.add_child.call_deferred(_pool)
	# Prefer an idle player; otherwise reuse the oldest.
	for i: int in POOL_SIZE:
		var index: int = (_next + i) % POOL_SIZE
		var candidate: AudioStreamPlayer = _pool.get_child(index) as AudioStreamPlayer
		if not candidate.playing:
			_next = (index + 1) % POOL_SIZE
			return candidate
	var oldest: AudioStreamPlayer = _pool.get_child(_next) as AudioStreamPlayer
	_next = (_next + 1) % POOL_SIZE
	return oldest
