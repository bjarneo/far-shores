class_name SceneView
extends Node2D
## Draws the water layer: reflections, light rays, seabed decor, fish, the line, the angler and the platform.

var g: Game

const LINE_AIR := Color(0.93, 0.93, 0.88, 0.85)
const LINE_WATER := Color(0.85, 0.9, 0.9, 0.42)
const BUBBLE_1 := Color(220 / 255.0, 244 / 255.0, 1.0, 0.75)
const BUBBLE_2 := Color(220 / 255.0, 244 / 255.0, 1.0, 0.55)
const WOOD := Color("#6a4a2e")
const WOOD_L := Color("#8a6440")
const WOOD_D := Color("#3e2a1a")


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if g == null or g.S.is_empty() or g.backdrop.is_empty():
		return
	var W := g.W
	var SURF := g.SURF
	var T := g.T
	var sk := g.sky()
	_reflection()
	# Light rays in daytime.
	if sk.light > 0.55 and g.place.get("murk", 0.0) < 0.5:
		var col := Color(1, 1, 1, 0.045 * (sk.light - 0.45))
		var span := float(g.BED - SURF)
		for i in ceili(W / 56.0):
			var x0 := fmod(i * 67 + T * 2.5, W + 70) - 60.0
			var w := 8.0 + i % 3 * 3
			draw_colored_polygon(PackedVector2Array([Vector2(x0, SURF + 1), Vector2(x0 + w, SURF + 1), Vector2(x0 + w + span * 0.4, g.BED), Vector2(x0 + span * 0.4, g.BED)]), col)
	for d in g.decor:
		if d.d < 0.5:
			_decor(d)
	_underwater_life()
	var murk: float = g.place.get("murk", 0.0)
	var wdeep := Color(g.place.water[1])
	var wtop := Color(g.place.water[0])
	for f in g.fish:
		if f.get("jump", -1.0) < 0.0:
			_fish(f, murk, wtop, wdeep)
	_line_water()
	for b in g.bubbles:
		var x := D.jr(b.x)
		var y := D.jr(b.y)
		if b.r == 1:
			draw_rect(Rect2(x, y, 1, 1), BUBBLE_1)
		else:
			draw_rect(Rect2(x, y - 1, 1, 1), BUBBLE_2)
			draw_rect(Rect2(x - 1, y, 3, 1), BUBBLE_2)
			draw_rect(Rect2(x, y + 1, 1, 1), BUBBLE_2)
	for d in g.decor:
		if d.d >= 0.5:
			_decor(d)
	_surface()
	_surface_plants()
	_penguins()
	var boat: bool = g.place.platform in ["boat", "skiff", "felucca", "longtail", "raft"]
	if not boat:
		_platform()
	_angler()
	if boat:
		_platform()
	_line_air()
	for f in g.fish:
		if f.get("jump", -1.0) >= 0.0:
			_jumper(f)
	if g.phase == "fight":
		var hf = g.fish_by_id(g.fight.get("id", -1))
		if hf != null and g.fight.get("jump", -1.0) >= 0.0:
			_fish(hf, 0.0, wtop, wdeep)
	_dangle()
	for s in g.splashes:
		draw_rect(Rect2(D.jr(s.x), D.jr(s.y), 1, 1), Color(0.9, 0.97, 1.0, 0.85))
	_weather()


# ---------- water ----------

func _reflection() -> void:
	var tex: Texture2D = g.backdrop.tex
	var SURF := g.SURF
	var rows := mini(30, int((g.BED - SURF) * 0.4))
	var water := Color(g.place.water[0])
	for r in rows:
		var src := SURF - 1 - r * 2
		if src < 0:
			break
		var off := D.jr(sin(r * 0.9 + g.T * 2.2) * minf(2.0, 0.4 + r * 0.12))
		var a := 0.3 * (1.0 - float(r) / rows)
		draw_texture_rect_region(tex, Rect2(off, SURF + r, g.W, 1), Rect2(0, src, g.W, 1), Color(D.mix(Color.WHITE, water, 0.4), a))
	var h := g.local_hours()
	if h > 5.5 and h < 19.0 and g.S.wx == "clear":
		var k := (h - 5.4) / 13.8
		var sx := g.W * (0.08 + 0.84 * k)
		for r in rows:
			if (r + int(g.T * 6.0)) % 3 == 0:
				var hw := 2 + r / 6
				draw_rect(Rect2(D.jr(sx + sin(r * 1.7 + g.T * 3.0) * hw) - 1, SURF + r, 2, 1), Color(1, 0.95, 0.8, 0.45 * (1.0 - float(r) / rows)))


