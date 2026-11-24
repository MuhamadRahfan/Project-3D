class_name UpgradePanelUI
extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

var _title_label: Label = null
var _cards_box: HBoxContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.06, 0.78)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 60
	vbox.offset_right = -60
	vbox.offset_top = 60
	vbox.offset_bottom = -60
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.45))
	vbox.add_child(_title_label)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 24)
	vbox.add_child(_cards_box)


func show_choices(cleared_wave: int) -> void:
	_title_label.text = "WAVE %d CLEARED! CHOOSE 1 UPGRADE" % cleared_wave
	for ch in _cards_box.get_children():
		ch.queue_free()

	var pool := GameConfig.UPGRADES.duplicate()
	pool.shuffle()
	var picks := pool.slice(0, mini(3, pool.size()))

	for item_v in picks:
		var item: Dictionary = item_v
		var uid: String = String(item["id"])
		var col: Color = item["color"]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 230)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.14, 0.14, 0.96)
		sb.border_color = col
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color(0.16, 0.21, 0.20, 0.98)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)

		var cv := VBoxContainer.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_theme_constant_override("separation", 14)
		btn.add_child(cv)

		var t_lbl := Label.new()
		t_lbl.text = String(item["title"])
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 26)
		t_lbl.add_theme_color_override("font_color", col)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.text = String(item["desc"])
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 20)
		d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(d_lbl)

		btn.pressed.connect(func():
			AudioManager.play_sfx("upgrade", -3.0, 0.05)
			visible = false
			get_tree().paused = false
			upgrade_selected.emit(uid)
		)
		_cards_box.add_child(btn)

	visible = true
	get_tree().paused = true
