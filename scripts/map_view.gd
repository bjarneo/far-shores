class_name MapView
extends Control
## The world map. Pick a place, unlock it, and fly there.

var g: Game
var hud: Hud
var sel := ""
var _fly := {}
var _clock := 0.0
var _sig := ""

var canvas: MapCanvas
var body: BoxContainer
var side: VBoxContainer
var info_flag: TextureRect
var info_name: Label
var info_country: Label
var info_blurb: Label
var info_meta: Label
var go_btn: PxButton
var list: VBoxContainer
var coins_l: Label
var _narrow := false
var _short := false
var _margin: MarginContainer
var _col: VBoxContainer
var _head: PanelContainer
var _scroll: ScrollContainer
var _sub: Label
var _close: PxButton

static var _tex: ImageTexture

const MAP_BG := Color(9 / 255.0, 14 / 255.0, 27 / 255.0, 0.98)


func build(game: Game, h: Hud) -> void:
	g = game
	hud = h
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = MAP_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	var m := MarginContainer.new()
	_margin = m
	m.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	for s in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	add_child(m)
	var col := UI.vbox(10)
	_col = col
	m.add_child(col)
	var head := UI.px_panel(Hud.BAR_BG, UI.BORDER, 3, Vector4(12, 7, 10, 7))
	_head = head
	col.add_child(head)
	var hh := UI.hbox(12)
	head.add_child(hh)
	var t := UI.label("WORLD MAP", UI.silk, 15, UI.GOLD_TEXT)
	t.size_flags_vertical = SIZE_SHRINK_CENTER
	hh.add_child(t)
	var sub := UI.label("Pick a place to fish", UI.pix, 14, UI.MUTED)
	sub.size_flags_vertical = SIZE_SHRINK_CENTER
	_sub = sub
	hh.add_child(sub)
	hh.add_child(UI.spacer())
	var coin := UI.hbox(7)
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	coin.add_child(UI.CoinIcon.new())
	coins_l = UI.label("0", UI.silk, 15, UI.GOLD_TEXT)
	coin.add_child(coins_l)
	hh.add_child(coin)
	var close := PxButton.new("CLOSE", UI.silk, 11, UI.TEXT, UI.BTN, Vector2(0, 32))
	_close = close
	close.pressed.connect(close_map)
	hh.add_child(close)
	body = BoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	body.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(body)
	canvas = MapCanvas.new()
	canvas.view = self
	canvas.size_flags_horizontal = SIZE_EXPAND_FILL
	canvas.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(canvas)
	side = UI.vbox(10)
	side.custom_minimum_size.x = 330
	body.add_child(side)
	var info := UI.px_panel(Hud.PANEL_BG, UI.BORDER, 3, Vector4(14, 12, 14, 12))
	side.add_child(info)
	var iv := UI.vbox(7)
	info.add_child(iv)
	var ih := UI.hbox(10)
	info_flag = TextureRect.new()
	info_flag.custom_minimum_size = Vector2(Sprites.FLAG_W * 3, Sprites.FLAG_H * 3)
	info_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_flag.texture_filter = TEXTURE_FILTER_NEAREST
	info_flag.size_flags_vertical = SIZE_SHRINK_CENTER
	ih.add_child(info_flag)
	var nv := UI.vbox(2)
	info_name = UI.label("", UI.pix_bold, 20)
	info_country = UI.label("", UI.silk, 10, UI.GOLD_TEXT)
	nv.add_child(info_name)
	nv.add_child(info_country)
	ih.add_child(nv)
	iv.add_child(ih)
	info_blurb = UI.wrap_label("", UI.pix, 14, UI.SUB)
	iv.add_child(info_blurb)
	info_meta = UI.wrap_label("", UI.silk, 10, UI.MUTED)
	iv.add_child(info_meta)
	go_btn = PxButton.new("TRAVEL", UI.silk, 13, UI.BG, UI.AQUA, Vector2(0, 42), Vector2(12, 8))
	go_btn.pressed.connect(_on_go)
	iv.add_child(go_btn)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	side.add_child(_scroll)
	list = UI.vbox(6)
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.mouse_filter = MOUSE_FILTER_PASS
	_scroll.add_child(list)