func _surface() -> void:
	var W := g.W
	var SURF := g.SURF
	var T := g.T
	var c := D.light(Color(g.place.water[0]), 0.45)
	if g.place.platform == "icehole":
		_ice_sheet()
		return
	var run_x := 0
	var run_up := false
	for x in W + 1:
		var up := x < W and sin(x * 0.3 + T * 2.0) + sin(x * 0.11 - T * 1.3) > 0.5
		if x == 0:
			run_up = up
			continue
		if x == W or up != run_up:
			draw_rect(Rect2(run_x, SURF - 1 if run_up else SURF, x - run_x, 1), c)
			run_x = x
			run_up = up
	draw_rect(Rect2(0, SURF + 1, W, 1), Color(1, 1, 1, 0.12))
	for r in g.ripples:
		var k: float = r.t / 1.2
		var dx := D.jr(1.0 + k * 7.0)
		var col := Color(1, 1, 1, 0.7 * (1.0 - k))
		draw_rect(Rect2(D.jr(r.x) - dx, SURF - 1, 2, 1), col)
		draw_rect(Rect2(D.jr(r.x) + dx - 1, SURF - 1, 2, 1), col)


func _ice_sheet() -> void:
	var W := g.W
	var SURF := g.SURF
	var hx := g.hole_x
	var top := Color("#f4f8fc")
	var mid := Color("#d4e4f0")
	var under := Color("#a8c8e0")
	for x in W:
		if absi(x - hx) <= 3:
			continue
		draw_rect(Rect2(x, SURF - 3, 1, 1), top)
		draw_rect(Rect2(x, SURF - 2, 1, 3), mid if (x / 5) % 3 != 0 else top)
		var depth := 4 + (1 if D.hash2(x / 4, 0, 3) < 0.5 else 0)
		draw_rect(Rect2(x, SURF + 1, 1, depth), Color(under, 0.85))
	draw_rect(Rect2(hx - 3, SURF, 7, 1), Color("#1c4a6a"))


func _penguins() -> void:
	for a in g.amb:
		if a.k != "penguins":
			continue
		for i in a.n:
			var x: int = D.jr(a.x) + i * 7
			var step: int = int(a.t * 4.0 + i) % 2
			var y := g.SURF - 4
			if g.place.platform == "icehole" and absi(x - g.hole_x) < 6:
				continue
			draw_rect(Rect2(x, y - 7, 3, 7), Color("#1e2228"))
			draw_rect(Rect2(x + (0 if a.dir > 0 else 1), y - 5, 2, 4), Color("#f4f4f0"))
			draw_rect(Rect2(x + (2 if a.dir < 0 else -1) * 0, y - 8, 3, 2), Color("#1e2228"))
			draw_rect(Rect2(x + (-1 if a.dir < 0 else 3), y - 7, 1, 1), Color("#e8a030"))
			draw_rect(Rect2(x + (1 if a.dir < 0 else 1), y - 7, 1, 1), Color("#f4f4f0"))
			draw_rect(Rect2(x + step, y, 1, 1), Color("#e8a030"))
			draw_rect(Rect2(x + 2 - step, y, 1, 1), Color("#e8a030"))


func _surface_plants() -> void:
	var SURF := g.SURF
	for d in g.decor:
		var x := D.jr(d.x)
		match d.type:
			"lily":
				var w: int = 7 + d.seed % 5
				draw_rect(Rect2(x - w / 2, SURF - 1, w, 1), Color("#4a8a3a"))
				draw_rect(Rect2(x - w / 2 - 1, SURF - 2, 1, 1), Color("#6aaa4a"))
				draw_rect(Rect2(x + w - w / 2, SURF - 2, 1, 1), Color("#6aaa4a"))
				if d.seed % 3 == 0:
					draw_rect(Rect2(x, SURF - 3, 2, 2), Color("#f0e0ec"))
					draw_rect(Rect2(x, SURF - 3, 1, 1), Color("#e890b0"))
			"lotus":
				draw_rect(Rect2(x - 3, SURF - 1, 7, 1), Color("#3a7a3a"))
				if d.seed % 2 == 0:
					draw_rect(Rect2(x, SURF - 6, 1, 5), Color("#3a6a2a"))
					draw_rect(Rect2(x - 1, SURF - 8, 3, 2), Color("#f0a0c0"))
					draw_rect(Rect2(x, SURF - 9, 1, 1), Color("#f8d0e0"))


