class_name Scenery
extends RefCounted
## Paints the backdrop above the water for a place: mountains, trees, houses and landmarks.
## The result is one image that covers the sky area. The horizon is the last row of the image.

var img: Image
var W := 320
var SH := 80
var hor := Color.WHITE
var lights: Array = []
var beacons: Array = []
var rng: D.Rng


static func build(place: Dictionary, w: int, sky_h: int) -> Dictionary:
	var s := Scenery.new()
	s.W = w
	s.SH = sky_h
	s.hor = Color(place.sky[1])
	s.img = Image.create_empty(w, sky_h, false, Image.FORMAT_RGBA8)
	s.img.fill(Color(0, 0, 0, 0))
	s.rng = D.Rng.new(hash(place.name) & 0xFFFF)
	for layer in place.scene:
		s._layer(layer[0], layer[1])
	var sky := PackedInt32Array()
	sky.resize(w)
	for x in w:
		sky[x] = sky_h
		for y in sky_h:
			if s.img.get_pixel(x, y).a > 0.0:
				sky[x] = y
				break
	return {"img": s.img, "tex": ImageTexture.create_from_image(s.img), "lights": s.lights, "beacons": s.beacons, "skyline": sky}


func _layer(kind: String, p: Dictionary) -> void:
	match kind:
		"range":
			_range(p)
		"hills":
			_hills(p)
		"dunes":
			_dunes(p)
		"karst":
			_karst(p)
		"cone":
			_cone(p)
		"shore":
			_shore(p)
		"trees":
			_trees(p)
		"houses":
			_houses(p)
		"landmark":
			_landmark(p)
		"bridge":
			_bridge(p)
		"isle":
			_isle(p)
		"cliff":
			_cliff(p)
		"mesa":
			_mesa(p)
		"jungle":
			_jungle(p)
		"icebergs":
			_icebergs(p)
		"rockhill":
			_rockhill(p)
		"glacier":
			_glacier(p)


# ---------- pixel helpers ----------