func open() -> void:
	sel = g.loc
	_fly = {}
	_sig = ""
	visible = true
	g.synth.click()
	_refresh()


func close_map() -> void:
	if not _fly.is_empty():
		return
	close()


func close() -> void:
	visible = false
	_fly = {}
	hud._refresh()


func select(k: String) -> void:
	if not _fly.is_empty():
		return
	sel = k
	g.synth.click()
	_refresh()


func _on_go() -> void:
	if not _fly.is_empty() or sel == g.loc:
		return
	if not g.S.unlocked.has(sel):
		if g.unlock(sel):
			g.toast.emit("%s unlocked. Have a good trip." % Places.ALL[sel].name, "good")
		_sig = ""
		_refresh()
		return
	_fly = {"from": g.loc, "to": sel, "t": 0.0}
	g.synth.buy()


func _process(dt: float) -> void:
	if not visible:
		return
	_clock += dt
	# A tall, thin screen stacks the map over the list. A short screen, such as a phone held
	# sideways, keeps them side by side.
	var n := size.x < 860.0 and size.y >= 520.0
	var sh := size.y < 520.0
	if n != _narrow or sh != _short:
		_narrow = n
		_short = sh
		body.vertical = n
		_sub.visible = size.x >= 520.0
		side.size_flags_vertical = SIZE_EXPAND_FILL if n else SIZE_FILL
		canvas.size_flags_vertical = SIZE_FILL if n else SIZE_EXPAND_FILL
		info_blurb.visible = not sh
		var mg := 6 if sh else 12
		for k in ["left", "top", "right", "bottom"]:
			_margin.add_theme_constant_override("margin_" + k, mg)
		_col.add_theme_constant_override("separation", 6 if sh else 10)
		_head.add_theme_stylebox_override("panel", UI.px_box(Hud.BAR_BG, UI.BORDER, 3, Vector4(10, 4, 8, 4) if sh else Vector4(12, 7, 10, 7)))
		_close.custom_minimum_size.y = 28 if sh else 32
		go_btn.custom_minimum_size.y = 36 if sh else 42
		_sig = ""
	if _narrow:
		side.custom_minimum_size.x = 0
		canvas.custom_minimum_size.y = clampf((size.x - 24.0) * 164.0 / 360.0, 120.0, size.y * 0.4)
	else:
		side.custom_minimum_size.x = clampf(size.x * 0.42, 240.0, 330.0)
		canvas.custom_minimum_size.y = 0
	if not _fly.is_empty():
		_fly.t += dt / 1.8
		if _fly.t >= 1.0 and not _fly.get("done", false):
			_fly.done = true
			var k: String = _fly.to
			hud.main.call("fade_through", func():
				g.travel(k)
				close())
	coins_l.text = D.fmt_int(g.S.coins)
	canvas.queue_redraw()
	var sig := "%s|%d|%s|%s" % [sel, g.S.coins, str(g.S.unlocked.keys()), _narrow]
	if sig != _sig:
		_refresh()