func _decor(d: Dictionary) -> void:
	var x := D.jr(d.x)
	var b := g.bed_at(d.x) + 1 + D.jr(d.d * 4.0)
	match d.type:
		"reed":
			if b - g.SURF < 46:
				Sprites.draw_plant(self, d.type, x, b, d.seed, d.flip, g.T, g.SURF + 4, g.SURF)
		"grass", "kelp", "anemone", "weed":
			Sprites.draw_plant(self, d.type, x, b, d.seed, d.flip, g.T, g.SURF + 4, g.SURF)
		"lily", "lotus":
			var stem := Color("#3a6a2a", 0.7)
			for y in range(g.SURF + 1, b, 2):
				draw_rect(Rect2(x + D.jr(sin(y * 0.2 + d.seed) * 1.0), y, 1, 1), stem)
		_:
			var tone := "dark" if g.place.bed.style == "rock" else ""
			var tex := Sprites.decor_tex(d.type, d.seed, tone)
			var w := tex.get_width()
			var y := b - tex.get_height() + 1
			if d.flip:
				draw_set_transform(Vector2(x, 0), 0.0, Vector2(-1, 1))
				draw_texture(tex, Vector2(-D.jr(w / 2.0), y))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture(tex, Vector2(D.jr(x - w / 2.0), y))


