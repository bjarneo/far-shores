class_name OverlayView
extends Node2D
## Draws the layer above the day and night tint: stars, the moon, the aurora, lit windows,
## glowing eyes, bite markers, the cast preview and coin pops.

var g: Game

const DIG := {"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001",
	"5": "111100111001111", "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111", "+": "000010111010000"}
const BANG := ["1", "1", "1", "0", "1"]
const QUERY := ["111", "001", "010", "000", "010"]
const SHADOW := Color("#0b1120")


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if g == null or g.S.is_empty() or g.backdrop.is_empty():
		return
	var sk := g.sky()
	var dark := clampf((0.75 - sk.light) / 0.45, 0.0, 1.0)
	var clear: bool = g.S.wx == "clear" or g.S.wx == "cloud"
	if dark > 0.0:
		if clear:
			_stars(dark * (1.0 if g.S.wx == "clear" else 0.4))
			_moon(dark)
			if g.place.get("aurora", false) and g.S.wx == "clear":
				_aurora(dark)
		_lights(dark)
		_glow_eyes(dark)
	_beacons(dark)
	_markers()
	_aim()
	for p in g.pops:
		var a := clampf(1.6 - p.t, 0.0, 1.0)
		_text(p.txt, D.jr(p.x - p.txt.length() * 2), D.jr(p.y), Color(1, 0.827, 0.306, a), a)


func _sky_ok(x: int, y: int) -> bool:
	var sl: PackedInt32Array = g.backdrop.skyline
	return x >= 0 and x < sl.size() and y < sl[x]


func _stars(a: float) -> void:
	var W := g.W
	var n := W / 5
	for i in n:
		var x := floori(D.hash2(i, 1, 91) * W)
		var y := floori(D.hash2(i, 2, 91) * g.SURF * 0.85)
		if not _sky_ok(x, y):
			continue
		var tw := 0.55 + 0.45 * sin(g.T * (1.0 + D.hash2(i, 3, 91) * 2.0) + i)
		draw_rect(Rect2(x, y, 1, 1), Color(1, 1, 0.95, a * tw * (0.5 + D.hash2(i, 4, 91) * 0.5)))


func _moon(a: float) -> void:
	var h := g.local_hours()
	var k := fposmod(h - 18.5, 24.0) / 12.0
	if k > 1.0:
		return
	var cx := g.W * (0.1 + 0.8 * k)
	var cy := g.SURF - sin(k * PI) * g.SURF * 0.7 + 4.0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d := Vector2(dx, dy).length()
			var x := D.jr(cx) + dx
			var y := D.jr(cy) + dy
			if d <= 3.6 and _sky_ok(x, y):
				var shade := Vector2(dx + 1.6, dy - 0.5).length() < 3.0
				draw_rect(Rect2(x, y, 1, 1), Color(0.95, 0.95, 0.88, a) if not shade else Color(0.8, 0.82, 0.8, a * 0.9))
			elif d <= 5.5 and _sky_ok(x, y):
				draw_rect(Rect2(x, y, 1, 1), Color(0.9, 0.9, 1.0, a * 0.07))


func _aurora(a: float) -> void:
	var W := g.W
	var T := g.T
	for x in range(0, W, 1):
		var base := g.SURF * (0.22 + 0.1 * sin(x * 0.03 + T * 0.15) + 0.06 * sin(x * 0.011 - T * 0.08))
		var hh := g.SURF * (0.2 + 0.12 * sin(x * 0.05 + T * 0.4))
		var inten := 0.5 + 0.5 * sin(x * 0.09 - T * 0.6) * sin(x * 0.023 + T * 0.2)
		if inten < 0.15:
			continue
		for j in int(hh):
			var y := D.jr(base) + j - int(hh * 0.3)
			if y < 0 or not _sky_ok(x, y):
				continue
			if (x + y) % 2 == 1 and j > hh * 0.5:
				continue
			var k := float(j) / hh
			var col := D.mix(Color("#5af0a0"), Color("#a070e8"), clampf(1.0 - k * 1.4, 0.0, 1.0))
			draw_rect(Rect2(x, y, 1, 1), Color(col, a * inten * 0.32 * (1.0 - absf(k - 0.6))))


func _lights(a: float) -> void:
	for p in g.backdrop.lights:
		var on := D.hash2(p.x, p.y, 7) < 0.8
		if on:
			draw_rect(Rect2(p.x, p.y, 1, 1), Color(1.0, 0.85, 0.45, a))
			draw_rect(Rect2(p.x, p.y + 1, 1, 1), Color(1.0, 0.85, 0.45, a * 0.25))


