class_name VirtualJoystick
extends Control

@export var max_radius: float = 72.0
@export var deadzone: float = 0.14

var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _default_center: Vector2 = Vector2(130.0, -130.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_reset_visual()


func _reset_visual() -> void:
	_default_center = Vector2(size.x * 0.5, size.y * 0.5)
	if not _is_active:
		_base_center = _default_center
		_knob_offset = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _is_active:
			_release()
		return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_index == -1 and _is_in_zone(st.position):
				_touch_index = st.index
				_activate_at(st.position)
		else:
			if st.index == _touch_index:
				_release()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_drag_to(sd.position)


func _process(_delta: float) -> void:
	if _is_active:
		return
	var kb := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if kb.length() > 0.1:
		output = kb.normalized()
	else:
		output = Vector2.ZERO


func _is_in_zone(global_pt: Vector2) -> bool:
	var vp := get_viewport_rect().size
	return global_pt.x <= vp.x * 0.52 and global_pt.y >= vp.y * 0.22


func _activate_at(global_pt: Vector2) -> void:
	_is_active = true
	var local_pt := global_pt - global_position
	_base_center = local_pt
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _drag_to(global_pt: Vector2) -> void:
	var local_pt := global_pt - global_position
	var delta := local_pt - _base_center
	var dist := delta.length()
	if dist > max_radius:
		delta = delta.normalized() * max_radius
		dist = max_radius
	_knob_offset = delta
	var norm_len := dist / max_radius
	if norm_len < deadzone:
		output = Vector2.ZERO
	else:
		var scaled := (norm_len - deadzone) / (1.0 - deadzone)
		output = delta.normalized() * clampf(scaled, 0.0, 1.0)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_is_active = false
	_base_center = _default_center
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var base_alpha := 0.42 if _is_active else 0.24
	var knob_alpha := 0.85 if _is_active else 0.45
	draw_circle(_base_center, max_radius, Color(0.12, 0.16, 0.15, base_alpha))
	draw_arc(_base_center, max_radius, 0.0, TAU, 36, Color(0.75, 0.90, 0.80, base_alpha + 0.2), 3.0)
	draw_circle(_base_center + _knob_offset, max_radius * 0.40, Color(0.88, 0.95, 0.90, knob_alpha))