func _fish(f: Dictionary, murk: float, wtop: Color, wdeep: Color) -> void:
	var m := Sprites.mask(f.sp, f.sz)
	var fr: int = int(floor(f.anim)) % 4
	var tex := Sprites.fish_tex(f.sp, f.sz, fr)
	var pos := Vector2(D.jr(f.x), D.jr(f.y))
	draw_set_transform(pos, 0.0, Vector2(-1 if f.face < 0 else 1, 1))
	var o := Vector2(-D.jr(m.bx), -D.jr(m.by) - 1)
	draw_texture(tex, o)
	if murk > 0.0 and f.y > g.SURF:
		var k := clampf((f.y - g.SURF) / maxf(1.0, g.BED - g.SURF), 0.0, 1.0)
		var a := clampf(murk * (0.25 + k * 0.95), 0.0, 0.92)
		draw_texture(Sprites.fish_tex(f.sp, f.sz, fr, "white"), o, Color(D.mix(wtop, wdeep, k), a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _jumper(f: Dictionary) -> void:
	var k: float = f.jump
	var hs := g.fish_half(f)
	var y: float = g.SURF - sin(k * PI) * f.get("jh", 12.0)
	var x: float = f.jx0 + (k - 0.5) * hs.x * 2.0 * f.face
	var m := Sprites.mask(f.sp, f.sz)
	var tex := Sprites.fish_tex(f.sp, f.sz, int(g.T * 8.0) % 4)
	var rot: float = (0.5 - k) * 1.4 * f.face
	draw_set_transform(Vector2(D.jr(x), D.jr(y)), rot, Vector2(-1 if f.face < 0 else 1, 1))
	draw_texture(tex, Vector2(-D.jr(m.bx), -D.jr(m.by) - 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _underwater_life() -> void:
	for a in g.amb:
		match a.k:
			"turtle":
				var x := D.jr(a.x)
				var y := D.jr(a.y + sin(a.t * 0.8) * 3.0)
				var flap := int(a.t * 2.0) % 2
				var sh := Color("#5a6a2a")
				var sk := Color("#8aa04a")
				draw_rect(Rect2(x - 4, y - 2, 8, 4), sh)
				draw_rect(Rect2(x - 3, y - 3, 6, 1), sh)
				draw_rect(Rect2(x - 2, y - 1, 4, 1), Color("#7a8a3a"))
				draw_rect(Rect2(x + 4 * a.dir, y - 1, 2, 2), sk)
				draw_rect(Rect2(x + (1 if a.dir > 0 else -3), y + 2 + flap, 2, 1), sk)
				draw_rect(Rect2(x - (3 if a.dir > 0 else -1), y + 2 + (1 - flap), 2, 1), sk)
			"ice":
				var x := D.jr(a.x)
				var w: int = a.w
				var bobv := D.jr(sin(a.t * 1.4) * 0.6)
				draw_rect(Rect2(x, g.SURF - 2 + bobv, w, 2), Color("#f4f8fc"))
				draw_rect(Rect2(x - 1, g.SURF + bobv, w + 2, 5), Color("#b8d4ea", 0.85))
				draw_rect(Rect2(x + 1, g.SURF + 5 + bobv, w - 2, 2), Color("#9ac0de", 0.7))


# ---------- line, lure and rod ----------

func _lure_pos() -> Vector2:
	if g.lure.st == "rod":
		return g.tip + Vector2(0, 5 + sin(g.T * 2.0) * 0.5)
	var j: float = g.lure.jig
	return Vector2(g.lure.x + (sin(g.T * 40.0) * j * 2.0), g.lure.y + j * 2.0)


func _line_water() -> void:
	if g.lure.st != "water":
		return
	var lp := _lure_pos()
	var e := _entry(lp)
	var tense: float = g.fight.get("ten", 0.5) if g.phase == "fight" else 0.6
	_curve(e, lp, (1.0 - clampf(tense, 0.0, 1.0)) * 3.0, _line_col(LINE_WATER))
	if g.phase != "fight":
		_lure(lp)


func _line_air() -> void:
	var lp := _lure_pos()
	match g.lure.st:
		"rod":
			_curve(g.tip, lp, 0.0, LINE_AIR)
			_lure(lp)
		"air":
			_curve(g.tip, lp, 3.0, LINE_AIR)
			_lure(lp)
		"water":
			var e := _entry(lp)
			var tense: float = g.fight.get("ten", 0.4) if g.phase == "fight" else 0.35
			_curve(g.tip, e, (1.0 - clampf(tense, 0.0, 1.0)) * 7.0, _line_col(LINE_AIR))


func _line_col(c: Color) -> Color:
	if g.phase == "fight" and g.fight.get("strain", 0.0) > 0.05 and int(g.T * 10.0) % 2 == 0:
		return Color(1.0, 0.45, 0.4, c.a + 0.1)
	return c


func _entry(lp: Vector2) -> Vector2:
	var t := g.tip
	var sy := float(g.SURF)
	if g.place.platform == "icehole":
		return Vector2(g.hole_x, sy)
	if absf(lp.y - t.y) < 0.01:
		return lp
	var k := clampf((sy - t.y) / (lp.y - t.y), 0.0, 1.0)
	return Vector2(lerpf(t.x, lp.x, k), sy)


func _curve(a: Vector2, b: Vector2, sag: float, col: Color) -> void:
	var mid := (a + b) * 0.5 + Vector2(0, sag)
	var n := maxi(2, int(a.distance_to(b) * 1.4))
	var last := Vector2i(-999, -999)
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		var q := Vector2i(floori(p.x), floori(p.y))
		if q != last:
			draw_rect(Rect2(q.x, q.y, 1, 1), col)
			last = q


func _lure(p: Vector2) -> void:
	var x := D.jr(p.x)
	var y := D.jr(p.y)
	match g.S.bait:
		"worm":
			var w := int(g.T * 4.0) % 2
			draw_rect(Rect2(x - 1, y, 1, 1), Color("#e87890"))
			draw_rect(Rect2(x, y + 1 - w, 1, 1), Color("#e87890"))
			draw_rect(Rect2(x + 1, y + w, 1, 1), Color("#ffb0c0"))
		"shrimp":
			draw_rect(Rect2(x - 1, y, 2, 1), Color("#f08a4a"))
			draw_rect(Rect2(x + 1, y + 1, 1, 1), Color("#ffc890"))
		"spinner":
			var on := g.holding and int(g.T * 12.0) % 2 == 0
			draw_rect(Rect2(x, y - 1, 1, 2), Color("#ffffff") if on else Color("#c8d0d8"))
			draw_rect(Rect2(x, y + 1, 1, 1), Color("#e03a3a"))
		"jig":
			draw_rect(Rect2(x, y, 2, 2), Color("#8a8a92"))
			draw_rect(Rect2(x - 1, y + 1, 1, 1), Color("#e8c030"))
		"plug":
			draw_rect(Rect2(x - 2, y, 5, 2), Color("#e8402a"))
			draw_rect(Rect2(x, y, 1, 2), Color("#f4f0e8"))
	draw_rect(Rect2(x, y + 2, 1, 1), Color("#9aa0a8"))


func _rod() -> void:
	var dir := (g.tip - g.hand).normalized()
	var a := g.hand - dir * 5.0
	var b := g.tip
	var perp := Vector2(dir.y, -dir.x)
	var mid := (a + b) * 0.5 - perp * g.rod_bend * 3.5 + Vector2(0, g.rod_bend * 2.0)
	var n := int(a.distance_to(b) * 1.6)
	var last := Vector2i(-999, -999)
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		var q := Vector2i(floori(p.x), floori(p.y))
		if q == last:
			continue
		last = q
		var c: Color
		if t < 0.2:
			c = Color("#c89a62") if i % 3 != 0 else Color("#a87a48")
			draw_rect(Rect2(q.x, q.y + 1, 1, 1), Color("#8a6038"))
		elif t < 0.55:
			c = Color("#2a2e3a")
		elif t < 0.92:
			c = Color("#3e4658")
		else:
			c = Color("#e8e0c8")
		draw_rect(Rect2(q.x, q.y, 1, 1), c)
		if absf(t - 0.5) < 0.012 or absf(t - 0.7) < 0.012 or absf(t - 0.86) < 0.012:
			draw_rect(Rect2(q.x, q.y + 1, 1, 1), Color("#c8d0d8"))
	var rp := g.hand - dir * 1.5 + Vector2(-perp.x, -perp.y) * -2.5
	var rx := floori(rp.x)
	var ry := floori(rp.y)
	draw_rect(Rect2(rx - 1, ry - 1, 4, 4), Color("#1e2026"))
	draw_rect(Rect2(rx, ry, 2, 2), Color("#9aa0a8"))
	draw_rect(Rect2(rx, ry, 1, 1), Color("#dfe4ea"))
	if g.holding and (g.phase == "sink" or g.phase == "fight"):
		var k := int(g.T * 14.0) % 4
		var off: Vector2i = [Vector2i(2, 0), Vector2i(1, 2), Vector2i(-1, 1), Vector2i(0, -1)][k]
		draw_rect(Rect2(rx + off.x, ry + off.y, 1, 1), Color("#e8c040"))


func _angler() -> void:
	var blink := fmod(g.T, 4.3) < 0.12
	var tex := Sprites.angler_tex(g.place.climate, blink)
	var bobv := D.jr(g.bob)
	var ax := D.jr(g.angler.x) - 8
	var ay := D.jr(g.angler.y) - Sprites.ANGLER_H + bobv
	var lean := 0
	if g.phase == "fight" and g.fight.get("ten", 0.0) > 0.7:
		lean = -1
	draw_texture(tex, Vector2(ax + lean, ay))
	var outfit: Dictionary = Sprites.OUTFITS.get(g.place.climate, Sprites.OUTFITS.warm)
	var jl := Color(outfit.L)
	var jd := Color(outfit.J)
	var skin := Color(outfit.s)
	var skin_d := Color(outfit.S)
	var outline := Color(outfit.o)
	var sh := Vector2(ax + lean, ay) + Sprites.ANGLER_SHOULDER
	var hd := g.hand
	if g.holding and (g.phase == "sink" or g.phase == "fight"):
		hd += Vector2(0, D.jr(sin(g.T * 22.0)))
	var n := maxi(2, int(sh.distance_to(hd)))
	for i in n:
		var p := sh.lerp(hd, float(i) / n)
		draw_rect(Rect2(floori(p.x), floori(p.y) - 1, 1, 1), outline)
		draw_rect(Rect2(floori(p.x), floori(p.y), 1, 1), jl)
		draw_rect(Rect2(floori(p.x), floori(p.y) + 1, 1, 1), jd)
		draw_rect(Rect2(floori(p.x), floori(p.y) + 2, 1, 1), outline)
	_rod()
	var hx := floori(hd.x)
	var hy := floori(hd.y)
	draw_rect(Rect2(hx - 1, hy - 1, 3, 3), outline)
	draw_rect(Rect2(hx, hy, 2, 2), skin)
	draw_rect(Rect2(hx, hy + 1, 2, 1), skin_d)


func _dangle() -> void:
	if g.phase != "land" and g.phase != "show":
		return
	var dd := g.dangle()
	if dd.is_empty():
		return
	var c: Dictionary = g.catch_info
	var m := Sprites.mask(c.sp, c.sz)
	var tex := Sprites.fish_tex(c.sp, c.sz, dd.fr)
	_curve(g.tip, Vector2(dd.x, dd.y - m.rx), 0.0, LINE_AIR)
	draw_set_transform(Vector2(D.jr(dd.x), D.jr(dd.y)), dd.rot, Vector2.ONE)
	draw_texture(tex, Vector2(-D.jr(m.bx), -D.jr(m.by) - 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- platforms ----------

func _platform() -> void:
	var SURF := g.SURF
	var PX := g.PX
	var bobv := D.jr(g.bob)
	match g.place.platform:
		"pier":
			var top := SURF - 4
			for x in range(2, PX, 9):
				draw_rect(Rect2(x, top + 2, 2, g.bed_at(x) - top), WOOD_D)
			draw_rect(Rect2(0, top, PX, 2), WOOD)
			draw_rect(Rect2(0, top, PX, 1), WOOD_L)
			for x in range(0, PX, 5):
				draw_rect(Rect2(x, top + 1, 1, 1), WOOD_D)
			draw_rect(Rect2(PX - 3, top - 5, 2, 5), WOOD_D)
			if g.place.get("canoe", false):
				draw_rect(Rect2(PX - 30, SURF - 1, 16, 2), Color("#c83a2a"))
				draw_rect(Rect2(PX - 29, SURF + 1, 14, 1), Color("#8a2a1e"))
				draw_rect(Rect2(PX - 31, SURF - 2, 2, 1), Color("#c83a2a"))
				draw_rect(Rect2(PX - 15, SURF - 2, 2, 1), Color("#c83a2a"))
		"quay":
			var top := SURF - 4
			var water := Color(g.place.water[1])
			for x in PX:
				var bottom := g.bed_at(x) + 2
				for y in range(top, bottom):
					var row := (y - top) / 3
					var bx := (x + (3 if row % 2 == 1 else 0)) % 6
					var c := Color("#c8b894") if y == top else (Color("#a8987a") if (y - top) % 3 != 0 else Color("#7a6a54"))
					if bx == 5:
						c = Color("#6a5a44")
					draw_rect(Rect2(x, y, 1, 1), c if y < SURF else D.mix(c, water, 0.4))
		"rocks", "bank", "floe":
			_shore_mound()
		"boat", "skiff", "felucca", "longtail", "raft":
			_boat(g.place.platform, bobv)


func _shore_mound() -> void:
	var SURF := g.SURF
	var PX := g.PX
	var kind: String = g.place.platform
	var c1 := Color("#7a7468")
	var c2 := Color("#5a564c")
	var c3 := Color("#3e3c36")
	if kind == "bank":
		c1 = Color("#5a4a30")
		c2 = Color("#4a3c26")
		c3 = Color("#2e2416")
	elif kind == "floe":
		c1 = Color("#f4f8fc")
		c2 = Color("#d4e4f0")
		c3 = Color("#a8c8e0")
	for x in PX + 4:
		var top := SURF - 4 - D.jr(maxf(0.0, (PX - x) * 0.06)) + (1 if x > PX - 3 else 0)
		if kind == "rocks":
			top += D.jr((D.hash2(x / 3, 0, 9) - 0.5) * 2.0)
		var bottom := g.bed_at(x) + 2 if kind != "floe" else SURF + 6
		for y in range(top, bottom):
			var c := c1 if y < top + 1 else (c2 if D.hash2(x / 2, y / 2, 4) < 0.6 else c3)
			if y >= SURF:
				c = D.mix(c, Color(g.place.water[1]), 0.45 if kind != "floe" else 0.15)
			draw_rect(Rect2(x, y, 1, 1), c)
		if kind == "bank" and x % 4 == 0:
			draw_rect(Rect2(x, top - 2, 1, 2), Color("#4a7a2a"))
		if kind == "rocks" and x % 7 == 2:
			draw_rect(Rect2(x, top - 1, 1, 1), Color("#5a6a3a"))


func _boat(kind: String, bobv: int) -> void:
	var SURF := g.SURF
	var x0 := 6
	var x1 := g.PX + 2
	var y := SURF - 3 + bobv
	var hull := Color("#f0f0ec")
	var hull2 := Color("#2a5a9a")
	match kind:
		"skiff":
			hull = Color("#e8e4d8")
			hull2 = Color("#3a8a8a")
		"felucca":
			hull = Color("#6a4a2a")
			hull2 = Color("#3a2a18")
		"longtail":
			hull = Color("#8a5a2e")
			hull2 = Color("#e8c040")
		"raft":
			for x in range(x0, x1):
				draw_rect(Rect2(x, y + 2, 1, 2), Color("#c8b070") if x % 3 != 0 else Color("#9a8650"))
			draw_rect(Rect2(x0, y + 4, x1 - x0, 1), Color("#6a5a3a", 0.6))
			draw_rect(Rect2(x1 - 2, y - 14, 1, 18), Color("#8a7a5a"))
			draw_rect(Rect2(x0 + 4, y - 2, 4, 4), Color("#1e1e22"))
			draw_rect(Rect2(x0 + 7, y - 4, 1, 2), Color("#e8c040"))
			return
	for x in range(x0, x1):
		var k := float(x - x0) / (x1 - x0)
		var depth := 4 if k > 0.08 and k < 0.92 else 2
		draw_rect(Rect2(x, y, 1, 1), D.dark(hull, 0.15))
		draw_rect(Rect2(x, y + 1, 1, depth - 1), hull)
		draw_rect(Rect2(x, y + depth, 1, 1), hull2)
	draw_rect(Rect2(x1, y - 1, 2, 1), D.dark(hull, 0.15))
	draw_rect(Rect2(x0 - 1, y - 1, 2, 1), D.dark(hull, 0.15))
	match kind:
		"boat":
			draw_rect(Rect2(x0 + 2, y - 7, 9, 7), Color("#e8e8e4"))
			draw_rect(Rect2(x0 + 3, y - 6, 3, 2), Color("#4a6a8a"))
			draw_rect(Rect2(x0 + 7, y - 6, 3, 2), Color("#4a6a8a"))
			draw_rect(Rect2(x0 + 1, y - 8, 11, 1), Color("#2a5a9a"))
			draw_rect(Rect2(x0 + 6, y - 14, 1, 6), Color("#5a5a60"))
		"skiff":
			draw_rect(Rect2(x0 + 1, y - 8, 1, 8), Color("#8a9098"))
			draw_rect(Rect2(x0 - 1, y - 9, 5, 1), Color("#8a9098"))
			draw_rect(Rect2(x0 + 1, y - 2, 4, 2), Color("#2a2a2e"))
		"felucca":
			draw_rect(Rect2(x0 + 8, y - 34, 1, 34), Color("#4a3420"))
			for j in 30:
				var w := D.jr(j * 0.55)
				draw_rect(Rect2(x0 + 9 + j * 0.15, y - 33 + j, maxi(1, w), 1), Color("#f4eee0") if j % 6 != 0 else Color("#d8d0bc"))
			draw_rect(Rect2(x0 - 4, y - 18, 30, 1), Color("#4a3420"))
		"longtail":
			draw_rect(Rect2(x0 - 6, y - 3, 8, 1), Color("#5a5a60"))
			draw_rect(Rect2(x0 - 1, y - 6, 4, 4), Color("#3a3a3e"))
			draw_rect(Rect2(x1 - 2, y - 3, 2, 3), Color("#e8c040"))
			draw_rect(Rect2(x1 - 1, y - 5, 1, 2), Color("#d83a2a"))


# ---------- weather ----------

func _weather() -> void:
	var wx: String = g.S.wx
	if wx == "rain":
		var c := Color(0.8, 0.86, 0.95, 0.5)
		for d in g.drops:
			draw_rect(Rect2(D.jr(d.x), D.jr(d.y), 1, 2), c)
	elif wx == "snow":
		for d in g.drops:
			draw_rect(Rect2(D.jr(d.x), D.jr(d.y), 1, 1), Color(1, 1, 1, 0.9))
	elif wx == "fog":
		var W := g.W
		var SURF := g.SURF
		var span := int(SURF * 0.6)
		for r in range(-span, 10):
			var y := SURF + r
			var k := 1.0 - absf(float(r + 4)) / span
			if k <= 0.0:
				continue
			var base := 0.26 * k * k
			for x in range(0, W, 3):
				var a := base * (0.7 + 0.3 * sin(x * 0.045 + g.T * 0.25 + r * 0.21) * sin(x * 0.017 - g.T * 0.1))
				if (x / 3 + y) % 2 == 0:
					a *= 0.85
				draw_rect(Rect2(x, y, 3, 1), Color(0.88, 0.9, 0.93, a))