func _beacons(a: float) -> void:
	for p in g.backdrop.beacons:
		var on := sin(g.T * 2.0) > 0.0
		if on and a > 0.2:
			draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color(1.0, 0.95, 0.6, 0.25 * a))
			draw_rect(Rect2(p.x, p.y, 1, 1), Color(1.0, 0.95, 0.7, a))
			var dir := 1 if sin(g.T * 0.5) > 0 else -1
			for i in 16:
				draw_rect(Rect2(p.x + dir * (2 + i * 2), p.y, 2, 1), Color(1.0, 0.95, 0.7, a * 0.18 * (1.0 - i / 16.0)))
		elif a <= 0.2:
			draw_rect(Rect2(p.x, p.y, 1, 1), Color(0.9, 0.3, 0.2, 0.8) if int(g.T) % 2 == 0 else Color(0, 0, 0, 0))


func _glow_eyes(a: float) -> void:
	for f in g.fish:
		var A: Dictionary = Species.ALL[f.sp]
		var m := Sprites.mask(f.sp, f.sz)
		if A.get("glow_eye", false):
			var ex: float = f.x + (m.ex - m.bx + 0.5) * f.face
			var ey: float = f.y + (m.ey - m.by)
			draw_rect(Rect2(floori(ex), floori(ey) + 1, 1, 1), Color(A.pal.get("e", "#ffe080"), a))
		if A.body.get("lure", false) and m.lx >= 0:
			var px: float = f.x + (m.lx - m.bx + 0.5) * f.face
			var py: float = f.y + (m.ly - m.by)
			var pulse := 0.75 + 0.25 * sin(g.T * 3.0 + f.ph)
			draw_rect(Rect2(floori(px) - 2, floori(py), 5, 3), Color(1, 0.95, 0.6, 0.12 * pulse * a))
			draw_rect(Rect2(floori(px), floori(py) + 1, 1, 1), Color("#fffbe0"))


func _markers() -> void:
	if g.phase != "sink":
		return
	var f = g.fish_by_id(g.lure.eng)
	if f == null:
		return
	var x := D.jr(g.lure.x)
	var y := D.jr(g.lure.y) - 9
	if f.st == "nibble":
		_icon(QUERY, x - 1, y, Color("#c8d4ff"))
	elif f.st == "bite":
		var c := Color("#ffd34e") if int(g.T * 10.0) % 2 == 0 else Color("#ff7a5a")
		_icon(BANG, x, y - 2, c)
		_icon(BANG, x + 2, y - 2, c)


func _aim() -> void:
	if g.phase != "aim":
		return
	var p0 := g.tip
	var range_k := g.gear_stat("rod", "cast")
	var tx := g.landing.x + 6.0 + g.power * range_k * (g.W - g.landing.x - 18.0)
	if g.place.platform == "icehole":
		tx = g.hole_x
	var peak := 16.0 + 28.0 * g.power
	var n := 22
	for i in n:
		if (i + int(g.T * 12.0)) % 3 != 0:
			continue
		var k := float(i) / (n - 1)
		var x := lerpf(p0.x, tx, k)
		var y := lerpf(p0.y, float(g.SURF), k) - sin(k * PI) * peak
		draw_rect(Rect2(D.jr(x), D.jr(y), 1, 1), Color(1, 1, 1, 0.75))
	var c := Color("#ffd34e")
	draw_rect(Rect2(D.jr(tx) - 2, g.SURF - 1, 5, 1), c)
	draw_rect(Rect2(D.jr(tx), g.SURF - 3, 1, 5), c)


func _text(s: String, x: int, y: int, col: Color, alpha := 1.0) -> void:
	var sh := Color(SHADOW, alpha)
	for ch in s:
		var b: String = DIG.get(ch, "")
		if b != "":
			for i in 15:
				if b[i] == "1":
					draw_rect(Rect2(x + i % 3, y + i / 3 + 1, 1, 1), sh)
			for i in 15:
				if b[i] == "1":
					draw_rect(Rect2(x + i % 3, y + i / 3, 1, 1), col)
		x += 4


func _icon(rows: Array, x: int, y: int, col: Color) -> void:
	for j in rows.size():
		var r: String = rows[j]
		for i in r.length():
			if r[i] == "1":
				draw_rect(Rect2(x + i + 1, y + j, 1, 1), SHADOW)
				draw_rect(Rect2(x + i, y + j + 1, 1, 1), SHADOW)
	for j in rows.size():
		var r: String = rows[j]
		for i in r.length():
			if r[i] == "1":
				draw_rect(Rect2(x + i, y + j, 1, 1), col)
