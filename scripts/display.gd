class_name SceneDisplay
extends Control
## Shows the low-resolution scene, scaled up with nearest filtering, and turns
## mouse, touch and key input into the fishing action.

var g: Game
var vp: SubViewport
var blocked := false
var _down := false
var _touch_id := -1


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_exited.connect(func(): if g: g.hover_at(Vector2(-99, -99), false))


func _process(_dt: float) -> void:
	queue_redraw()
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if g and g.phase == "idle" else CURSOR_ARROW


func _draw() -> void:
	if g == null or vp == null or g.S.is_empty():
		return
	var s := g.px_scale
	draw_texture_rect(vp.get_texture(), Rect2(Vector2.ZERO, Vector2(g.W, g.H) * s), false)


func screen_to_world(p: Vector2) -> Vector2:
	return p / g.px_scale


func world_to_screen(p: Vector2) -> Vector2:
	return p * g.px_scale


func _gui_input(e: InputEvent) -> void:
	if g == null or g.S.is_empty():
		return
	if e is InputEventScreenTouch:
		if e.pressed and _touch_id < 0:
			_touch_id = e.index
			g.hover_at(screen_to_world(e.position), true)
			_press()
		elif not e.pressed and e.index == _touch_id:
			_touch_id = -1
			_release()
		accept_event()
		return
	if e is InputEventMouse and e.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press()
		else:
			_release()
		accept_event()
	elif e is InputEventMouseMotion:
		g.hover_at(screen_to_world(e.position), false)


func _press() -> void:
	if blocked or g.phase == "show" or g.phase == "land":
		return
	_down = true
	g.action_down()


func _release() -> void:
	if not _down:
		return
	_down = false
	g.action_up()


func cancel() -> void:
	if _down:
		_down = false
		g.action_up()