func _refresh() -> void:
	_sig = "%s|%d|%s|%s" % [sel, g.S.coins, str(g.S.unlocked.keys()), _narrow]
	if sel == "":
		sel = g.loc
	var P: Dictionary = Places.ALL[sel]
	info_flag.texture = Sprites.flag_tex(P.flag)
	info_name.text = P.name
	info_country.text = P.country.to_upper()
	info_blurb.text = P.blurb
	var pool := Species.of_place(sel)
	var found := 0
	for k in pool:
		if g.S.book.has(k):
			found += 1
	var lh := D.local_hours(g.S.utc, P.tz)
	info_meta.text = "LOCAL TIME %02d:%02d %s   ·   FISH FOUND %d/%d" % [floori(lh), floori(fmod(lh, 1.0) * 60.0), D.phase_of(lh).to_upper(), found, pool.size()]
	if sel == g.loc:
		go_btn.set_text("YOU ARE HERE")
		go_btn.set_colors(UI.BTN2, UI.MUTED)
	elif g.S.unlocked.has(sel):
		go_btn.set_text("TRAVEL")
		go_btn.set_colors(UI.AQUA, UI.BG)
	else:
		var can: bool = g.S.coins >= P.price
		go_btn.set_text("UNLOCK  %s" % D.fmt_int(P.price))
		go_btn.set_colors(UI.GOLD if can else UI.BTN2, UI.BG if can else UI.MUTED)
	for c in list.get_children():
		c.queue_free()
	for k in Places.ORDER:
		var Q: Dictionary = Places.ALL[k]
		var on := k == sel
		var b := PxButton.new("", null, 12, UI.TEXT, UI.BTN2 if on else UI.BTN, Vector2(0, 38), Vector2(8, 4))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		# The row passes drags on to the list, so a finger can scroll it.
		b.mouse_filter = MOUSE_FILTER_PASS
		var h := UI.hbox(8)
		var fl := TextureRect.new()
		fl.texture = Sprites.flag_tex(Q.flag)
		fl.custom_minimum_size = Vector2(22, 14)
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.texture_filter = TEXTURE_FILTER_NEAREST
		fl.size_flags_vertical = SIZE_SHRINK_CENTER
		fl.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(fl)
		var nl := UI.clip(UI.label(Q.name, UI.pix_bold if on else UI.pix, 15, UI.TEXT if g.S.unlocked.has(k) else UI.MUTED))
		nl.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(nl)
		var stl: Label
		if k == g.loc:
			stl = UI.label("HERE", UI.silk, 10, UI.GOLD_TEXT)
		elif g.S.unlocked.has(k):
			var pool2 := Species.of_place(k)
			var f2 := 0
			for sp in pool2:
				if g.S.book.has(sp):
					f2 += 1
			stl = UI.label("%d/%d" % [f2, pool2.size()], UI.silk, 10, UI.GOOD if f2 == pool2.size() else UI.MUTED)
		else:
			stl = UI.label(D.fmt_int(Q.price), UI.silk, 10, UI.GOLD_TEXT if g.S.coins >= Q.price else UI.DIM)
		stl.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(stl)
		b.add_child(h)
		b.pressed.connect(select.bind(k))
		list.add_child(b)


static func map_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var w := WorldData.W
	var h := WorldData.H
	var bits := Marshalls.base64_to_raw(WorldData.LAND)
	var land := func(x: int, y: int) -> bool:
		if y < 0 or y >= h:
			return false
		var xx := posmod(x, w)
		var i := y * w + xx
		return (bits[i >> 3] >> (i & 7)) & 1 == 1
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var lat: float = WorldData.LAT0 - (y + 0.5) * WorldData.RES
		for x in w:
			var lon := -180.0 + (x + 0.5) * WorldData.RES
			var c: Color
			if land.call(x, y):
				c = _biome(lat, lon, x, y)
				var coast: bool = not land.call(x + 1, y) or not land.call(x - 1, y) or not land.call(x, y + 1) or not land.call(x, y - 1)
				if coast:
					c = D.dark(c, 0.22)
			else:
				var near := false
				for o in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if land.call(x + o.x, y + o.y):
						near = true
						break
				c = Color("#2a5a8e") if near else Color("#1c3f6c")
				if not near and (x % 30 == 0 or y == int((84.0 - 0.0) / WorldData.RES)) and (x + y) % 2 == 0:
					c = Color("#244c7c")
				if not near and D.hash2(x, y, 3) < 0.04:
					c = Color("#234a78")
			img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(img)
	return _tex


