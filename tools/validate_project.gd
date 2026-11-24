extends SceneTree

const SCRIPTS_TO_CHECK: Array[String] = [
	"res://scripts/game_config.gd",
	"res://scripts/save_manager.gd",
	"res://scripts/audio_manager.gd",
	"res://scripts/combat.gd",
	"res://scripts/joystick.gd",
	"res://scripts/projectile.gd",
	"res://scripts/loot.gd",
	"res://scripts/enemy.gd",
	"res://scripts/player.gd",
	"res://scripts/wave_manager.gd",
	"res://scripts/arena.gd",
	"res://scripts/hud.gd",
	"res://scripts/hero_select.gd",
	"res://scripts/upgrade.gd",
	"res://scripts/main.gd",
]


func _initialize() -> void:
	print("=== Bonefall Grove: Project & Script Validation ===")
	var ok := true
	for sp: String in SCRIPTS_TO_CHECK:
		var scr := ResourceLoader.load(sp) as GDScript
		if scr == null or not scr.can_instantiate():
			push_error("Script failed to load/compile: " + sp)
			ok = false
		else:
			print("[OK] ", sp)

	var main_scene := ResourceLoader.load("res://scenes/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load res://scenes/Main.tscn")
		ok = false
	else:
		print("[OK] res://scenes/Main.tscn")

	print("=== Validation Complete (ok=%s) ===" % str(ok))
	quit(0 if ok else 1)
