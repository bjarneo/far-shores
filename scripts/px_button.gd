class_name PxButton
extends PanelContainer
## A flat pixel button that holds any content. It fires on release, so drag-to-scroll
## in the drawer does not trigger it, and it works with touch through mouse emulation.

signal pressed

var label: Label
var dot_visible := false
var dot_color := Color.WHITE
var dim := 1.0
var _sb: StyleBoxFlat
var _down := false
var _down_pos := Vector2.ZERO

const SLOP := 12.0


func _init(text := "", font: Font = null, font_size := 12, fg := UI.TEXT, bg := UI.BTN, min_size := Vector2(0, 34), pad := Vector2(10, 6)) -> void:
	_sb = UI.flat(bg, Vector4(pad.x, pad.y, pad.x, pad.y))
	add_theme_stylebox_override("panel", _sb)
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	if text != "":
		label = UI.label(text, font if font != null else UI.silk, font_size, fg)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(label)


func set_text(t: String) -> void:
	if label and label.text != t:
		label.text = t


func set_colors(bg: Color, fg: Color) -> void:
	if _sb.bg_color != bg:
		_sb.bg_color = bg
	if label:
		label.add_theme_color_override("font_color", fg)


func set_pad(x: float, y: float) -> void:
	_sb.content_margin_left = x
	_sb.content_margin_right = x
	_sb.content_margin_top = y
	_sb.content_margin_bottom = y


func set_dim(v: float) -> void:
	if dim != v:
		dim = v
		_apply()


func set_dot(v: bool, c: Color) -> void:
	if v != dot_visible or c != dot_color:
		dot_visible = v
		dot_color = c
		queue_redraw()


func _apply() -> void:
	var k := 0.8 if _down else 1.0
	modulate = Color(k, k, k, dim)


func _draw() -> void:
	if dot_visible:
		# Small buttons, like the drawer tabs on phones, get a smaller dot in the corner.
		draw_rect(Rect2(size.x - 7, 3, 4, 4) if size.y < 36.0 else Rect2(size.x - 11, 5, 6, 6), dot_color)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_down_pos = e.position
			_apply()
		elif _down:
			_down = false
			_apply()
			if Rect2(Vector2.ZERO, size).has_point(e.position) and e.position.distance_to(_down_pos) < SLOP:
				pressed.emit()
	elif e is InputEventMouseMotion and _down and e.position.distance_to(_down_pos) >= SLOP:
		_down = false
		_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _down and mouse_filter == Control.MOUSE_FILTER_STOP:
		_down = false
		_apply()
