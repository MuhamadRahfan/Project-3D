class_name HeroSelectUI
extends CanvasLayer

signal hero_chosen(hero_id: String)

var _record_label: Label = null
var _cards_box: HBoxContainer = null


func _ready() -> void:
	_build_ui()
	refresh()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.09, 0.08, 0.92)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 48
	vbox.offset_right = -48
	vbox.offset_top = 34
	vbox.offset_bottom = -34
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title := Label.new()
	title.text = GameConfig.GAME_TITLE.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.86, 0.95, 0.80))
	vbox.add_child(title)

	_record_label = Label.new()
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override("font_size", 20)
	_record_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.45))
	vbox.add_child(_record_label)

	var hint := Label.new()
	hint.text = "Select your hero  •  Auto-aim & Auto-attack  •  Dodge & Skill on the right"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.70, 0.78, 0.74))
	vbox.add_child(hint)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 24)
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_cards_box)


func refresh() -> void:
	_record_label.text = "Best Wave: %d   |   Best Score: %d" % [SaveManager.best_wave, SaveManager.best_score]
	for ch in _cards_box.get_children():
		ch.queue_free()

	for hero_id in GameConfig.HERO_ORDER:
		var cfg: Dictionary = GameConfig.HEROES[hero_id]
		var unlocked := SaveManager.is_hero_unlocked(hero_id)
		var req_wave := int(cfg["unlock_wave"])
		var accent: Color = cfg["accent_color"]

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(310, 350)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.15, 0.14, 0.95) if unlocked else Color(0.09, 0.10, 0.11, 0.85)
		sb.border_color = accent if unlocked else Color(0.32, 0.34, 0.36)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 18
		sb.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", sb)
		_cards_box.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)

		var name_lbl := Label.new()
		name_lbl.text = String(cfg["display_name"])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 30)
		name_lbl.add_theme_color_override("font_color", accent if unlocked else Color(0.55, 0.58, 0.60))
		cv.add_child(name_lbl)

		var role_lbl := Label.new()
		role_lbl.text = String(cfg["role"])
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.add_theme_font_size_override("font_size", 18)
		cv.add_child(role_lbl)

		var stats_lbl := Label.new()
		stats_lbl.text = "HP: %d   DMG: %d   SPD: %.1f\nSkill: %s\n%s" % [
			int(cfg["max_hp"]),
			int(cfg["damage"]),
			float(cfg["move_speed"]),
			String(cfg["skill_name"]),
			String(cfg["skill_desc"]),
		]
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stats_lbl.add_theme_font_size_override("font_size", 16)
		stats_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.86))
		cv.add_child(stats_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 22)
		if unlocked:
			btn.text = "PLAY"
			btn.pressed.connect(func():
				AudioManager.play_sfx("click", -4.0, 0.04)
				hero_chosen.emit(hero_id)
			)
		else:
			btn.text = "UNLOCK: WAVE %d" % req_wave
			btn.disabled = true
		cv.add_child(btn)
