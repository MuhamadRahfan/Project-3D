extends Node

var _arena: Arena = null
var _hud: GameHUD = null
var _hero_select: HeroSelectUI = null
var _upgrade_panel: UpgradePanelUI = null
var _game_over_layer: CanvasLayer = null
var _go_stats_label: Label = null
var _go_unlock_label: Label = null

var _current_hero_id: String = "Knight"
var _in_run: bool = false


func _ready() -> void:
	_arena = Arena.new()
	_arena.name = "Arena"
	add_child(_arena)

	_hud = GameHUD.new()
	_hud.name = "HUD"
	_hud.layer = 1
	_hud.visible = false
	add_child(_hud)

	_upgrade_panel = UpgradePanelUI.new()
	_upgrade_panel.name = "UpgradePanel"
	_upgrade_panel.layer = 5
	add_child(_upgrade_panel)

	_hero_select = HeroSelectUI.new()
	_hero_select.name = "HeroSelect"
	_hero_select.layer = 15
	add_child(_hero_select)

	_build_game_over_ui()
	_game_over_layer.layer = 10
	_connect_signals()


func _connect_signals() -> void:
	_hero_select.hero_chosen.connect(_start_game_with_hero)
	_hud.dodge_pressed.connect(func(): _arena.player.trigger_dodge())
	_hud.skill_pressed.connect(func(): _arena.player.trigger_skill())

	_arena.player.hp_changed.connect(_hud.set_hp)
	_arena.player.weapon_changed.connect(_hud.set_weapon)
	_arena.score_changed.connect(_hud.set_score)
	_arena.boss_hp_changed.connect(_hud.set_boss_hp)
	_arena.player_died.connect(_on_player_died)

	_arena.wave_manager.wave_started.connect(func(w: int, _t: int, is_b: bool): _hud.set_wave(w, is_b))
	_arena.wave_manager.wave_progress.connect(_hud.set_remaining)
	_arena.wave_manager.wave_cleared.connect(_on_wave_cleared)
	_upgrade_panel.upgrade_selected.connect(_on_upgrade_selected)


func _process(_delta: float) -> void:
	if _in_run and not get_tree().paused and _arena.player != null:
		_arena.player.move_input = _hud.joystick.output


func _start_game_with_hero(hero_id: String) -> void:
	_current_hero_id = hero_id
	_in_run = true
	get_tree().paused = false
	_hero_select.visible = false
	_game_over_layer.visible = false
	_upgrade_panel.visible = false
	_hud.visible = true
	AudioManager.set_bgm_volume(-11.0)

	_arena.start_run(hero_id)
	_hud.bind_player(_arena.player, hero_id)


func _on_wave_cleared(cleared_wave: int) -> void:
	if not _in_run or not _arena.player.is_alive():
		return
	_hud.visible = false
	AudioManager.set_bgm_volume(-16.0)
	_upgrade_panel.show_choices(cleared_wave)


func _on_upgrade_selected(upgrade_id: String) -> void:
	_hud.visible = true
	AudioManager.set_bgm_volume(-11.0)
	_arena.player.apply_upgrade(upgrade_id)
	var next_wave := _arena.wave_manager.current_wave + 1
	_arena.wave_manager.start_wave(next_wave)


func _on_player_died(wave_reached: int, final_score: int) -> void:
	_in_run = false
	_hud.visible = false
	AudioManager.set_bgm_volume(-16.0)
	var newly_unlocked := SaveManager.record_run(wave_reached, final_score)

	_go_stats_label.text = "Wave Reached: %d   |   Score: %d\nBest Wave: %d   |   Best Score: %d" % [
		wave_reached,
		final_score,
		SaveManager.best_wave,
		SaveManager.best_score,
	]
	if newly_unlocked.is_empty():
		_go_unlock_label.visible = false
	else:
		_go_unlock_label.text = "NEW HERO UNLOCKED: %s!" % ", ".join(newly_unlocked)
		_go_unlock_label.visible = true
	_game_over_layer.visible = true


func _build_game_over_ui() -> void:
	_game_over_layer = CanvasLayer.new()
	_game_over_layer.visible = false
	add_child(_game_over_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.05, 0.84)
	_game_over_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	_game_over_layer.add_child(vbox)

	var title := Label.new()
	title.text = "DEFEATED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.32))
	vbox.add_child(title)

	_go_stats_label = Label.new()
	_go_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_stats_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_go_stats_label)

	_go_unlock_label = Label.new()
	_go_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_unlock_label.add_theme_font_size_override("font_size", 28)
	_go_unlock_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.35))
	_go_unlock_label.visible = false
	vbox.add_child(_go_unlock_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	var retry_btn := Button.new()
	retry_btn.custom_minimum_size = Vector2(220, 64)
	retry_btn.text = "PLAY AGAIN"
	retry_btn.add_theme_font_size_override("font_size", 22)
	retry_btn.pressed.connect(func():
		AudioManager.play_sfx("click", -4.0, 0.04)
		_start_game_with_hero(_current_hero_id)
	)
	hbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.custom_minimum_size = Vector2(220, 64)
	menu_btn.text = "HERO SELECT"
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.pressed.connect(func():
		AudioManager.play_sfx("click", -4.0, 0.04)
		_game_over_layer.visible = false
		_arena.reset_run()
		_hero_select.refresh()
		_hero_select.visible = true
	)
	hbox.add_child(menu_btn)