static func _vn(x: int, y: int, cell: float, s: int) -> float:
	var fx := x / cell
	var fy := y / cell
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	var a := lerpf(D.hash2(ix, iy, s), D.hash2(ix + 1, iy, s), tx)
	var b := lerpf(D.hash2(ix, iy + 1, s), D.hash2(ix + 1, iy + 1, s), tx)
	return lerpf(a, b, ty)


static func _biome(lat0: float, lon0: float, x: int, y: int) -> Color:
	var n := D.hash2(x, y, 9)
	var lat := lat0 + (_vn(x, y, 5.0, 3) - 0.5) * 9.0 + (_vn(x, y, 2.0, 4) - 0.5) * 3.0
	var lon := lon0 + (_vn(x, y, 5.0, 5) - 0.5) * 10.0 + (_vn(x, y, 2.0, 6) - 0.5) * 3.0
	var deserts := [[15, 32, -17, 35], [13, 32, 35, 60], [25, 37, 55, 70], [37, 46, 88, 112], [-31, -19, 117, 142], [24, 37, -117, -103], [-28, -17, -71, -68], [-28, -18, 12, 25], [36, 42, 76, 90]]
	if lat0 < -62 or lat > 76 or (lon0 > -73 and lon0 < -12 and lat0 > 59 and lat > 61):
		return Color("#e8eef4") if n < 0.85 else Color("#d0dce8")
	for d in deserts:
		if lat >= d[0] and lat <= d[1] and lon >= d[2] and lon <= d[3]:
			return Color("#d8bc80") if n < 0.8 else Color("#c8a868")
	if lat > 62:
		return Color("#8a9a7a") if n < 0.75 else Color("#7a8a6a")
	if lat > 50:
		return Color("#3e6a3e") if n < 0.75 else Color("#4a7a44")
	if absf(lat) < 12:
		return Color("#2a6a2e") if n < 0.75 else Color("#347a36")
	return Color("#5a8a3e") if n < 0.75 else Color("#6a9a48")


