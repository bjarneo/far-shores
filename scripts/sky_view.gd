class_name SkyView
extends Node2D
## Draws the sky layer: the sun, clouds, the backdrop, birds and life on the far horizon.

var g: Game


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if g == null or g.S.is_empty() or g.backdrop.is_empty():
		return
	var W := g.W
	var SURF := g.SURF
	var h := g.local_hours()
	if h > 5.0 and h < 19.6 and g.S.wx != "rain" and g.S.wx != "fog":
		var k := (h - 5.4) / 13.8
		var sx := W * (0.08 + 0.84 * k)
		var sy := SURF - sin(k * PI) * SURF * 0.78 + 3.0
		var low := 1.0 - sin(k * PI)
		var core := D.mix(Color("#fff6d0"), Color("#ffb068"), clampf(low * 1.4, 0.0, 1.0))
		_disc(sx, sy, 6.5, Color(core, 0.18))
		_disc(sx, sy, 4.5, core)
	for c in g.clouds:
		draw_texture(c.img, Vector2(D.jr(c.x), D.jr(c.y)), Color(1, 1, 1, 0.92))
	draw_texture(g.backdrop.tex, Vector2.ZERO)
	_horizon_life()
	var kind: String = g.place.get("birds", "gull")
	for b in g.birds:
		var fr := int(g.T * 5.0 + b.ph) % 2
		var tex := Sprites.bird_tex(kind, fr)
		draw_texture(tex, Vector2(D.jr(b.x) - tex.get_width() / 2, D.jr(b.y)))


func _disc(cx: float, cy: float, r: float, c: Color) -> void:
	var ir := ceili(r)
	for dy in range(-ir, ir + 1):
		var hw := floori(sqrt(maxf(0.0, r * r - dy * dy)))
		draw_rect(Rect2(D.jr(cx) - hw, D.jr(cy) + dy, hw * 2 + 1, 1), c)


func _horizon_life() -> void:
	var SURF := g.SURF
	for a in g.amb:
		var x := D.jr(a.x)
		var k: float = a.t / a.dur if a.dur < 900 else 0.0
		match a.k:
			"whale":
				var up := sin(clampf(k, 0.0, 1.0) * PI)
				var hh := D.jr(up * 6.0)
				var c := Color("#2a3440")
				if hh > 0:
					draw_rect(Rect2(x, SURF - hh, 1, hh), c)
					if hh >= 4:
						draw_rect(Rect2(x - 3, SURF - hh - 1, 3, 1), c)
						draw_rect(Rect2(x + 1, SURF - hh - 1, 3, 1), c)
						draw_rect(Rect2(x - 4, SURF - hh - 2, 2, 1), c)
						draw_rect(Rect2(x + 3, SURF - hh - 2, 2, 1), c)
				if k < 0.25:
					draw_rect(Rect2(x - 1, SURF - 6 - D.jr(k * 12.0), 1, 2), Color(1, 1, 1, 0.6))
			"dolphin", "boto":
				var c := Color("#5a6a78") if a.k == "dolphin" else Color("#e8a0b0")
				var px := x + D.jr((k - 0.5) * 14.0 * a.dir)
				var py := SURF - D.jr(sin(clampf(k, 0.0, 1.0) * PI) * 5.0)
				draw_rect(Rect2(px - 2, py, 5, 1), c)
				draw_rect(Rect2(px - 1, py - 1, 2, 1), c)
			"seal", "sealion":
				var bobv := D.jr(sin(a.t * 3.0))
				draw_rect(Rect2(x, SURF - 2 + bobv, 2, 2), Color("#3a3430"))
				draw_rect(Rect2(x + (2 if a.dir > 0 else -1), SURF - 2 + bobv, 1, 1), Color("#3a3430"))
			"ship":
				var dir: int = a.dir
				draw_rect(Rect2(x - 9, SURF - 3, 18, 2), Color("#1e1e24"))
				draw_rect(Rect2(x - 8, SURF - 1, 16, 1), Color("#a82a24"))
				draw_rect(Rect2(x - 6, SURF - 6, 10, 3), Color("#f0f0ec"))
				draw_rect(Rect2(x - 2 + dir, SURF - 9, 3, 3), Color("#1e1e24"))
				draw_rect(Rect2(x - 2 + dir, SURF - 9, 3, 1), Color("#a82a24"))
			"sail":
				draw_rect(Rect2(x - 3, SURF - 1, 7, 1), Color("#f0f0ec"))
				draw_rect(Rect2(x - 2, SURF - 2, 5, 1), Color("#2a3a5a"))
				for j in 6:
					draw_rect(Rect2(x - j / 2, SURF - 3 - (5 - j), j / 2 + 1, 1), Color("#f8f8f4"))
				draw_rect(Rect2(x + 1, SURF - 9, 1, 7), Color("#5a4a3a"))
			"felucca":
				draw_rect(Rect2(x - 4, SURF - 2, 9, 2), Color("#6a4a2a"))
				for j in 8:
					draw_rect(Rect2(x - 3 + j / 2, SURF - 3 - j, 4 - j / 3, 1), Color("#f4eee0"))
			"longtail":
				draw_rect(Rect2(x - 7, SURF - 2, 14, 2), Color("#8a5a2e"))
				draw_rect(Rect2(x + (6 if a.dir > 0 else -7), SURF - 4, 1, 2), Color("#e8c040"))
				draw_rect(Rect2(x - 2, SURF - 5, 1, 3), Color("#2a2a2a"))
				if int(g.T * 10.0) % 2 == 0:
					draw_rect(Rect2(x - 8 * a.dir, SURF - 1, 2, 1), Color(1, 1, 1, 0.7))
			"raft":
				draw_rect(Rect2(x - 5, SURF - 1, 10, 1), Color("#c8b070"))
				draw_rect(Rect2(x - 1, SURF - 5, 2, 4), Color("#2a3a5a"))
				draw_rect(Rect2(x - 1, SURF - 6, 2, 1), Color("#d8c890"))
				draw_rect(Rect2(x + 2, SURF - 9, 1, 9), Color("#8a7a5a"))
				draw_rect(Rect2(x - 4, SURF - 3, 2, 2), Color("#1e1e22"))
			"loon", "ducks":
				var n := 1 if a.k == "loon" else 3
				for i in n:
					var dx: int = x - i * 6 * a.dir
					var c := Color("#1e1e22") if a.k == "loon" else Color("#6a5a3a")
					draw_rect(Rect2(dx - 2, SURF - 2, 5, 2), c)
					draw_rect(Rect2(dx + (2 if a.dir > 0 else -2), SURF - 4, 1, 2), c)
					if a.k == "ducks":
						draw_rect(Rect2(dx + (2 if a.dir > 0 else -2), SURF - 4, 1, 1), Color("#2a6a3a"))
					else:
						draw_rect(Rect2(dx - 1, SURF - 2, 1, 1), Color(1, 1, 1, 0.8))
			"nessie":
				var up := sin(clampf(k, 0.0, 1.0) * PI)
				var c := Color("#2a3028", 0.85)
				var hh := D.jr(up * 9.0)
				if hh > 0:
					draw_rect(Rect2(x, SURF - hh, 2, hh), c)
					draw_rect(Rect2(x - 2, SURF - hh, 3, 2), c)
					var hump := D.jr(up * 3.0)
					draw_rect(Rect2(x + 4, SURF - hump, 4, hump), c)
					draw_rect(Rect2(x + 10, SURF - D.jr(up * 2.0), 3, D.jr(up * 2.0)), c)