func _p(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= W or y >= SH:
		return
	if c.a >= 1.0:
		img.set_pixel(x, y, c)
	elif c.a > 0.0:
		var b := img.get_pixel(x, y)
		img.set_pixel(x, y, b.blend(c) if b.a > 0.0 else c)


func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_p(xx, yy, c)


func _col(x: int, y0: int, y1: int, c: Color) -> void:
	for y in range(maxi(0, y0), mini(SH, y1 + 1)):
		_p(x, y, c)


func _mist(c: Color, m: float) -> Color:
	return D.mix(c, hor, clampf(m, 0.0, 1.0))


func _top_at(x: int) -> int:
	if x < 0 or x >= W:
		return SH
	for y in SH:
		if img.get_pixel(x, y).a > 0.0:
			return y
	return SH


func _span(p: Dictionary) -> Vector2i:
	return Vector2i(D.jr(p.get("x0", 0.0) * W), D.jr(p.get("x1", 1.0) * W))


## Edge fade so a layer that stops before the screen edge slopes down into the sea.
func _edge_fade(x: int, sp: Vector2i, full: bool) -> float:
	if full:
		return 1.0
	var e := maxf(8.0, (sp.y - sp.x) * 0.16)
	var a := 1.0 if sp.x <= 0 else clampf((x - sp.x) / e, 0.0, 1.0)
	var b := 1.0 if sp.y >= W else clampf((sp.y - x) / e, 0.0, 1.0)
	var k := minf(a, b)
	return k * k * (3.0 - 2.0 * k)


## Draws a filled terrain profile with left-lit shading. heights holds pixels above the horizon.
func _terrain(heights: PackedFloat32Array, x0: int, col: Color, mist: float, snow: float, shade := 0.14, tex := 0.0, snow_col := Color("#f2f5fa")) -> void:
	var n := heights.size()
	var hmax := 0.0
	for v in heights:
		hmax = maxf(hmax, v)
	var lit := _mist(D.light(col, shade), mist)
	var dk := _mist(D.dark(col, shade), mist)
	var mid := _mist(col, mist)
	var sl := _mist(snow_col, mist * 0.8)
	var sd := _mist(D.mix(snow_col, Color("#9ab0cc"), 0.45), mist * 0.8)
	var snow_line := hmax * (1.0 - snow)
	for i in n:
		var x := x0 + i
		var hh := heights[i]
		if hh < 0.5:
			continue
		var top := SH - 1 - D.jr(hh)
		var prev := heights[maxi(0, i - 2)]
		var nxt := heights[mini(n - 1, i + 2)]
		var rising := nxt - prev > 0.4 or (absf(nxt - prev) <= 0.4 and hh >= prev)
		for y in range(maxi(0, top), SH):
			var above := float(SH - 1 - y)
			var c := mid
			if rising:
				c = lit if above > hh * 0.3 else (lit if (x + y) % 2 == 0 and above > hh * 0.15 else mid)
			else:
				c = dk if above > hh * 0.3 else (dk if (x + y) % 2 == 0 and above > hh * 0.15 else mid)
			if tex > 0.0 and D.hash2(x, y, 19) < tex:
				c = _mist(D.dark(col, 0.25), mist)
			if snow > 0.0:
				var ragged := (D.hash2(x, 0, 77) - 0.5) * 4.0 + sin(x * 0.7) * 1.5
				if above > snow_line + ragged and above > 3.0:
					c = sl if rising else sd
					if not rising and D.hash2(x, y, 3) < 0.25:
						c = mid
			_p(x, y, c)


func _ridge(x: float, seed_value: int, rough: float) -> float:
	var v := 0.0
	var amp := 1.0
	var f := 0.035
	var tot := 0.0
	for k in 3:
		var nz := D.noise1(x * f, seed_value + k * 17)
		var r := 1.0 - absf(nz * 2.0 - 1.0)
		v += amp * lerpf(nz, r, rough)
		tot += amp
		amp *= 0.5
		f *= 2.1
	return v / tot


# ---------- layers ----------

func _range(p: Dictionary) -> void:
	var sp := _span(p)
	var full := sp.x <= 0 and sp.y >= W
	var hs := PackedFloat32Array()
	var hmax: float = p.h * SH
	var seed_value: int = p.get("seed", 1)
	var rough: float = p.get("rough", 0.8)
	for x in range(sp.x, sp.y):
		var v := _ridge(x * 320.0 / W, seed_value, rough)
		var hh := hmax * (0.25 + 0.75 * pow(v, 1.35)) * _edge_fade(x, sp, full)
		hs.append(hh)
	_terrain(hs, sp.x, Color(p.col), p.get("mist", 0.0), p.get("snow", 0.0), 0.14, 0.04)


func _hills(p: Dictionary) -> void:
	var sp := _span(p)
	var full := sp.x <= 0 and sp.y >= W
	var hs := PackedFloat32Array()
	var hmax: float = p.h * SH
	var s: float = p.get("seed", 1)
	for x in range(sp.x, sp.y):
		var xf := x * 320.0 / W
		var v := 0.5 + 0.28 * sin(xf * 0.021 + s) + 0.16 * sin(xf * 0.053 + s * 2.3) + 0.06 * sin(xf * 0.13 + s * 0.7)
		hs.append(hmax * clampf(v, 0.05, 1.0) * _edge_fade(x, sp, full))
	var mist: float = p.get("mist", 0.0)
	_terrain(hs, sp.x, Color(p.col), mist, 0.35 if p.get("snowy", false) else 0.0, 0.08, 0.0)
	if p.has("heather"):
		var hc := _mist(Color(p.heather), mist)
		for i in hs.size():
			var x := sp.x + i
			var top := SH - 1 - D.jr(hs[i])
			for y in range(top + 1, SH):
				if D.hash2(floori(x / 4.0), floori(y / 2.0), 31) < 0.28 and D.hash2(x, y, 5) < 0.7:
					_p(x, y, hc)


func _dunes(p: Dictionary) -> void:
	var hs := PackedFloat32Array()
	var hmax: float = p.h * SH
	var s: float = p.get("seed", 1)
	for x in W:
		var xf := x * 320.0 / W
		hs.append(hmax * (0.45 + 0.3 * sin(xf * 0.03 + s) + 0.25 * sin(xf * 0.071 + s * 1.7)))
	var c := Color(p.col)
	var c2 := Color(p.col2)
	for x in W:
		var top := SH - 1 - D.jr(hs[x])
		var rising := x == 0 or hs[x] >= hs[x - 1]
		for y in range(maxi(0, top), SH):
			_p(x, y, c2 if rising and y < top + 3 else (c if (x + y) % 5 != 0 else D.dark(c, 0.06)))


func _karst(p: Dictionary) -> void:
	var n: int = p.get("n", 6)
	var hmax: float = p.h * SH
	var mist: float = p.get("mist", 0.0)
	var col := Color(p.col)
	var r := D.Rng.new(p.get("seed", 1) * 97)
	var towers := []
	for i in n + 2:
		var cx := (i - 0.5 + r.range_f(-0.25, 0.25)) / n * W
		var tw := W / float(n) * r.range_f(0.45, 0.85)
		towers.append({"cx": cx, "w": tw, "h": hmax * r.range_f(0.5, 1.0), "lean": r.range_f(-0.12, 0.12)})
	for t in towers:
		var half: float = t.w * 0.5
		for x in range(floori(t.cx - half), ceili(t.cx + half) + 1):
			if x < 0 or x >= W:
				continue
			var d: float = absf(x + 0.5 - t.cx) / half
			if d > 1.0:
				continue
			var prof := pow(1.0 - pow(d, 2.4), 1.0 / 2.4)
			var hh: float = t.h * prof * (0.97 + 0.03 * sin(x * 1.3))
			var top := SH - 1 - D.jr(hh)
			var left_side: bool = x < t.cx - half * 0.15
			for y in range(maxi(0, top), SH):
				var above := float(SH - 1 - y)
				var low := 1.0 - above / maxf(1.0, t.h)
				var m := mist + (1.0 - mist) * 0.55 * low * low
				var c := D.light(col, 0.12) if left_side else D.dark(col, 0.1)
				if D.hash2(x, y, 13) < 0.16:
					c = D.dark(col, 0.25)
				_p(x, y, _mist(c, m))


func _cone(p: Dictionary) -> void:
	var cx: float = p.x * W
	var half: float = p.w * W * 0.5
	var hmax: float = p.h * SH
	var mist: float = p.get("mist", 0.0)
	var col := Color(p.col)
	var snow: float = p.get("snow", 0.3)
	for x in range(floori(cx - half), ceili(cx + half) + 1):
		if x < 0 or x >= W:
			continue
		var d := absf(x + 0.5 - cx) / half
		if d >= 1.0:
			continue
		var hh := hmax * minf(0.94, pow(1.0 - d, 1.55) * 1.04)
		var top := SH - 1 - D.jr(hh)
		var left_side := x < cx
		var streak := D.noise1(x * 0.35, 55) * hmax * 0.1 + D.noise1(x * 1.1, 56) * 2.5
		for y in range(maxi(0, top), SH):
			var above := float(SH - 1 - y)
			var c := D.light(col, 0.1) if left_side else D.dark(col, 0.1)
			if above > hmax * (1.0 - snow) - streak:
				c = Color("#f4f7fb") if left_side else Color("#c4d0e4")
			_p(x, y, _mist(c, mist * (0.6 + 0.4 * (1.0 - above / hmax))))


func _shore(p: Dictionary) -> void:
	var h: int = p.get("h", 2)
	var c := Color(p.col)
	var c2 := Color(p.get("col2", p.col))
	for x in W:
		var hh := h + (1 if D.hash2(x / 3, 0, 9) < 0.3 else 0)
		for k in hh:
			var y := SH - 1 - k
			if img.get_pixel(x, y).a > 0.0 or k == 0:
				_p(x, y, c2 if k == 0 else (c if D.hash2(x, y, 4) < 0.8 else D.dark(c, 0.2)))


func _isle(p: Dictionary) -> void:
	var sp := _span(p)
	var h: int = p.get("h", 4)
	var c := Color(p.col)
	var sand := Color(p.get("sand", "#e8dcb0"))
	var mid := (sp.x + sp.y) * 0.5
	var half := (sp.y - sp.x) * 0.5
	for x in range(sp.x, sp.y):
		var d := absf(x + 0.5 - mid) / half
		var hh := D.jr(h * sqrt(maxf(0.0, 1.0 - d * d * d * d)) + (D.hash2(x, 0, 3) - 0.5) * 1.5)
		for k in maxi(0, hh):
			_p(x, SH - 2 - k, c if (x + k) % 3 != 0 else D.light(c, 0.12))
		_p(x, SH - 1, sand)


func _cliff(p: Dictionary) -> void:
	var sp := _span(p)
	var hmax: float = p.h * SH
	var c := Color(p.col)
	var c2 := Color(p.col2)
	var hs := PackedFloat32Array()
	for x in range(sp.x, sp.y):
		var k := float(x - sp.x) / maxf(1.0, sp.y - sp.x)
		var prof := 1.0 - pow(k, 2.2)
		var hh := hmax * (0.55 + 0.45 * prof) * (1.0 if k < 0.85 else (1.0 - (k - 0.85) / 0.15 * 0.9))
		hh += (D.noise1(x * 0.3, p.get("seed", 1)) - 0.5) * 3.0
		hs.append(hh)
	for i in hs.size():
		var x := sp.x + i
		var top := SH - 1 - D.jr(hs[i])
		for y in range(maxi(0, top), SH):
			var cc := c2 if (y - top) < 2 or (y % 4 == 0 and D.hash2(x, y, 2) < 0.6) else c
			if D.hash2(x, y, 7) < 0.08:
				cc = D.dark(c, 0.2)
			_p(x, y, cc)
	# Lemon terraces and green scrub on the cliff.
	for i in hs.size():
		var x := sp.x + i
		var top := SH - 1 - D.jr(hs[i])
		if D.hash2(x, 0, 21) < 0.5:
			_p(x, top, Color("#4a6a2e"))
		for y in range(top + 2, SH - 2):
			if D.hash2(floori(x / 3.0), floori(y / 2.0), 44) < 0.12:
				_p(x, y, Color("#5a7a32") if D.hash2(x, y, 45) < 0.8 else Color("#e8d040"))


func _mesa(p: Dictionary) -> void:
	var sp := _span(p)
	var hmax: float = p.h * SH
	var c := Color(p.col)
	var c2 := Color(p.col2)
	for x in range(sp.x, sp.y):
		var k := float(x - sp.x) / maxf(1.0, sp.y - sp.x)
		var nz := D.noise1(x * 0.08, p.get("seed", 1))
		var hh := hmax * (0.7 + 0.3 * nz) * (1.0 if k < 0.8 else maxf(0.0, 1.0 - (k - 0.8) / 0.2))
		var top := SH - 1 - D.jr(hh)
		for y in range(maxi(0, top), SH):
			var band := floori((y - top) / 3.0) % 2 == 0
			var cc := c2 if band else c
			if y - top == 0:
				cc = D.light(c2, 0.15)
			if D.hash2(x, y, 3) < 0.07:
				cc = D.dark(c, 0.2)
			_p(x, y, cc)


func _jungle(p: Dictionary) -> void:
	var hmax: float = p.h * SH
	var mist: float = p.get("mist", 0.0)
	var c := Color(p.col)
	var c2 := Color(p.col2)
	var r := D.Rng.new(p.get("seed", 1) * 53)
	var blobs := []
	var x := -6.0
	while x < W + 6:
		var rad := r.range_f(3.0, 7.0) * SH / 80.0
		var tall := r.next() < 0.12
		blobs.append({"x": x, "r": rad, "h": hmax * (r.range_f(0.6, 0.9) if not tall else r.range_f(1.0, 1.25))})
		x += rad * r.range_f(0.9, 1.4)
	for b in blobs:
		var rad: float = b.r
		var cy: float = SH - 1 - b.h + rad
		for yy in range(floori(cy - rad), SH):
			for xx in range(floori(b.x - rad), ceili(b.x + rad) + 1):
				var dy: float = yy - cy
				var dx: float = xx + 0.5 - b.x
				var ins: bool = dx * dx + dy * dy <= rad * rad if dy < 0.0 else absf(dx) <= rad
				if not ins:
					continue
				var hl: bool = dx < -rad * 0.1 and dy < -rad * 0.2
				var cc := c2 if hl and (xx + yy) % 2 == 0 else (D.dark(c, 0.12) if dx > rad * 0.4 else c)
				if D.hash2(xx, yy, 8) < 0.1:
					cc = D.dark(c, 0.25)
				_p(xx, yy, _mist(cc, mist))
		if b.h > hmax:
			_col(D.jr(b.x), D.jr(cy + rad), SH - 1, _mist(Color("#5a4a3a"), mist))


func _icebergs(p: Dictionary) -> void:
	var n: int = p.get("n", 3)
	var hmax: float = p.get("h", 0.5) * SH
	var r := D.Rng.new(p.get("seed", 1) * 71)
	for i in n:
		var cx := (i + 0.5 + r.range_f(-0.2, 0.2)) / n * W
		var bw := r.range_f(18.0, 40.0) * W / 320.0
		var bh := hmax * r.range_f(0.45, 1.0)
		var tabular := r.next() < 0.5
		var x0 := floori(cx - bw * 0.5)
		var x1 := ceili(cx + bw * 0.5)
		for x in range(x0, x1 + 1):
			var k := (x - x0) / maxf(1.0, x1 - x0)
			var hh: float
			if tabular:
				hh = bh * (0.85 + 0.15 * D.noise1(x * 0.4, i)) * (1.0 if k > 0.06 and k < 0.94 else 0.6)
			else:
				var pk := 1.0 - absf(k - r.range_f(0.4, 0.6)) * 1.8
				hh = bh * clampf(pk, 0.15, 1.0) * (0.8 + 0.2 * D.noise1(x * 0.5, i + 9))
			var top := SH - 1 - D.jr(hh)
			for y in range(maxi(0, top), SH):
				var depth := y - top
				var cc := Color("#f6fafd") if k < 0.55 else Color("#cfe0ef")
				if depth > hh * 0.6 and k > 0.4:
					cc = Color("#a8c6e0")
				if D.hash2(x, y, 4) < 0.05:
					cc = Color("#8ab4d8")
				_p(x, y, _mist(cc, 0.1))


func _rockhill(p: Dictionary) -> void:
	var sp := _span(p)
	var hmax: float = p.h * SH
	var c := Color(p.col)
	var c2 := Color(p.col2)
	for x in range(sp.x, sp.y):
		var k := float(x - sp.x) / maxf(1.0, sp.y - sp.x)
		var hh := hmax * (0.55 + 0.45 * (1.0 - k * k)) * minf(1.0, (1.0 - k) * 4.0) + (D.noise1(x * 0.25, p.get("seed", 1)) - 0.5) * 4.0
		var top := SH - 1 - D.jr(hh)
		for y in range(maxi(0, top), SH):
			var cc := c if D.hash2(x, y, 5) < 0.85 else D.dark(c, 0.2)
			var sn := D.noise1(x * 0.12 + y * 0.31, 9) * D.noise1(y * 0.2 - x * 0.05, 10)
			if sn > 0.38 or y == top or (y == top + 1 and x % 3 != 0):
				cc = c2 if D.hash2(x, y, 6) < 0.92 else D.dark(c2, 0.12)
			_p(x, y, cc)


func _glacier(p: Dictionary) -> void:
	var hh: float = p.h * SH
	var c := Color(p.col)
	var c2 := Color(p.col2)
	for x in W:
		var h2 := hh * (0.85 + 0.15 * D.noise1(x * 0.05, 3))
		var top := SH - 1 - D.jr(h2)
		for y in range(maxi(0, top), SH):
			var face := y - top > 2
			var cc := c if not face else (c2 if D.hash2(x, 0, 6) < 0.6 else D.dark(c2, 0.12))
			if face and x % 7 == 0:
				cc = D.dark(c2, 0.2)
			_p(x, y, cc)


func _bridge(p: Dictionary) -> void:
	var y := SH - 1 - int(p.get("y", 6))
	var c := Color(p.col)
	var c2 := Color(p.col2)
	var gap0 := D.jr(W * 0.36)
	var gap1 := D.jr(W * 0.42)
	for x in W:
		if x >= gap0 and x < gap1:
			continue
		_p(x, y, c)
		_p(x, y + 1, c2)
		if x % 7 == 0:
			_col(x, y + 2, SH - 1, c2)


# ---------- trees ----------

func _trees(p: Dictionary) -> void:
	var sp := _span(p)
	var n: int = p.get("n", 5)
	var h: int = p.get("h", 10)
	var kind: String = p.kind
	var c := Color(p.col)
	var c2 := Color(p.get("col2", "#5a3a2a"))
	var on_slope: bool = p.get("onslope", false)
	var base_off: int = p.get("base", 1)
	var dense: bool = p.get("dense", false)
	var span := sp.y - sp.x
	for i in n:
		var x := D.jr(sp.x + (i + 0.5 + rng.range_f(-0.35, 0.35)) / n * span)
		var th := maxi(3, D.jr(h * rng.range_f(0.72, 1.25) * SH / 80.0))
		var by := SH - 1 - base_off
		if on_slope:
			by = _top_at(x) + 1
			if by >= SH - 1:
				continue
		if dense:
			by += rng.range_i(-1, 1)
		_tree(kind, x, by, th, c, c2)


func _tree(kind: String, x: int, by: int, th: int, c: Color, c2: Color) -> void:
	var lit := D.light(c, 0.15)
	match kind:
		"pine", "spruce":
			_col(x, by - 1, by, c2)
			for j in range(1, th):
				var wv := (th - j) * (0.42 if kind == "spruce" else 0.5) + (0.6 if j % 3 == 0 else 0.0)
				var hw := D.jr(wv)
				for dx in range(-hw, hw + 1):
					_p(x + dx, by - j, lit if dx < 0 and (dx + j) % 2 == 0 else c)
		"cypress":
			_col(x, by - 1, by, c2)
			for j in range(1, th):
				var k := float(j) / th
				var hw := D.jr(1.6 * sin(k * PI) + 0.2)
				for dx in range(-hw, hw + 1):
					_p(x + dx, by - j, lit if dx < 0 else c)
		"palm":
			var lean := 1 if rng.next() < 0.5 else -1
			var tx := x
			var ty := by
			for j in th:
				tx = x + D.jr(sin(float(j) / th * 1.4) * th * 0.25 * lean)
				ty = by - j
				_p(tx, ty, c2 if j % 3 != 0 else D.dark(c2, 0.25))
			for a in [-2.8, -2.2, -1.6, -0.9, -0.35, 0.3]:
				var ln := th * 0.42 + rng.range_f(-1.0, 1.5)
				for k in range(1, D.jr(ln)):
					var fx := tx + D.jr(cos(a) * k)
					var fy := ty + D.jr(sin(a) * k * 0.55 + k * k * 0.06)
					_p(fx, fy, c if k % 2 == 0 else lit)
			_p(tx, ty + 1, Color("#5a3a1a"))
		"blossom":
			for j in D.jr(th * 0.55):
				_p(x, by - j, c2)
			var cy := by - D.jr(th * 0.62)
			for b in 4:
				var bxx := x + rng.range_i(-3, 3)
				var byy := cy + rng.range_i(-2, 1)
				var rad := rng.range_f(2.0, 3.5)
				for yy in range(floori(byy - rad), ceili(byy + rad) + 1):
					for xx in range(floori(bxx - rad), ceili(bxx + rad) + 1):
						if Vector2(xx - bxx, yy - byy).length() <= rad:
							var cc := c if D.hash2(xx, yy, 2) < 0.7 else (D.light(c, 0.3) if yy < byy else D.dark(c, 0.15))
							_p(xx, yy, cc)
		"jpine":
			var tx := x
			for j in D.jr(th * 0.7):
				tx = x + D.jr(sin(j * 0.5) * 1.2)
				_p(tx, by - j, c2)
			for k in 3:
				var py := by - D.jr(th * (0.45 + k * 0.22))
				var pw := D.jr((5 - k) * th / 9.0) + 1
				var px := tx + rng.range_i(-2, 2)
				for dx in range(-pw, pw + 1):
					_p(px + dx, py, c)
					if absi(dx) < pw - 1:
						_p(px + dx, py - 1, lit if dx < 0 else c)
		"bamboo":
			var n := rng.range_i(4, 6)
			for s in n:
				var lean := (s - (n - 1) * 0.5) * 0.09 + rng.range_f(-0.04, 0.04)
				var sh := th + rng.range_i(-2, 3)
				var sx := x + D.jr((s - (n - 1) * 0.5) * 1.2)
				for j in sh:
					var lx := sx + D.jr(j * lean + j * j * 0.006 * signf(lean))
					_p(lx, by - j, D.dark(c, 0.15) if j % 5 == 0 else (c if s % 2 == 0 else lit))
					if j > sh * 0.45 and j % 2 == 0:
						var side := 1 if (j / 2 + s) % 2 == 0 else -1
						_p(lx + side, by - j, c2)
						_p(lx + side * 2, by - j + 1, c2)
						if j % 4 == 0:
							_p(lx + side * 3, by - j + 1, D.dark(c2, 0.15))
		"jungle":
			var trunk := D.dark(Color("#5a4030"), 0.1)
			for j in D.jr(th * 0.5):
				_p(x, by - j, trunk)
			var puffs := rng.range_i(3, 5)
			for k in puffs:
				var rad := maxf(2.0, th * rng.range_f(0.22, 0.34))
				var px := x + rng.range_f(-th * 0.3, th * 0.3)
				var py := by - th * rng.range_f(0.55, 0.85) + rad * 0.5
				for yy in range(floori(py - rad), ceili(py + rad) + 1):
					for xx in range(floori(px - rad), ceili(px + rad) + 1):
						var dx := xx + 0.5 - px
						var dy := yy + 0.5 - py
						if dx * dx + dy * dy > rad * rad:
							continue
						var cc := c
						if dx < 0 and dy < 0 and (xx + yy) % 2 == 0:
							cc = c2
						elif dy > rad * 0.3:
							cc = D.dark(c, 0.15)
						if D.hash2(xx, yy, 17) < 0.08:
							cc = D.dark(c, 0.25)
						_p(xx, yy, cc)
		"papyrus":
			for j in th:
				_p(x, by - j, c)
			for a in [-2, -1, 0, 1, 2]:
				_p(x + a, by - th - (1 if absi(a) < 2 else 0), c2)
				if absi(a) == 2:
					_p(x + a + signi(a), by - th + 1, c2)
		"cactus":
			for j in th:
				_p(x, by - j, c)
				_p(x + 1, by - j, D.dark(c, 0.2))
			for side in [-1, 1]:
				if rng.next() < 0.7:
					var ay := by - D.jr(th * rng.range_f(0.35, 0.55))
					var ax := x + (2 if side > 0 else -2)
					_p(x + (1 if side > 0 else -1) + (1 if side > 0 else 0), ay, c)
					for j in D.jr(th * 0.35):
						_p(ax, ay - j, c)


# ---------- houses ----------

func _houses(p: Dictionary) -> void:
	var sp := _span(p)
	var n: int = p.get("n", 3)
	var cols: Array = p.get("cols", ["#b8322a"])
	var style: String = p.style
	var slope: bool = p.get("slope", false)
	var span := sp.y - sp.x
	var placed := []
	for i in n:
		var x := D.jr(sp.x + (i + 0.5 + rng.range_f(-0.3, 0.3)) / n * span)
		var c := Color(cols[i % cols.size()])
		match style:
			"rorbu":
				_rorbu(x, c)
			"amalfi":
				var top := _top_at(x)
				var depth := SH - 1 - top
				var y := top + 3 + rng.range_i(0, maxi(1, D.jr(depth * 0.55)))
				_box_house(x, y, rng.range_i(4, 7), rng.range_i(3, 6), c, Color("#c86a3a"), false)
			"nordic":
				var top := _top_at(x) + 2 + rng.range_i(0, 5)
				_box_house(x, top, rng.range_i(5, 7), 3, c, Color("#2a2a2e"), true)
			"stilt":
				_stilt(x, c, true)
			"palafita":
				_stilt(x, c, false)
		placed.append(x)


func _window(x: int, y: int) -> void:
	_p(x, y, Color("#2a2a34"))
	lights.append(Vector2i(x, y))


func _rorbu(x: int, c: Color) -> void:
	var w := 8
	var fy := SH - 4
	var x0 := x - w / 2
	for k in 3:
		_col(x0 + 1 + k * 3, fy, SH - 1, Color("#3a2a20"))
	_rect(x0, fy - 5, w, 5, c)
	_rect(x0, fy - 5, w, 1, D.light(c, 0.15))
	for j in 4:
		var rw := w + 2 - j * 2
		_rect(x - rw / 2, fy - 6 - j, rw, 1, Color("#2a2420") if j > 0 else Color("#3a3028"))
	_p(x0 + 2, fy - 3, Color("#f4f0e4"))
	_window(x0 + 2, fy - 3)
	_p(x0 + 5, fy - 3, Color("#f4f0e4"))
	_window(x0 + 5, fy - 3)
	_rect(x0, fy, w, 1, Color("#2a2020"))


func _box_house(x: int, y: int, w: int, h: int, c: Color, roof: Color, pitched: bool) -> void:
	var x0 := x - w / 2
	_rect(x0, y - h, w, h, c)
	_rect(x0, y - h, 1, h, D.light(c, 0.1))
	_rect(x0 + w - 1, y - h, 1, h, D.dark(c, 0.15))
	if pitched:
		for j in 3:
			_rect(x0 - 1 + j, y - h - 1 - j, w + 2 - j * 2, 1, roof)
	else:
		_rect(x0, y - h - 1, w, 1, roof)
	for wx in range(x0 + 1, x0 + w - 1, 2):
		if D.hash2(wx, y, 3) < 0.7:
			_window(wx, y - h + 1)


func _stilt(x: int, c: Color, thai: bool) -> void:
	var w := 10
	var fy := SH - 5
	var x0 := x - w / 2
	for k in 4:
		_col(x0 + k * 3, fy, SH - 1, Color("#3a2818"))
	_rect(x0, fy - 5, w, 5, c)
	_rect(x0, fy, w, 1, D.dark(c, 0.3))
	if thai:
		for j in 5:
			var rw := w + 2 - j * 2
			_rect(x - rw / 2, fy - 6 - j, rw, 1, Color("#8a2a1e") if j % 2 == 0 else Color("#a83a24"))
		_p(x0 - 2, fy - 7, Color("#c89a3a"))
		_p(x0 + w + 1, fy - 7, Color("#c89a3a"))
	else:
		_rect(x0 - 1, fy - 6, w + 2, 1, Color("#9aa0a8"))
		_rect(x0, fy - 7, w, 1, Color("#b8bec6"))
	_p(x0 + 2, fy - 3, Color("#f0d890"))
	_window(x0 + 2, fy - 3)
	_p(x0 + 6, fy - 3, Color("#f0d890"))
	_window(x0 + 6, fy - 3)


# ---------- landmarks ----------

func _landmark(p: Dictionary) -> void:
	var x := D.jr(p.x * W)
	var s: float = p.get("s", 1.0)
	var by := SH - 1
	match p.k:
		"pyramid":
			var hh := D.jr(SH * 0.42 * s)
			for j in hh:
				var hw := hh - j
				for dx in range(-hw, hw + 1):
					var cc := Color("#e8cc8a") if dx < 0 else Color("#b8945a")
					if j % 3 == 0:
						cc = D.dark(cc, 0.08)
					if D.hash2(x + dx, j, 5) < 0.05:
						cc = D.dark(cc, 0.18)
					_p(x + dx, by - j, _mist(cc, 0.18))
		"castle":
			var stone := Color("#7a7468")
			var dk := Color("#57524a")
			_rect(x - 14, by - 6, 24, 6, stone)
			for k in range(-14, 10, 3):
				_rect(x + k, by - 7, 2, 1, stone)
			_rect(x + 2, by - 18, 8, 12, stone)
			_rect(x + 8, by - 18, 2, 12, dk)
			_rect(x + 2, by - 19, 2, 1, stone)
			_rect(x + 5, by - 20, 2, 2, stone)
			_rect(x + 8, by - 19, 2, 1, dk)
			for wy in [by - 15, by - 11]:
				_p(x + 5, wy, Color("#1e1e22"))
			_rect(x - 10, by - 4, 2, 2, Color("#1e1e22"))
			_rect(x - 2, by - 4, 2, 2, Color("#1e1e22"))
			_rect(x - 16, by - 2, 34, 2, Color("#4a5a36"))
		"dome":
			var y := _top_at(x) + 6
			_rect(x - 3, y - 12, 6, 12, Color("#f2ead8"))
			_rect(x + 2, y - 12, 1, 12, Color("#d8ccb0"))
			_rect(x - 3, y - 13, 6, 1, Color("#c8a040"))
			for j in 4:
				_rect(x - 3 + j, y - 14 - j, 6 - j * 2, 1, Color("#3a9a6a") if j % 2 == 0 else Color("#e8c040"))
			_p(x, y - 18, Color("#e8c040"))
			_p(x - 1, y - 8, Color("#2a2a34"))
			_window(x - 1, y - 8)
		"pagoda":
			var y := by - 1
			var tw := 9
			for tier in 5:
				var ww := tw - tier
				_rect(x - ww / 2, y - 3, ww, 3, Color("#8a2a24"))
				_rect(x - ww / 2 - 2, y - 4, ww + 4, 1, Color("#2a2a30"))
				_p(x - ww / 2 - 3, y - 5, Color("#2a2a30"))
				_p(x + ww / 2 + 2, y - 5, Color("#2a2a30"))
				_window(x, y - 2)
				y -= 4
			_col(x, y - 4, y, Color("#c8a040"))
		"torii":
			var red := Color("#d83a2a")
			var top := by - 16
			_col(x - 5, top + 2, by + 6, red)
			_col(x + 5, top + 2, by + 6, red)
			_rect(x - 8, top, 17, 1, Color("#1a1a1a"))
			_rect(x - 7, top + 1, 15, 1, red)
			_rect(x - 6, top + 4, 13, 1, red)
		"lighthouse":
			var y := by - 2
			for j in 20:
				var band := floori(j / 4.0) % 2 == 0
				var hw := 2 if j < 12 else 1
				for dx in range(-hw, hw + 1):
					_p(x + dx, y - j, (Color("#f4f4f0") if band else Color("#d83a2a")) if dx <= 0 else (Color("#d0d0cc") if band else Color("#a82a20")))
			_rect(x - 2, y - 23, 5, 3, Color("#2a2a30"))
			_p(x, y - 22, Color("#fff0a0"))
			beacons.append(Vector2i(x, y - 22))
			_rect(x - 2, y - 24, 5, 1, Color("#d83a2a"))
			_rect(x - 4, by - 1, 9, 2, Color("#6a6a60"))
		"prang":
			var hh := 30
			for j in hh:
				var k := float(j) / hh
				var hw := D.jr(4.5 * (1.0 - k * k) + 0.5)
				for dx in range(-hw, hw + 1):
					var cc := Color("#b8a888") if dx < 0 else Color("#8a7a62")
					if j % 4 == 0:
						cc = D.dark(cc, 0.15)
					_p(x + dx, by - j, cc)
			_rect(x - 7, by - 4, 15, 4, Color("#9a8a6a"))
		"stupa":
			var hh := D.jr(22 * s)
			for j in hh:
				var k := float(j) / hh
				var hw := D.jr((5.0 * s) * (1.0 - k) * (1.0 if k > 0.35 else 1.2) + 0.4)
				for dx in range(-hw, hw + 1):
					_p(x + dx, by - j, Color("#f2c84a") if dx < 0 else Color("#c89a2a"))
			_rect(x - D.jr(6 * s), by - 2, D.jr(12 * s) + 1, 2, Color("#e8e0d0"))
		"station":
			var y := by - 1
			_rect(x - 10, y - 5, 9, 5, Color("#e85a2a"))
			_rect(x - 10, y - 5, 9, 1, Color("#f08a5a"))
			_rect(x + 1, y - 4, 7, 4, Color("#e8c040"))
			_window(x - 8, y - 3)
			_window(x - 5, y - 3)
			_window(x + 3, y - 2)
			_col(x + 10, y - 14, y, Color("#5a5a60"))
			_rect(x + 8, y - 14, 5, 1, Color("#5a5a60"))
			beacons.append(Vector2i(x + 10, y - 15))
		"arch":
			var hh := D.jr(SH * 0.42)
			var bw := 22
			for xx in range(x - bw / 2, x + bw / 2):
				var k := float(xx - (x - bw / 2)) / bw
				var top := by - D.jr(hh * (0.55 + 0.45 * sin(k * PI)) + (D.hash2(xx, 0, 4) - 0.5) * 3.0)
				for y in range(top, by + 1):
					var hole := absf(k - 0.5) < 0.16 and y > by - hh * 0.42
					if hole:
						continue
					var cc := Color("#a88462") if k < 0.5 else Color("#7a5e44")
					if D.hash2(xx, y, 9) < 0.1:
						cc = Color("#5a442e")
					_p(xx, y, cc)
			for xx in range(x + bw / 2 + 2, x + bw / 2 + 9):
				var top := by - D.jr(hh * 0.5 * (1.0 - absf(xx - (x + bw / 2 + 5)) / 5.0))
				for y in range(top, by + 1):
					_p(xx, y, Color("#8a6a4c"))
