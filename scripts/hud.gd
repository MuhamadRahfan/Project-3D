class_name GameHUD
extends CanvasLayer

signal dodge_pressed
signal skill_pressed
signal pause_menu_requested

var joystick: TouchJoystick = null

var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _weapon_label: Label = null
var _wave_label: Label = null
var _remain_label: Label = null
var _score_label: Label = null
var _boss_box: VBoxContainer = null
var _boss_bar: ProgressBar = null
var _banner_label: Label = null
var _banner_timer: float = 0.0

var _dodge_btn: Button = null
var _skill_btn: Button = null
var _mute_btn: Button = null
var _skill_title: String = "SKILL"
var _player_ref: Player = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left stats panel
	var tl_panel := PanelContainer.new()
	tl_panel.position = Vector2(20, 16)
	tl_panel.custom_minimum_size = Vector2(300, 92)
	tl_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.10, 0.78), Color(0.28, 0.42, 0.35, 0.8)))
	root.add_child(tl_panel)

	var tl_box := VBoxContainer.new()
	tl_box.add_theme_constant_override("separation", 6)
	tl_panel.add_child(tl_box)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.text = "HP: 150 / 150"
	tl_box.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(270, 20)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.26, 0.80, 0.38)
	fill.set_corner_radius_all(5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.16, 0.18, 0.9)
	bg.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
	tl_box.add_child(_hp_bar)

	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 16)
	_weapon_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.72))
	_weapon_label.text = "Weapon: Iron Sword"
	tl_box.add_child(_weapon_label)

	# Top-center wave + score + boss bar
	var tc_box := VBoxContainer.new()
	tc_box.anchor_left = 0.5
	tc_box.anchor_right = 0.5
	tc_box.offset_left = -190
	tc_box.offset_right = 190
	tc_box.offset_top = 14
	tc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tc_box)

	var wave_panel := PanelContainer.new()
	wave_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.11, 0.10, 0.78), Color(0.35, 0.45, 0.38, 0.75)))
	tc_box.add_child(wave_panel)

	var wp_hbox := HBoxContainer.new()
	wp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wp_hbox.add_theme_constant_override("separation", 22)
	wave_panel.add_child(wp_hbox)

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 22)
	_wave_label.text = "WAVE 1"
	wp_hbox.add_child(_wave_label)

	_remain_label = Label.new()
	_remain_label.add_theme_font_size_override("font_size", 18)
	_remain_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
	_remain_label.text = "Left: 0"
	wp_hbox.add_child(_remain_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.42))
	_score_label.text = "Score: 0"
	wp_hbox.add_child(_score_label)

	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	tc_box.add_child(_boss_box)

	var boss_lbl := Label.new()
	boss_lbl.text = "NECROMANCER LORD"
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.add_theme_font_size_override("font_size", 16)
	boss_lbl.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	_boss_box.add_child(boss_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(360, 18)
	_boss_bar.show_percentage = false
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = Color(0.88, 0.22, 0.28)
	bfill.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("fill", bfill)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_box.add_child(_boss_bar)

	# Top-right mute button
	_mute_btn = Button.new()
	_mute_btn.anchor_left = 1.0
	_mute_btn.anchor_right = 1.0
	_mute_btn.offset_left = -132
	_mute_btn.offset_right = -20
	_mute_btn.offset_top = 18
	_mute_btn.offset_bottom = 66
	_mute_btn.text = "AUDIO: ON"
	_mute_btn.add_theme_font_size_override("font_size", 17)
	_mute_btn.pressed.connect(_on_mute_pressed)
	root.add_child(_mute_btn)

	# Center transient banner
	_banner_label = Label.new()
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.anchor_top = 0.24
	_banner_label.offset_left = -280
	_banner_label.offset_right = 280
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 34)
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	_banner_label.visible = false
	root.add_child(_banner_label)

	# Bottom-left virtual joystick
	joystick = TouchJoystick.new()
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 20
	joystick.offset_top = -280
	joystick.offset_right = 280
	joystick.offset_bottom = -20
	root.add_child(joystick)

	# Bottom-right action buttons
	var br_box := HBoxContainer.new()
	br_box.anchor_left = 1.0
	br_box.anchor_right = 1.0
	br_box.anchor_top = 1.0
	br_box.anchor_bottom = 1.0
	br_box.offset_left = -310
	br_box.offset_right = -24
	br_box.offset_top = -168
	br_box.offset_bottom = -24
	br_box.add_theme_constant_override("separation", 20)
	br_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(br_box)

	_dodge_btn = Button.new()
	_dodge_btn.custom_minimum_size = Vector2(118, 118)
	_dodge_btn.text = "DODGE"
	_dodge_btn.add_theme_font_size_override("font_size", 22)
	_dodge_btn.add_theme_stylebox_override("normal", _make_circle_btn_style(Color(0.22, 0.34, 0.44, 0.85)))
	_dodge_btn.add_theme_stylebox_override("pressed", _make_circle_btn_style(Color(0.32, 0.50, 0.65, 0.95)))
	_dodge_btn.pressed.connect(func(): dodge_pressed.emit())
	br_box.add_child(_dodge_btn)

	_skill_btn = Button.new()
	_skill_btn.custom_minimum_size = Vector2(132, 132)
	_skill_btn.text = "SKILL"
	_skill_btn.add_theme_font_size_override("font_size", 20)
	_skill_btn.add_theme_stylebox_override("normal", _make_circle_btn_style(Color(0.48, 0.26, 0.52, 0.88)))
	_skill_btn.add_theme_stylebox_override("pressed", _make_circle_btn_style(Color(0.68, 0.36, 0.72, 0.96)))
	_skill_btn.pressed.connect(func(): skill_pressed.emit())
	br_box.add_child(_skill_btn)


