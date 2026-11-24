extends Node

const SAVE_PATH := "user://save.cfg"
const SAVE_VERSION := 1

var best_wave: int = 0
var best_score: int = 0
var unlocked_heroes: Array[String] = ["Knight"]


func _ready() -> void:
	load_save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		best_wave = 0
		best_score = 0
		unlocked_heroes = ["Knight"]
		return

	var _ver: int = int(cfg.get_value("meta", "version", SAVE_VERSION))
	best_wave = maxi(0, int(cfg.get_value("progress", "best_wave", 0)))
	best_score = maxi(0, int(cfg.get_value("progress", "best_score", 0)))

	var raw_unlocked: Variant = cfg.get_value("progress", "unlocked_heroes", ["Knight"])
	unlocked_heroes.clear()
	if raw_unlocked is Array:
		for item in raw_unlocked:
			var h := String(item)
			if not unlocked_heroes.has(h):
				unlocked_heroes.append(h)
	if not unlocked_heroes.has("Knight"):
		unlocked_heroes.append("Knight")
	_sync_unlocks_from_wave(best_wave)


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("progress", "best_wave", best_wave)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "unlocked_heroes", unlocked_heroes)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: failed to save to %s (err=%d)" % [SAVE_PATH, err])


func is_hero_unlocked(hero_id: String) -> bool:
	return unlocked_heroes.has(hero_id)


func record_run(wave_reached: int, score: int) -> Array[String]:
	var newly_unlocked: Array[String] = []
	if wave_reached > best_wave:
		best_wave = wave_reached
	if score > best_score:
		best_score = score

	newly_unlocked = _sync_unlocks_from_wave(maxi(best_wave, wave_reached))
	save_data()
	return newly_unlocked


func _sync_unlocks_from_wave(wave_val: int) -> Array[String]:
	var newly: Array[String] = []
	for hero_id in GameConfig.HERO_ORDER:
		var req: int = int(GameConfig.HERO_UNLOCK_WAVES.get(hero_id, 999))
		if wave_val >= req and not unlocked_heroes.has(hero_id):
			unlocked_heroes.append(hero_id)
			newly.append(hero_id)
	return newly
