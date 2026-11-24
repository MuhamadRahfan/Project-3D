extends Node

const POOL_SIZE := 10
const BGM_PATH := "res://assets/audio/bgm_grove.ogg"

const SFX_PATHS := {
	"swing": "res://assets/audio/swing.mp3",
	"bow": "res://assets/audio/bow.mp3",
	"magic": "res://assets/audio/magic.mp3",
	"shield": "res://assets/audio/shield.mp3",
	"hit": "res://assets/audio/hit.ogg",
	"hurt": "res://assets/audio/hurt.ogg",
	"enemy_die": "res://assets/audio/enemy_die.ogg",
	"dodge": "res://assets/audio/dodge.ogg",
	"pickup": "res://assets/audio/pickup.ogg",
	"upgrade": "res://assets/audio/upgrade.ogg",
	"explosion": "res://assets/audio/explosion.ogg",
	"game_over": "res://assets/audio/game_over.ogg",
	"spawn": "res://assets/audio/spawn.ogg",
	"click": "res://assets/audio/click.ogg",
}

var _players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var _next_idx: int = 0
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -13.0
	add_child(_bgm_player)

	for key in SFX_PATHS.keys():
		var path: String = String(SFX_PATHS[key])
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

	if ResourceLoader.exists(BGM_PATH):
		var bgm := load(BGM_PATH) as AudioStream
		if bgm != null:
			if bgm is AudioStreamOggVorbis:
				(bgm as AudioStreamOggVorbis).loop = true
			_bgm_player.stream = bgm
			_bgm_player.finished.connect(_on_bgm_finished)
			_bgm_player.play()


func _on_bgm_finished() -> void:
	if not muted and _bgm_player.stream != null:
		_bgm_player.play()


func set_bgm_volume(vol_db: float) -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = vol_db


func set_muted(is_muted: bool) -> void:
	muted = is_muted
	if _bgm_player != null:
		_bgm_player.stream_paused = muted


func play_sfx(key: String, volume_db: float = -4.0, pitch_jitter: float = 0.08) -> void:
	if muted:
		return
	var stream := _streams.get(key) as AudioStream
	if stream == null:
		return

	var player: AudioStreamPlayer = _players[_next_idx]
	_next_idx = (_next_idx + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.play()