## Draws the map, the pins, the route and the plane.
class MapCanvas:
	extends Control
	var view: MapView

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		texture_filter = TEXTURE_FILTER_NEAREST

	func _geo() -> Dictionary:
		var w := float(WorldData.W)
		var h := float(WorldData.H)
		var s := minf(size.x / w, size.y / h)
		if s >= 1.0:
			s = floorf(s * 2.0) / 2.0
		var dim := Vector2(w, h) * s
		var o := ((size - dim) * 0.5).floor()
		return {"s": s, "o": o, "dim": dim}

	func to_px(lat: float, lon: float, geo: Dictionary) -> Vector2:
		var x := (lon + 180.0) / WorldData.RES
		var y := (WorldData.LAT0 - lat) / WorldData.RES
		return geo.o + Vector2(x, y) * geo.s

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var geo := _geo()
			var best := ""
			var bd := 26.0 * 26.0
			for k in Places.ORDER:
				var P: Dictionary = Places.ALL[k]
				var d := to_px(P.lat, P.lon, geo).distance_squared_to(e.position)
				if d < bd:
					bd = d
					best = k
			if best != "":
				view.select(best)
			accept_event()

	func _draw() -> void:
		var g := view.g
		var geo := _geo()
		var s: float = geo.s
		draw_rect(Rect2(geo.o - Vector2(3, 3), geo.dim + Vector2(6, 6)), UI.BORDER)
		draw_texture_rect(MapView.map_texture(), Rect2(geo.o, geo.dim), false)
		var t := view._clock
		# Shimmer on the sea.
		for i in 40:
			var x := D.hash2(i, 0, 5) * WorldData.W
			var y := D.hash2(i, 1, 5) * WorldData.H
			if fmod(t * 0.5 + D.hash2(i, 2, 5) * 3.0, 3.0) < 0.5:
				draw_rect(Rect2(geo.o + Vector2(floorf(x), floorf(y)) * s, Vector2(s, s)), Color(1, 1, 1, 0.12))
		var cur: Dictionary = Places.ALL[g.loc]
		var dst: Dictionary = Places.ALL[view.sel]
		var a := to_px(cur.lat, cur.lon, geo)
		var b := to_px(dst.lat, dst.lon, geo)
		var wrap: float = geo.dim.x
		if b.x - a.x > wrap * 0.5:
			b.x -= wrap
		elif a.x - b.x > wrap * 0.5:
			b.x += wrap
		if view.sel != g.loc:
			var ctrl := (a + b) * 0.5 + Vector2(0, -a.distance_to(b) * 0.25)
			var n := int(a.distance_to(b) / 6.0) + 2
			for i in n:
				var k := float(i) / n
				if int(k * n - t * 6.0) % 2 != 0:
					continue
				var p := a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
				p.x = geo.o.x + fposmod(p.x - geo.o.x, wrap)
				draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(1, 0.95, 0.7, 0.8))
			if not view._fly.is_empty():
				var k: float = clampf(view._fly.t, 0.0, 1.0)
				k = k * k * (3.0 - 2.0 * k)
				var p := a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
				var p2 := a.lerp(ctrl, k + 0.01).lerp(ctrl.lerp(b, k + 0.01), k + 0.01)
				p.x = geo.o.x + fposmod(p.x - geo.o.x, wrap)
				_plane(p, (p2 - p).angle() if k < 0.99 else 0.0)
		for k in Places.ORDER:
			var P: Dictionary = Places.ALL[k]
			var p := to_px(P.lat, P.lon, geo).floor()
			var col := UI.DIM
			if k == g.loc:
				col = UI.GOLD
			elif g.S.unlocked.has(k):
				col = UI.AQUA
			var r := 4.0
			if k == view.sel:
				var pulse := 7.0 + 2.0 * sin(t * 5.0)
				draw_rect(Rect2(p - Vector2(pulse, pulse), Vector2(pulse * 2, 2)), Color.WHITE)
				draw_rect(Rect2(p - Vector2(pulse, pulse), Vector2(2, pulse * 2)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(pulse - 2, -pulse), Vector2(2, pulse * 2)), Color.WHITE)
				draw_rect(Rect2(p + Vector2(-pulse, pulse - 2), Vector2(pulse * 2, 2)), Color.WHITE)
			draw_rect(Rect2(p - Vector2(r + 2, r + 2), Vector2(r * 2 + 4, r * 2 + 4)), Color(UI.BG, 0.9))
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2, r * 2)), col)
			draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2, 2)), D.light(col, 0.4))
			if not g.S.unlocked.has(k):
				draw_rect(Rect2(p - Vector2(1, 2), Vector2(2, 3)), UI.BG)
			if k == view.sel or k == g.loc or s >= 2.5:
				var name: String = P.name
				var fs := 11
				var tw := UI.silk.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var lp := p + Vector2(-tw * 0.5, -10.0)
				lp.x = clampf(lp.x, 2.0, size.x - tw - 2.0)
				if lp.y < 12:
					lp.y = p.y + 20
				draw_string(UI.silk, lp + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
				draw_string(UI.silk, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if k == view.sel else D.light(col, 0.3))

	func _plane(p: Vector2, ang: float) -> void:
		var rows := ["...w...", "...w...", "..www..", "wwwwwww", "...w...", "..www.."]
		var c := Color("#f4f4f0")
		var sc := 2.0
		draw_set_transform(p, ang + PI / 2.0, Vector2.ONE)
		for y in rows.size():
			for x in 7:
				if rows[y][x] == "w":
					draw_rect(Rect2(Vector2(x - 3.5, y - 3.0) * sc, Vector2(sc, sc)), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
