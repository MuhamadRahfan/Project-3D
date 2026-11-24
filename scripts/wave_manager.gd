class_name WaveManager
extends Node

signal wave_started(wave_num: int, total_to_kill: int, is_boss_wave: bool)
signal wave_progress(remaining: int)
signal wave_cleared(wave_num: int)

var current_wave: int = 0
var running: bool = false

var _arena_ref: Node = null
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.85
var _remaining_kills: int = 0
var _hp_mult: float = 1.0
var _spd_mult: float = 1.0


func setup(arena: Node) -> void:
	_arena_ref = arena


func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	running = true
	_spawn_queue.clear()

	_hp_mult = 1.0 + float(wave_num - 1) * 0.16
	_spd_mult = minf(1.55, 1.0 + float(wave_num - 1) * 0.03)
	_spawn_interval = maxf(0.32, 0.95 - float(wave_num - 1) * 0.04)

	var is_boss_wave := (wave_num % 5 == 0)
	var base_count := 6 + wave_num * 3

	if is_boss_wave:
		_spawn_queue.append({"type": "boss", "elite": false})
		base_count = maxi(5, int(base_count * 0.6))

	for i in base_count:
		var e_type := _pick_enemy_type(wave_num)
		var elite := (wave_num >= 3 and randf() < minf(0.24, 0.08 + float(wave_num) * 0.012))
		_spawn_queue.append({"type": e_type, "elite": elite})

	_remaining_kills = _spawn_queue.size()
	_spawn_timer = 0.35
	wave_started.emit(current_wave, _remaining_kills, is_boss_wave)
	wave_progress.emit(_remaining_kills)


func stop() -> void:
	running = false
	_spawn_queue.clear()


func _pick_enemy_type(wave_num: int) -> String:
	var roll := randf()
	if wave_num == 1:
		return "minion"
	if wave_num == 2:
		return "warrior" if roll < 0.25 else "minion"
	if wave_num == 3:
		if roll < 0.25:
			return "warrior"
		if roll < 0.45:
			return "rogue"
		return "minion"
	# Wave 4+: all 4 regular archetypes
	if roll < 0.40:
		return "minion"
	if roll < 0.62:
		return "warrior"
	if roll < 0.82:
		return "rogue"
	return "mage"


func _process(delta: float) -> void:
	if not running or _arena_ref == null:
		return
	if _spawn_queue.is_empty():
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		if _arena_ref.get_active_enemy_count() < GameConfig.MAX_ACTIVE_ENEMIES:
			var entry: Dictionary = _spawn_queue.pop_front()
			_arena_ref.spawn_enemy_at_edge(
				String(entry["type"]),
				_hp_mult,
				_spd_mult,
				bool(entry["elite"])
			)
			_spawn_timer = _spawn_interval
		else:
			_spawn_timer = 0.25


func on_enemy_killed(was_boss: bool, pos: Vector3) -> void:
	if not running:
		return
	_remaining_kills = maxi(0, _remaining_kills - 1)
	wave_progress.emit(_remaining_kills)

	if was_boss:
		_arena_ref.spawn_loot_drop(pos, LootDrop.LootType.WEAPON)
		_arena_ref.spawn_loot_drop(pos + Vector3(1.2, 0.0, 0.4), LootDrop.LootType.HEAL_ORB)
	else:
		var r := randf()
		if r < 0.09:
			_arena_ref.spawn_loot_drop(pos, LootDrop.LootType.WEAPON)
		elif r < 0.23:
			_arena_ref.spawn_loot_drop(pos, LootDrop.LootType.HEAL_ORB)

	if _remaining_kills <= 0 and _spawn_queue.is_empty():
		running = false
		wave_cleared.emit(current_wave)


func on_summoned_minion_added() -> void:
	if running:
		_remaining_kills += 1
		wave_progress.emit(_remaining_kills)