func bind_player(p: Player, hero_id: String) -> void:
	_player_ref = p
	var cfg: Dictionary = GameConfig.HEROES.get(hero_id, {})
	_skill_title = String(cfg.get("skill_name", "SKILL"))
	_skill_btn.text = _skill_title


func set_hp(cur: float, max_v: float) -> void:
	_hp_bar.max_value = maxf(1.0, max_v)
	_hp_bar.value = cur
	_hp_label.text = "HP: %d / %d" % [ceili(cur), ceili(max_v)]


func set_weapon(w_name: String) -> void:
	_weapon_label.text = "Weapon: " + w_name


func set_wave(wave_num: int, is_boss: bool) -> void:
	_wave_label.text = "WAVE %d" % wave_num
	show_banner("WAVE %d - BOSS!" % wave_num if is_boss else "WAVE %d" % wave_num)


func set_remaining(rem: int) -> void:
	_remain_label.text = "Left: %d" % rem


func set_score(s: int) -> void:
	_score_label.text = "Score: %d" % s


func set_boss_hp(cur: float, max_v: float, active: bool) -> void:
	_boss_box.visible = active
	if active:
		_boss_bar.max_value = maxf(1.0, max_v)
		_boss_bar.value = cur


func show_banner(msg: String) -> void:
	_banner_label.text = msg
	_banner_label.visible = true
	_banner_timer = 2.2


func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner_label.visible = false

	if _player_ref != null:
		var d_ratio := _player_ref.get_dodge_cooldown_ratio()
		_dodge_btn.disabled = d_ratio > 0.0
		_dodge_btn.text = "DODGE" if d_ratio <= 0.0 else "%.1fs" % (_player_ref.dodge_cd * d_ratio)

		var s_ratio := _player_ref.get_skill_cooldown_ratio()
		_skill_btn.disabled = s_ratio > 0.0
		_skill_btn.text = _skill_title if s_ratio <= 0.0 else "%.1fs" % (_player_ref.skill_cd * s_ratio)


func _on_mute_pressed() -> void:
	AudioManager.set_muted(not AudioManager.muted)
	_mute_btn.text = "AUDIO: OFF" if AudioManager.muted else "AUDIO: ON"


func _make_panel_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _make_circle_btn_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(0.9, 0.95, 0.92, 0.6)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(64)
	return sb
