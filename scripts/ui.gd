class_name UI
extends RefCounted
## Shared fonts, colors and widget helpers for the HUD.

const TEXT := Color("#e9eef6")
const BG := Color("#0b1120")
const BORDER := Color("#2a3b62")
const BTN := Color("#18243f")
const BTN2 := Color("#22305a")
const MUTED := Color("#8fa0bf")
const SUB := Color("#b9c5db")
const HINT := Color("#c9d3e6")
const DIM := Color("#5d6d8c")
const LOGO := Color("#58e5ed")
const GOLD_TEXT := Color("#fbc959")
const INFO := Color("#3a4e7e")
const GOOD := Color("#75d78d")
const WARN := Color("#f1bf4e")
const BAD := Color("#f97770")
const DEAD := Color("#6b7790")
const AQUA := Color("#28d6df")
const GOLD := Color("#f7c243")
const PINK := Color("#ff8fb4")
const ALGAE := Color("#77b868")
const KEEPER := Color("#a8704a")
const TONES := {"good": GOOD, "warn": WARN, "bad": BAD, "muted": MUTED, "dead": DEAD}
const PHASES := {"Dawn": Color("#f6a88d"), "Day": Color("#ead070"), "Dusk": Color("#f09080"), "Night": Color("#95abee")}

static var pix: Font
static var pix_bold: Font
static var silk: Font
static var _boxes := {}


static func init_fonts() -> void:
	if pix != null:
		return
	# The design turns off ligatures. Pixelify Sans would otherwise join "fi" in "Sailfin".
	var ts := TextServerManager.get_primary_interface()
	var no_liga := {ts.name_to_tag("liga"): 0, ts.name_to_tag("calt"): 0}
	var base: FontFile = load("res://fonts/PixelifySans.ttf")
	var regular := FontVariation.new()
	regular.base_font = base
	regular.opentype_features = no_liga
	pix = regular
	var bold := FontVariation.new()
	bold.base_font = base
	bold.opentype_features = no_liga
	bold.variation_opentype = {ts.name_to_tag("wght"): 600}
	pix_bold = bold
	silk = load("res://fonts/Silkscreen-Regular.ttf")


static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = pix
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 1)
	t.set_stylebox("panel", "TooltipPanel", px_box(Color(0.06, 0.09, 0.16, 0.97), BORDER, 2, Vector4(8, 5, 8, 5)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	var grab := StyleBoxFlat.new()
	grab.bg_color = BORDER
	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color("#3a4e7e")
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0)
	track.content_margin_left = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	return t


static func label(text: String, font: Font = null, size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, font: Font = null, size := 16, color := TEXT) -> Label:
	var l := label(text, font, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	return l


static func clip(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func hbox(sep: int) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func vbox(sep: int) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func flat(bg: Color, pad := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


static func panel(bg: Color, pad := Vector4(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A panel with a pixel border drawn outside the box and notched corners,
## like the box-shadow borders in the original design.
static func px_box(bg: Color, border: Color, bw: int, pad: Vector4) -> StyleBoxTexture:
	var key := "%s|%s|%d|%s" % [bg.to_html(), border.to_html(), bw, pad]
	if _boxes.has(key):
		return _boxes[key]
	var n := bw * 2 + 1
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var ix := x >= bw and x < n - bw
			var iy := y >= bw and y < n - bw
			if ix and iy:
				img.set_pixel(x, y, bg)
			elif ix or iy:
				img.set_pixel(x, y, border)
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(side, bw)
		s.set_expand_margin(side, bw)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	_boxes[key] = s
	return s


static func px_panel(bg: Color, border: Color, bw: int, pad: Vector4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", px_box(bg, border, bw, pad))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


## A sprite box: dark background with a pixel sprite scaled to fit, like background-size: contain.
static func sprite_box(box: Vector2, img: Vector2, tex: Texture2D = null) -> Array:
	var p := panel(BG)
	p.custom_minimum_size = box
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = img
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if img.x > 0 else Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = tex
	p.add_child(t)
	return [p, t]


## A thin value bar. value runs from 0 to 1.
class Bar:
	extends Control
	var value := 0.0
	var color := Color.WHITE
	var ring := false

	func _init(h: int, with_ring := false) -> void:
		custom_minimum_size = Vector2(0, h)
		ring = with_ring
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func set_value(v: float, c: Color) -> void:
		var nv := clampf(v, 0.0, 1.0)
		if nv != value or c != color:
			value = nv
			color = c
			queue_redraw()

	func _draw() -> void:
		if ring:
			draw_rect(Rect2(-1, -1, size.x + 2, size.y + 2), BORDER)
		draw_rect(Rect2(Vector2.ZERO, size), BG)
		draw_rect(Rect2(0, 0, size.x * value, size.y), color)


## The gold coin icon from the top bar.
class CoinIcon:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(10, 10)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 10, 10), GOLD)
		draw_rect(Rect2(8, 0, 2, 10), Color("#bb7400"))
		draw_rect(Rect2(0, 8, 10, 2), Color("#bb7400"))
		draw_rect(Rect2(0, 0, 2, 8), Color("#ffedb9"))
		draw_rect(Rect2(0, 0, 8, 2), Color("#ffedb9"))


## A pixel speaker for the sound button. It shows sound waves when on and a cross when off.
class Speaker:
	extends Control
	var on := true

	func _init() -> void:
		custom_minimum_size = Vector2(18, 14)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool) -> void:
		if v != on:
			on = v
			queue_redraw()

	func _draw() -> void:
		var c := TEXT if on else MUTED
		draw_rect(Rect2(0, 4, 4, 6), c)
		draw_rect(Rect2(4, 2, 2, 10), c)
		draw_rect(Rect2(6, 0, 2, 14), c)
		if on:
			draw_rect(Rect2(10, 4, 2, 6), c)
			draw_rect(Rect2(13, 1, 2, 2), c)
			draw_rect(Rect2(15, 3, 2, 8), c)
			draw_rect(Rect2(13, 11, 2, 2), c)
		else:
			for p in [Vector2(10, 3), Vector2(12, 5), Vector2(14, 7), Vector2(16, 9), Vector2(16, 3), Vector2(14, 5), Vector2(12, 7), Vector2(10, 9)]:
				draw_rect(Rect2(p, Vector2(2, 2)), BAD)


## The achievement checkbox: a filled square with a 2 px ring.
class AchBox:
	extends Control
	var done := false

	func _init(is_done: bool) -> void:
		done = is_done
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ring := Color("#fdeab6") if done else INFO
		draw_rect(Rect2(0, 0, 18, 18), ring)
		draw_rect(Rect2(2, 2, 14, 14), GOLD if done else Color("#18243f"))


## A grid that picks its column count from its width, like repeat(auto-fill, minmax(N, 1fr)).
class AutoGrid:
	extends GridContainer
	var min_w := 130.0
	var gap := 10

	func _init(min_width: float, spacing: int) -> void:
		min_w = min_width
		gap = spacing
		add_theme_constant_override("h_separation", spacing)
		add_theme_constant_override("v_separation", spacing)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(_fit)

	func _fit() -> void:
		var c := maxi(1, floori((size.x + gap) / (min_w + gap)))
		if c != columns:
			columns = c
