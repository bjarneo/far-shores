class_name Game
extends Node
## The fishing simulation: time, weather, fish, the cast, the bite, the fight, the economy and saving.

signal changed
signal toast(text: String, kind: String)
signal world_resized
signal landed(info: Dictionary)
signal place_changed

# Scene layout in scene pixels.
var W := 320
var H := 200
var SURF := 84
var BED := 176
var bed := PackedInt32Array()
var PX := 48
var angler := Vector2(36, 80)
var landing := Vector2(52, 86)
var hole_x := 0

# Screen. view_size and the insets are in UI pixels.
var view_size := Vector2(1280, 800)
var inset_top := 0.0
var inset_bottom := 0.0
var px_scale := 4.0
## Screen pixels per UI pixel. Main sets it from the device pixel ratio.
var ui_scale := 1.0

var loc := "lofoten"
var place: Dictionary = {}
var backdrop := {}
var S := {}
var T := 0.0
var synth: Synth

var fish: Array = []
var decor: Array = []
var lure := {"st": "rod", "x": 0.0, "y": 0.0, "t": 0.0, "eng": -1, "jig": 0.0, "rest": false}
var phase := "idle"
var holding := false
var power := 0.0
var aim_t := 0.0
var fight := {}
var catch_info := {}
var land_t := 0.0
var rod_ang := -1.05
var rod_bend := 0.0
var tip := Vector2.ZERO
var hand := Vector2.ZERO
var bob := 0.0

var bubbles: Array = []
var splashes: Array = []
var ripples: Array = []
var pops: Array = []
var drops: Array = []
var clouds: Array = []
var birds: Array = []
var amb: Array = []
var hover := Vector2(-99, -99)
var hover_until := 0.0
var msg := ""
var msg_t := 0.0
var flash := 0.0

var _next_id := 1
var _spawn_t := 0.0
var _bird_t := 4.0
var _amb_t := 6.0
var _save_t := 0.0
var _sec_t := 0.0
var _emit_t := 0.0
var _tick_acc := 0.0
var _creak_t := 0.0
var _legend_hint := false

const FISH_MAX := 13


# ---------- setup ----------

func start(view: Vector2, top_inset: float, bottom_inset: float) -> void:
	view_size = view
	inset_top = top_inset
	inset_bottom = bottom_inset
	_load_settings()
	var loaded := _load()
	S = loaded if not loaded.is_empty() else _fresh_state()
	loc = S.loc
	place = Places.get_place(loc)
	_layout(true)
	_new_weather(true)
	_populate()
	synth.warm(place.music)
	_emit()


func _fresh_state() -> Dictionary:
	return {"v": 1, "coins": 40, "total": 0, "utc": 6.4, "day": 1, "loc": "lofoten", "unlocked": {"lofoten": true}, "visited": {"lofoten": true},
		"gear": {"rod": 0, "reel": 0, "line": 0}, "baits": {"worm": true}, "bait": "worm", "book": {}, "ach": {},
		"stats": {"casts": 0, "caught": 0, "sold": 0, "released": 0, "snaps": 0, "lost": 0, "legend": 0, "night": 0, "dawn": 0, "rain": 0, "record": 0, "heavy": 0},
		"tut": 0, "wx": "clear", "wx_t": 0.0}


func set_view(view: Vector2, top_inset: float, bottom_inset: float, scale := 1.0) -> void:
	if view.is_equal_approx(view_size) and absf(top_inset - inset_top) < 1.0 and absf(bottom_inset - inset_bottom) < 1.0 and absf(scale - ui_scale) < 0.001:
		return
	ui_scale = scale
	view_size = view
	inset_top = top_inset
	inset_bottom = bottom_inset
	_layout(false)


func _layout(force: bool) -> void:
	var cw := maxf(view_size.x, 200.0)
	var ch := maxf(view_size.y, 200.0)
	var sc := maxf(2.0, roundf(minf(cw, ch) / 250.0))
	# One scene pixel covers a whole number of screen pixels, so the pixel art stays sharp
	# when the device pixel ratio is not a whole number. The scene can be up to one pixel
	# larger than the screen at the right and bottom edges.
	var fs := maxf(1.0, roundf(sc * ui_scale)) / ui_scale
	var nW := maxi(160, ceili(cw / fs))
	var nH := maxi(140, ceili(ch / fs))
	var top_px := inset_top / fs
	var bot_px := inset_bottom / fs
	var nSURF := clampi(D.jr(nH * 0.42), 56, D.jr(nW * 0.5 + 40))
	nSURF = maxi(nSURF, ceili(top_px) + 42)
	var nBED := nH - maxi(12, ceili(bot_px) + 6)
	nBED = maxi(nBED, nSURF + 54)
	if not force and nW == W and nH == H and nSURF == SURF and nBED == BED:
		return
	var old_w := W
	var old_surf := SURF
	W = nW
	H = nH
	SURF = nSURF
	BED = nBED
	px_scale = fs
	_build_place()
	if old_w != W or old_surf != SURF:
		for f in fish:
			f.x = clampf(f.x * W / maxf(1.0, old_w), -20, W + 20)
			f.y = clampf(f.y, SURF + 4, bed_at(f.x) - 3)
			f.tx = f.x
			f.ty = f.y
	if phase != "show" and phase != "land":
		_reset_line()
	world_resized.emit()


func _build_place() -> void:
	var plat: String = place.platform
	PX = clampi(D.jr(W * 0.15), 36, 70)
	var depth_k: float = place.get("shallow", 1.0)
	var base := lerpf(SURF + 30, BED, depth_k)
	bed.resize(W)
	var seed_v: int = hash(loc) & 0xFF
	var shore := plat in ["pier", "quay", "rocks", "bank", "floe"]
	var steep := plat != "pier"
	for x in W:
		var y := base + sin(x * 0.05 + seed_v) * 2.0 + sin(x * 0.13 + seed_v * 0.3) * 1.2 + (D.noise1(x * 0.08, seed_v) - 0.5) * 4.0
		if shore and steep:
			var k := clampf((x - PX - 3.0) / 55.0, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			y = lerpf(SURF + 4.0, y, k)
		elif shore:
			var k := clampf(float(x) / (PX + 34.0), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			y = lerpf(SURF + 10.0, y, k)
		bed[x] = D.jr(y)
	match plat:
		"boat", "skiff", "felucca", "longtail", "raft":
			angler = Vector2(PX - 16, SURF - 1)
			landing = Vector2(PX + 6, SURF + 2)
		"icehole":
			hole_x = PX + 16
			angler = Vector2(hole_x - 16, SURF - 3)
			landing = Vector2(hole_x, SURF + 6)
		_:
			angler = Vector2(PX - 12, SURF - 4)
			landing = Vector2(PX + 4, SURF + 2)
	backdrop = Scenery.build(place, W, SURF)
	_build_decor()
	_make_clouds()


func _build_decor() -> void:
	decor.clear()
	var r := D.Rng.new(hash(loc) & 0xFFFFF)
	var x0 := PX + 10
	if place.platform == "icehole":
		x0 = 8
	for it in place.decor:
		var type: String = it[0]
		var n: int = it[1]
		if W < 240:
			n = maxi(1, D.jr(n * 0.7))
		for i in n:
			var x := r.range_f(x0, W - 6)
			if type == "reed":
				x = r.range_f(PX + 4, PX + 50) if r.next() < 0.6 else r.range_f(W - 40, W - 4)
			decor.append({"type": type, "x": float(D.jr(x)), "seed": r.range_i(1, 9999), "flip": r.next() < 0.5, "d": r.next()})
	decor.sort_custom(func(a, b): return a.d < b.d)


func _make_clouds() -> void:
	clouds.clear()
	var n: int = D.WEATHER[S.get("wx", "clear")].clouds if not S.is_empty() else 2
	for i in n:
		clouds.append(_new_cloud(randf_range(-30, W)))


func _new_cloud(x: float) -> Dictionary:
	var big := randf() < 0.5
	return {"x": x, "y": randf_range(6, SURF * 0.55), "v": randf_range(1.5, 4.0), "img": _cloud_tex(randi() % 9999, big)}


func _cloud_tex(seed_value: int, big: bool) -> ImageTexture:
	var r := D.Rng.new(seed_value)
	var w := r.range_i(18, 34) if big else r.range_i(10, 18)
	var h := w / 3 + 3
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var puffs := []
	for i in r.range_i(3, 5):
		puffs.append(Vector3(r.range_f(h * 0.5, w - h * 0.5), h - r.range_f(h * 0.35, h * 0.6), r.range_f(h * 0.35, h * 0.55)))
	var dark: bool = S.get("wx", "clear") in ["rain", "snow"]
	var top_c := Color("#f6f8fb") if not dark else Color("#b8c0cc")
	var bot_c := Color("#c8d4e4") if not dark else Color("#8a94a4")
	for y in h:
		for x in w:
			var inside := y >= h - 2 and x > 2 and x < w - 3
			var lit := false
			for p in puffs:
				var d := Vector2(x + 0.5 - p.x, y + 0.5 - p.y)
				if d.length() <= p.z:
					inside = true
					if d.y < -p.z * 0.25:
						lit = true
			if inside:
				img.set_pixel(x, y, top_c if lit or y < h * 0.45 else bot_c)
	return ImageTexture.create_from_image(img)


func bed_at(x: float) -> int:
	return bed[clampi(int(x), 0, W - 1)]


## Water top for the fish at x. Under the ice sheet the fish stay below the ice.
func water_top(x: float) -> float:
	if place.platform == "icehole":
		return SURF + 6.0
	return SURF + 2.0


# ---------- state helpers ----------

func gear_stat(kind: String, key: String) -> float:
	return D.GEAR[kind][S.gear[kind]][key]


func reel_px() -> float:
	return W * gear_stat("reel", "speed")


func local_hours() -> float:
	return D.local_hours(S.utc, place.tz)


func sky() -> Dictionary:
	var s := D.sky_at(local_hours())
	var wl: float = D.WEATHER[S.wx].light
	s.light *= wl
	if wl < 1.0:
		s.tint = D.mix(s.tint, D.mix(s.tint, Color("#9aa4b4"), 0.5), (1.0 - wl) * 2.0)
	return s


func is_night() -> bool:
	return D.phase_of(local_hours()) == "Night"


func _id() -> int:
	_next_id += 1
	return _next_id


func book_has(sp: String) -> bool:
	return S.book.has(sp)


# ---------- weather ----------

func _new_weather(force: bool) -> void:
	if not force and S.wx_t > 0.0:
		return
	var ws: Dictionary = place.weather
	var tot := 0.0
	for k in ws:
		tot += ws[k]
	var r := randf() * tot
	var pick := "clear"
	for k in ws:
		r -= ws[k]
		if r <= 0.0:
			pick = k
			break
	if not ws.has(S.get("wx", "")) or not force or S.wx != pick:
		S.wx = pick
	S.wx_t = randf_range(90.0, 200.0)
	drops.clear()
	_make_clouds()


# ---------- fish ----------

func _populate() -> void:
	fish.clear()
	for i in _fish_target():
		_spawn(true)


func _fish_target() -> int:
	var area := W * (BED - SURF)
	return clampi(D.jr(area / 2600.0), 6, FISH_MAX)


func _spawn(inside: bool) -> void:
	var pool := Species.of_place(loc)
	var h := local_hours()
	var wsum := 0.0
	var ws := []
	var has_legend := false
	for f in fish:
		if Species.ALL[f.sp].r == 3:
			has_legend = true
	for k in pool:
		var A: Dictionary = Species.ALL[k]
		var w: float = D.RARITY[A.r].w * D.time_factor(A.time, h)
		if A.r == 3 and has_legend:
			w = 0.0
		ws.append(w)
		wsum += w
	var r := randf() * wsum
	var sp: String = pool[0]
	for i in pool.size():
		r -= ws[i]
		if r <= 0.0:
			sp = pool[i]
			break
	var A: Dictionary = Species.ALL[sp]
	var n := 1
	if A.get("school", false):
		n = randi_range(3, 5)
	var side := -1 if randf() < 0.5 else 1
	var x0 := randf_range(PX + 20, W - 20) if inside else (-24.0 if side < 0 else W + 24.0)
	var d0 := randf_range(A.depth[0], A.depth[1])
	for i in n:
		if fish.size() >= FISH_MAX + 4:
			break
		var wk := pow(randf(), 1.9)
		var w: float = lerpf(A.w[0], A.w[1], wk)
		var sz := 0 if wk < 0.18 else (1 if wk < 0.5 else (2 if wk < 0.82 else 3))
		var x := x0 + randf_range(-10, 10) - side * i * 8
		var f := {"id": _id(), "sp": sp, "sz": sz, "w": w, "wk": wk, "x": x, "y": 0.0, "vx": 0.0, "vy": 0.0, "face": -side if not inside else (1 if randf() < 0.5 else -1),
			"tx": x, "ty": 0.0, "wt": 0.0, "st": "swim", "t": 0.0, "anim": randf() * 4.0, "ph": randf() * 6.0,
			"life": randf_range(40, 110), "cool": randf_range(0.0, 3.0), "nib": 0, "d0": clampf(d0 + randf_range(-0.06, 0.06), 0.0, 1.0), "jump": -1.0}
		f.y = _depth_y(f, f.d0)
		f.ty = f.y
		fish.append(f)
		if A.r == 3 and not inside and not _legend_hint:
			_legend_hint = true
			toast.emit("Something huge moves in the deep water...", "legend")


func fish_half(f: Dictionary) -> Vector2:
	var m := Sprites.mask(f.sp, f.sz)
	return Vector2(m.rx + 2.0, m.ry + 1.0)


func _depth_y(f: Dictionary, d: float) -> float:
	var hh := fish_half(f).y
	var top := water_top(f.x) + hh + 1.0
	var bot := bed_at(f.x) - hh - 1.0
	if bot < top:
		return top
	return lerpf(top, bot, d)


func _band(f: Dictionary) -> Vector2:
	var A: Dictionary = Species.ALL[f.sp]
	return Vector2(_depth_y(f, A.depth[0]), _depth_y(f, A.depth[1]))


## The mouth of a fish in scene pixels.
func mouth_of(f: Dictionary) -> Vector2:
	var m := Sprites.mask(f.sp, f.sz)
	var off: float = m.mx - m.bx
	return Vector2(f.x + off * f.face, f.y + (m.my - m.by) + 1.0)


func fish_by_id(id: int):
	for f in fish:
		if f.id == id:
			return f
	return null


func _update_fish(dt: float) -> void:
	var lure_in: bool = lure.st == "water"
	var night := is_night()
	for i in range(fish.size() - 1, -1, -1):
		var f: Dictionary = fish[i]
		if f.st == "hooked":
			continue
		var A: Dictionary = Species.ALL[f.sp]
		var B: Dictionary = A.body
		var hs := fish_half(f)
		f.life -= dt
		f.cool = maxf(0.0, f.cool - dt)
		var spd: float = (5.0 + B.rx * 0.45) * (0.7 if night and A.time != "night" else 1.0)
		match f.st:
			"swim":
				if f.life <= 0.0:
					f.st = "leave"
					f.tx = -40.0 if f.x < W * 0.5 else W + 40.0
				f.wt -= dt
				if f.wt <= 0.0 or Vector2(f.tx - f.x, f.ty - f.y).length() < 4.0:
					f.wt = randf_range(3, 9)
					f.tx = randf_range(PX + 6, W - 10)
					var band := _band(f)
					f.ty = randf_range(band.x, band.y)
				if lure_in and lure.eng < 0 and f.cool <= 0.0 and phase == "sink":
					_notice(f, dt)
			"leave":
				spd *= 1.2
				f.ty = clampf(f.y, SURF + hs.y + 2, bed_at(f.x) - hs.y - 1)
				if f.x < -36.0 or f.x > W + 36.0:
					fish.remove_at(i)
					continue
			"look":
				if not lure_in or lure.eng != f.id:
					_drop_interest(f)
				else:
					var m := mouth_of(f)
					var to := Vector2(lure.x, lure.y) - m
					f.tx = f.x + to.x
					f.ty = f.y + to.y
					spd *= 1.25
					f.t += dt
					if absf(to.x) > 1.5:
						f.face = 1 if to.x > 0.0 else -1
					if to.length() < 3.0 + hs.y * 0.35:
						f.st = "nibble"
						var hunter: bool = ("spinner" in A.bait) or ("plug" in A.bait)
						f.nib = randi_range(0, 1) if hunter else randi_range(1, 3)
						f.t = randf_range(0.5, 1.0) if f.nib > 0 else 0.25
						if f.nib > 0:
							_nibble_fx()
					elif to.length() > _sight(f) * 1.7 or f.t > 8.0:
						_drop_interest(f)
					elif holding and not ("spinner" in A.bait) and randf() < dt * 0.35:
						_drop_interest(f)
			"nibble", "bite":
				if not lure_in or lure.eng != f.id:
					_drop_interest(f)
				else:
					var m := mouth_of(f)
					var jitter := sin(T * 18.0 + f.ph) * 0.6 if f.st == "nibble" else 0.0
					f.x += (lure.x - m.x) + jitter
					f.y += (lure.y - m.y)
					f.vx = 0.0
					f.vy = 0.0
					f.t -= dt
					if f.st == "nibble" and f.t <= 0.0:
						f.nib -= 1
						if f.nib <= 0:
							f.st = "bite"
							f.t = 0.62 + gear_stat("rod", "hook") + (0.1 if A.r >= 2 else 0.0)
							lure.jig = 0.5
							flash = 0.5
							synth.bite()
							if S.tut < 2:
								S.tut = 2
						else:
							f.t = randf_range(0.5, 1.1)
							_nibble_fx()
					elif f.st == "bite" and f.t <= 0.0:
						_lost_bait(f)
					f.anim += dt * 4.0
					continue
			"flee":
				spd *= 2.6
				f.t -= dt
				if f.t <= 0.0:
					f.st = "swim"
					f.wt = 0.0
		var dx: float = f.tx - f.x
		var dy: float = f.ty - f.y
		var d := sqrt(dx * dx + dy * dy)
		if d < 0.001:
			d = 1.0
		var slow := minf(1.0, d / 14.0) if f.st == "swim" else 1.0
		var k := minf(1.0, dt * 1.8)
		f.vx += (dx / d * spd * slow - f.vx) * k
		f.vy += (dy / d * spd * 0.6 * slow - f.vy) * k
		f.x += f.vx * dt
		f.y = clampf(f.y + f.vy * dt, water_top(f.x) + hs.y, bed_at(f.x) - hs.y + 1.0)
		if f.st != "look" and absf(f.vx) > 0.8:
			f.face = 1 if f.vx > 0 else -1
		f.anim += dt * (1.6 + absf(f.vx) * 0.3)
		if A.get("jump", false) and f.st == "swim" and f.y < SURF + 30 and randf() < dt * 0.012 and place.platform != "icehole":
			f.st = "jumping"
		if f.st == "jumping":
			_fish_jump(f)
		if randf() < dt * 0.03:
			bubbles.append({"x": f.x + f.face * hs.x * 0.6, "y": f.y - 1.0, "vy": -randf_range(10, 16), "r": 1, "ph": randf() * 6.0})
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(2.5, 6.0)
		if fish.size() < _fish_target():
			_spawn(false)


func _fish_jump(f: Dictionary) -> void:
	f.st = "swim"
	var hs := fish_half(f)
	f.jump = 0.0
	f.jx0 = f.x
	f.jh = 10.0 + hs.x * 0.7
	_splash(f.x, 6)
	synth.splash_small()


func _sight(f: Dictionary) -> float:
	return 30.0 + Species.ALL[f.sp].body.rx * 1.6


func _interest(f: Dictionary) -> float:
	var A: Dictionary = Species.ALL[f.sp]
	var bait: String = S.bait
	var k := 1.0 if bait in A.bait else (0.3 if bait == "worm" else 0.12)
	if bait == "plug":
		if A.fight < 0.4:
			return 0.0
		if A.r >= 2:
			k *= 1.5
	if bait == "spinner":
		k *= 1.4 if holding else 0.55
	k *= D.time_factor(A.time, local_hours())
	k *= D.WEATHER[S.wx].bite
	if A.r == 3:
		k *= 0.7
	var band := _band(f)
	if lure.y < band.x - 12.0 or lure.y > band.y + 12.0:
		k *= 0.25
	return k


func _notice(f: Dictionary, dt: float) -> void:
	var m := mouth_of(f)
	var d := m.distance_to(Vector2(lure.x, lure.y))
	if d > _sight(f):
		return
	if randf() < dt * 1.3 * _interest(f):
		f.st = "look"
		f.t = 0.0
		lure.eng = f.id


func _drop_interest(f: Dictionary) -> void:
	f.st = "swim"
	f.cool = randf_range(4.0, 8.0)
	f.wt = 0.0
	if lure.eng == f.id:
		lure.eng = -1


func _spook(f: Dictionary, text: String) -> void:
	f.st = "flee"
	f.t = 1.6
	f.cool = 12.0
	var away := 1.0 if f.x > lure.x else -1.0
	f.tx = clampf(f.x + away * 60.0, -40, W + 40)
	f.ty = f.y + randf_range(-6, 10)
	if lure.eng == f.id:
		lure.eng = -1
	_say(text)


func _lost_bait(f: Dictionary) -> void:
	_spook(f, "Too slow. It stole the bait.")
	S.stats.lost += 1


func _nibble_fx() -> void:
	lure.jig = 0.25
	synth.nibble()
	ripples.append({"x": lure.x, "t": 0.0})


func _say(text: String, t := 2.2) -> void:
	msg = text
	msg_t = t


# ---------- the cast and the line ----------

## Called when the action button or the scene goes down.
func action_down() -> void:
	if S.is_empty():
		return
	holding = true
	match phase:
		"idle":
			phase = "aim"
			aim_t = 0.0
			power = 0.0
		"sink":
			var f = fish_by_id(lure.eng)
			if f != null:
				if f.st == "bite":
					_hook(f)
				elif f.st == "nibble":
					_spook(f, "Too early! Wait for the bite.")
		"show":
			pass


func action_up() -> void:
	holding = false
	if phase == "aim":
		if aim_t < 0.14:
			phase = "idle"
			if S.tut == 0:
				_say("Hold to charge the cast, then let go.")
			return
		_cast()


func _cast() -> void:
	phase = "fly"
	var range_k := gear_stat("rod", "cast")
	var tx := landing.x + 6.0 + power * range_k * (W - landing.x - 18.0)
	if place.platform == "icehole":
		tx = hole_x
	lure.st = "air"
	lure.x0 = tip.x
	lure.y0 = tip.y
	lure.x1 = tx
	lure.t = 0.0
	lure.dur = 0.45 + 0.4 * power if place.platform != "icehole" else 0.35
	lure.peak = 16.0 + 28.0 * power if place.platform != "icehole" else 4.0
	lure.eng = -1
	lure.rest = false
	S.stats.casts += 1
	if S.tut == 0:
		S.tut = 1
	synth.cast()


func _reset_line() -> void:
	phase = "idle"
	lure.st = "rod"
	lure.eng = -1
	fight = {}
	for f in fish:
		if f.st == "hooked":
			f.st = "flee"
			f.t = 1.5


func _update_lure(dt: float) -> void:
	lure.jig = maxf(0.0, lure.jig - dt)
	match lure.st:
		"air":
			lure.t += dt
			var k: float = minf(1.0, lure.t / lure.dur)
			lure.x = lerpf(lure.x0, lure.x1, k)
			var base := lerpf(lure.y0, float(SURF), k)
			lure.y = base - sin(k * PI) * lure.peak
			if k >= 1.0:
				lure.st = "water"
				lure.y = SURF + 1.0
				phase = "sink"
				_splash(lure.x, 4)
				ripples.append({"x": lure.x, "t": 0.0})
				synth.plop()
		"water":
			if phase == "fight":
				return
			var bed_y := bed_at(lure.x) - 2.0
			var eng = fish_by_id(lure.eng)
			var bitten: bool = eng != null and (eng.st == "nibble" or eng.st == "bite")
			if holding and not bitten:
				var to := landing - Vector2(lure.x, lure.y)
				var d := to.length()
				var sp := reel_px() * dt
				if d <= sp + 3.0:
					_reset_line()
					return
				lure.x += to.x / d * sp
				lure.y += to.y / d * sp * 1.15
				lure.rest = false
				_tick_acc += sp
				if _tick_acc > 6.0:
					_tick_acc = 0.0
					synth.reel()
			elif not lure.rest:
				var sink: float = 13.0 * D.BAITS[S.bait].sink
				if bitten and eng.st == "bite":
					sink = 6.0
				lure.y += sink * dt
				lure.x += sin(T * 1.3) * 0.03
				if lure.y >= bed_y:
					lure.y = bed_y
					lure.rest = true
			if place.platform == "icehole":
				lure.x = lerpf(lure.x, float(hole_x), minf(1.0, dt * 2.0))
			lure.y = clampf(lure.y, water_top(lure.x) - 1.0, bed_y)


func _update_rod(dt: float) -> void:
	var target := -1.05
	var bend := 0.0
	match phase:
		"aim":
			target = lerpf(-1.3, -2.5, power)
		"fly":
			target = -0.45
		"sink":
			target = -0.75 if not holding else -0.55
			var eng = fish_by_id(lure.eng)
			if eng != null and eng.st == "bite":
				bend = 0.25
		"fight":
			target = -1.2 + fight.ten * 0.25
			bend = clampf(fight.ten, 0.0, 1.3)
		"land", "show":
			target = -0.8
			bend = 0.45
	rod_ang += (target - rod_ang) * minf(1.0, dt * (14.0 if phase == "fly" else 7.0))
	rod_bend += (bend - rod_bend) * minf(1.0, dt * 8.0)
	bob = sin(T * 1.6) * 0.8 if place.platform in ["boat", "skiff", "felucca", "longtail", "raft"] else 0.0
	hand = Vector2(angler.x + 5.0, angler.y - 13.0 + D.jr(bob))
	var L := 25.0
	var a := rod_ang + rod_bend * 0.5
	tip = hand + Vector2(cos(a), sin(a)) * L
	if phase == "fight" or (phase == "sink" and rod_bend > 0.05):
		tip.y += rod_bend * 3.0


# ---------- the fight ----------

func _hook(f: Dictionary) -> void:
	var A: Dictionary = Species.ALL[f.sp]
	f.st = "hooked"
	phase = "fight"
	var off := Vector2(f.x, f.y) - landing
	fight = {"id": f.id, "d": off.length(), "ten": 0.4, "strain": 0.0, "slack": 0.0, "stam": 1.0, "run": 0.0, "run_cd": randf_range(0.8, 2.0),
		"ang": atan2(off.y, off.x), "tang": atan2(off.y, off.x), "turn_t": 1.5, "jump": -1.0, "dmax": Vector2(W - landing.x, BED - landing.y).length(),
		"big": A.r >= 2 or A.fight > 0.7}
	if S.tut < 3:
		S.tut = 3
	synth.hook()
	_splash(lure.x, 5)
	_say("Fish on!", 1.2)


func _update_fight(dt: float) -> void:
	var f = fish_by_id(fight.id)
	if f == null:
		_reset_line()
		return
	var A: Dictionary = Species.ALL[f.sp]
	var avg: float = (A.w[0] + A.w[1]) * 0.5
	var size_k := pow(f.w / avg, 0.22)
	var running: bool = fight.run > 0.0
	var pull: float = A.fight * size_k * (0.35 + 0.65 * fight.stam) * (1.9 if running else 1.0)
	var line_s := gear_stat("line", "str")
	var ratio := pull / line_s
	var rp := reel_px()
	var jumping: bool = fight.jump >= 0.0
	var tt: float
	if jumping:
		tt = 0.15
	elif holding:
		tt = 0.22 + 0.78 * ratio
		fight.d -= rp * clampf(1.15 - ratio * 0.9, -0.7, 1.0) * dt
		_tick_acc += rp * dt
		if _tick_acc > 5.0:
			_tick_acc = 0.0
			synth.reel()
	else:
		tt = 0.08 + 0.3 * ratio
		fight.d += rp * 0.55 * ratio * dt
	fight.ten += (tt - fight.ten) * minf(1.0, dt * 5.0)
	if fight.ten > 1.0:
		fight.strain += (fight.ten - 1.0) * dt * 3.0 + dt * 0.55
		_creak_t -= dt
		if _creak_t <= 0.0:
			_creak_t = 0.22
			synth.creak()
	else:
		fight.strain = maxf(0.0, fight.strain - dt * 0.7)
	if fight.ten < 0.16 and not holding and not jumping:
		fight.slack += dt
	else:
		fight.slack = maxf(0.0, fight.slack - dt * 2.0)
	var drain: float = (0.05 + 0.16 * fight.ten) * (1.0 if holding else 0.65) * (1.6 if running else 1.0) / A.endur
	fight.stam = maxf(0.0, fight.stam - drain * dt)
	fight.run_cd -= dt
	if running:
		fight.run -= dt
	elif fight.run_cd <= 0.0 and fight.stam > 0.15:
		fight.run = randf_range(0.8, 1.8) * (0.6 + 0.6 * fight.stam)
		fight.run_cd = randf_range(2.2, 4.5) * (1.4 - fight.stam * 0.5)
		fight.tang = randf_range(-0.1, 1.2) if place.platform != "icehole" else randf_range(0.4, 2.6)
		_splash(f.x, 3)
		if A.get("jump", false) and randf() < 0.55 and place.platform != "icehole":
			fight.jump = 0.0
			synth.splash()
	fight.d = clampf(fight.d, 0.0, fight.dmax)
	# Where the fish is on screen.
	fight.turn_t -= dt
	if fight.turn_t <= 0.0:
		fight.turn_t = randf_range(1.2, 2.6)
		fight.tang = randf_range(0.0, 1.25) if place.platform != "icehole" else randf_range(0.3, 2.8)
	fight.ang += (fight.tang - fight.ang) * minf(1.0, dt * (1.6 if running else 0.7))
	var hs := fish_half(f)
	var p: Vector2 = landing + Vector2(cos(fight.ang), sin(fight.ang)) * fight.d
	p.x = clampf(p.x, landing.x - 4.0 if place.platform == "icehole" else landing.x + 2.0, W - hs.x)
	var top := water_top(p.x) + hs.y * 0.6
	if place.platform == "icehole" and absf(p.x - hole_x) < 6.0:
		top = SURF + 2.0
	p.y = clampf(p.y, top, bed_at(p.x) - hs.y + 1.0)
	if jumping:
		fight.jump += dt / 0.9
		var k: float = fight.jump
		p.y = SURF - sin(k * PI) * (10.0 + hs.x * 0.6)
		if k >= 1.0:
			fight.jump = -1.0
			_splash(p.x, 8)
			synth.splash()
	var prev_x: float = f.x
	f.x = lerpf(f.x, p.x, minf(1.0, dt * 6.0))
	f.y = lerpf(f.y, p.y, minf(1.0, dt * 6.0)) if not jumping else p.y
	if absf(f.x - prev_x) > 0.05:
		f.face = 1 if f.x > prev_x else -1
	if holding and not running:
		f.face = -1 if f.x > landing.x else 1
	f.anim += dt * (6.0 if running else 3.0)
	var m := mouth_of(f)
	lure.x = m.x
	lure.y = m.y
	if randf() < dt * 3.0 and not jumping:
		bubbles.append({"x": f.x, "y": f.y - 2.0, "vy": -randf_range(12, 20), "r": 1, "ph": randf() * 6.0})
	if fight.strain >= 1.0:
		_snap(f)
	elif fight.slack > 3.2:
		_spat(f)
	elif fight.d < 7.0 and not jumping:
		_land(f)


func _snap(f: Dictionary) -> void:
	S.stats.snaps += 1
	synth.snap()
	_spook(f, "SNAP! The line broke.")
	f.cool = 30.0
	fight = {}
	phase = "idle"
	lure.st = "rod"
	flash = 0.3
	toast.emit("The line snapped. Let go of the reel when the line turns red.", "bad")


func _spat(f: Dictionary) -> void:
	S.stats.lost += 1
	_spook(f, "Slack line. It spat the hook.")
	fight = {}
	phase = "idle"
	lure.st = "rod"
	synth.lose()


func _land(f: Dictionary) -> void:
	var A: Dictionary = Species.ALL[f.sp]
	phase = "land"
	land_t = 0.0
	fight = {}
	fish.erase(f)
	lure.st = "held"
	var length: float = lerpf(A.l[0], A.l[1], pow(f.wk, 0.6))
	var price := maxi(1, D.jr(A.price * D.SELL_MULT * (0.7 + 0.6 * f.wk)))
	var e: Dictionary = S.book.get(f.sp, {})
	var is_new := e.is_empty()
	var record: bool = not is_new and f.w > float(e.get("best", 0.0))
	if is_new:
		e = {"n": 0, "best": 0.0, "len": 0.0}
	e.n = int(e.n) + 1
	if f.w > float(e.best):
		e.best = f.w
		e.len = length
	S.book[f.sp] = e
	S.stats.caught += 1
	var ph := D.phase_of(local_hours())
	if ph == "Night":
		S.stats.night += 1
	if ph == "Dawn":
		S.stats.dawn += 1
	if S.wx == "rain" or S.wx == "snow":
		S.stats.rain += 1
	if A.r == 3:
		S.stats.legend += 1
	if f.wk >= 0.9:
		S.stats.record += 1
	if f.w >= 100.0:
		S.stats.heavy += 1
	if S.tut < 4:
		S.tut = 4
	catch_info = {"sp": f.sp, "sz": f.sz, "name": A.name, "latin": A.latin, "w": f.w, "len": length, "price": price, "r": A.r, "new": is_new,
		"record": record, "legend": A.r == 3, "desc": A.desc}
	_splash(landing.x, 8)
	synth.land()
	_legend_hint = false if A.r == 3 else _legend_hint


func _update_land(dt: float) -> void:
	land_t += dt
	if land_t >= 0.6 and phase == "land":
		phase = "show"
		synth.fanfare(catch_info.r, catch_info.new)
		landed.emit(catch_info)
		save()
		_emit()


## The landed fish dangles from the rod tip. Returns its position and flip.
func dangle() -> Dictionary:
	if catch_info.is_empty():
		return {}
	var k := minf(1.0, land_t / 0.6)
	var hang := tip + Vector2(0, 6)
	var p := landing.lerp(hang, k * k * (3.0 - 2.0 * k))
	var m := Sprites.mask(catch_info.sp, catch_info.sz)
	return {"x": p.x, "y": p.y + m.rx * 0.9, "rot": -PI / 2.0 + sin(T * 6.0) * 0.25, "fr": int(T * 6.0) % 4}


func sell_catch() -> void:
	if catch_info.is_empty():
		return
	var p: int = catch_info.price
	if catch_info.legend:
		S.stats.released += 1
		_released_fish(catch_info)
		_earn(p, "Bounty")
	else:
		S.stats.sold += 1
		_earn(p, "")
	catch_info = {}
	phase = "idle"
	lure.st = "rod"
	save()
	_emit()


func release_catch() -> void:
	if catch_info.is_empty():
		return
	S.stats.released += 1
	_released_fish(catch_info)
	if catch_info.legend:
		_earn(catch_info.price, "Bounty")
	synth.splash()
	catch_info = {}
	phase = "idle"
	lure.st = "rod"
	save()
	_emit()


func _released_fish(c: Dictionary) -> void:
	var f := {"id": _id(), "sp": c.sp, "sz": c.sz, "w": c.w, "wk": 0.5, "x": landing.x + 2.0, "y": SURF + 6.0, "vx": 0.0, "vy": 0.0, "face": 1,
		"tx": W + 40.0, "ty": SURF + 30.0, "wt": 0.0, "st": "leave", "t": 0.0, "anim": 0.0, "ph": 0.0, "life": 0.0, "cool": 99.0, "nib": 0, "d0": 0.5, "jump": -1.0}
	fish.append(f)
	_splash(landing.x, 6)


func _earn(n: int, label: String) -> void:
	S.coins += n
	S.total += n
	pops.append({"x": tip.x, "y": tip.y - 4.0, "txt": "+" + str(n), "t": 0.0})
	synth.coin()
	if label != "":
		toast.emit("%s +%d coins" % [label, n], "ach")


# ---------- effects ----------

func _splash(x: float, n: int) -> void:
	for i in n:
		splashes.append({"x": x + randf_range(-2, 2), "y": SURF - 1.0, "vx": randf_range(-14, 14), "vy": -randf_range(18, 34), "t": 0.0})
	ripples.append({"x": x, "t": 0.0})


func _update_fx(dt: float) -> void:
	for i in range(bubbles.size() - 1, -1, -1):
		var b: Dictionary = bubbles[i]
		b.y += b.vy * dt
		b.x += sin(T * 4.0 + b.ph) * 0.12
		if b.y <= water_top(b.x):
			bubbles.remove_at(i)
	for i in range(splashes.size() - 1, -1, -1):
		var s: Dictionary = splashes[i]
		s.t += dt
		s.vy += 90.0 * dt
		s.x += s.vx * dt
		s.y += s.vy * dt
		if s.y > SURF:
			splashes.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].t += dt
		if ripples[i].t > 1.2:
			ripples.remove_at(i)
	for i in range(pops.size() - 1, -1, -1):
		var p: Dictionary = pops[i]
		p.t += dt
		p.y -= 8.0 * dt
		if p.t > 1.6:
			pops.remove_at(i)
	for f in fish:
		if f.get("jump", -1.0) >= 0.0:
			f.jump += dt / 0.9
			if f.jump >= 1.0:
				f.jump = -1.0
				_splash(f.x, 6)
				synth.splash_small()
	# Clouds.
	for c in clouds:
		c.x += c.v * dt
		if c.x > W + 10:
			c.x = -float(c.img.get_width()) - randf_range(0, 40)
			c.y = randf_range(6, SURF * 0.55)
	# Rain and snow.
	var wx: String = S.wx
	if wx == "rain" or wx == "snow":
		var rate := (W / 320.0) * (90.0 if wx == "rain" else 40.0)
		var n := int(rate * dt + randf())
		for i in n:
			drops.append({"x": randf_range(-10, W + 10), "y": randf_range(-6, 0), "ph": randf() * 6.0})
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		if wx == "rain":
			d.y += 150.0 * dt
			d.x -= 30.0 * dt
		else:
			d.y += 16.0 * dt
			d.x += sin(T * 1.5 + d.ph) * 6.0 * dt - 3.0 * dt
		if d.y >= SURF or wx != "rain" and wx != "snow":
			if wx == "rain" and randf() < 0.3:
				ripples.append({"x": d.x, "t": 0.6})
			drops.remove_at(i)
	# Birds.
	_bird_t -= dt
	if _bird_t <= 0.0:
		_bird_t = randf_range(7.0, 18.0)
		var n := randi_range(1, 3)
		var dir := 1 if randf() < 0.5 else -1
		var y := randf_range(10, SURF * 0.6)
		for i in n:
			birds.append({"x": -10.0 - i * 9 if dir > 0 else W + 10.0 + i * 9, "y": y + i * 3 + randf_range(-2, 2), "v": randf_range(14, 22) * dir, "ph": randf() * 6.0})
	for i in range(birds.size() - 1, -1, -1):
		var b: Dictionary = birds[i]
		b.x += b.v * dt
		b.y += sin(T * 1.3 + b.ph) * 0.08
		if b.x < -30 or b.x > W + 30:
			birds.remove_at(i)
	_update_ambient(dt)


## Ambient life: whales, dolphins, boats, turtles, penguins and the like.
func _update_ambient(dt: float) -> void:
	_amb_t -= dt
	var kinds: Array = place.get("ambient", [])
	if _amb_t <= 0.0 and not kinds.is_empty():
		_amb_t = randf_range(14.0, 30.0)
		var k: String = kinds.pick_random()
		var dir := 1 if randf() < 0.5 else -1
		match k:
			"whale", "dolphin", "boto", "seal", "sealion":
				amb.append({"k": k, "x": randf_range(W * 0.45, W * 0.9), "t": 0.0, "dur": 3.2 if k == "whale" else 1.6, "dir": dir})
			"ship", "sail", "felucca", "longtail", "raft":
				amb.append({"k": k, "x": -24.0 if dir > 0 else W + 24.0, "t": 0.0, "dur": 999.0, "dir": dir, "v": randf_range(3.0, 6.0) if k != "longtail" else 14.0})
			"turtle":
				amb.append({"k": k, "x": -16.0 if dir > 0 else W + 16.0, "y": randf_range(SURF + 20, BED - 20), "t": 0.0, "dur": 999.0, "dir": dir, "v": 5.0})
			"loon", "ducks":
				amb.append({"k": k, "x": -10.0 if dir > 0 else W + 10.0, "t": 0.0, "dur": 999.0, "dir": dir, "v": 2.5})
			"penguins":
				amb.append({"k": k, "x": W + 10.0, "t": 0.0, "dur": 999.0, "dir": -1, "v": 3.5, "n": randi_range(2, 4)})
			"ice":
				amb.append({"k": k, "x": -12.0, "t": 0.0, "dur": 999.0, "dir": 1, "v": 1.2, "w": randi_range(5, 12)})
	if place.get("nessie", false) and S.wx == "fog" and randf() < dt * 0.004 and not amb.any(func(a): return a.k == "nessie"):
		amb.append({"k": "nessie", "x": W * randf_range(0.55, 0.8), "t": 0.0, "dur": 9.0, "dir": -1})
	for i in range(amb.size() - 1, -1, -1):
		var a: Dictionary = amb[i]
		a.t += dt
		if a.has("v"):
			a.x += a.v * a.dir * dt
			if (a.dir > 0 and a.x > W + 30) or (a.dir < 0 and a.x < -30):
				amb.remove_at(i)
				continue
		if a.t > a.dur:
			amb.remove_at(i)


# ---------- frame loop ----------

func _process(delta: float) -> void:
	if S.is_empty():
		return
	var dt := minf(0.1, delta)
	T += dt
	var prev_day: float = S.utc
	S.utc = fmod(S.utc + dt * 24.0 / D.DAY, 24.0)
	if S.utc < prev_day:
		S.day += 1
	S.wx_t -= dt
	if S.wx_t <= 0.0:
		_new_weather(true)
	if phase == "aim":
		aim_t += dt
		power = 0.5 - 0.5 * cos(aim_t * 2.6)
	_update_rod(dt)
	_update_lure(dt)
	if phase == "fight":
		_update_fight(dt)
	if phase == "land" or phase == "show":
		_update_land(dt)
	_update_fish(dt)
	_update_fx(dt)
	flash = maxf(0.0, flash - dt)
	msg_t = maxf(0.0, msg_t - dt)
	synth.music(T, sky().light, place.music)
	synth.weather(S.wx)
	_sec_t += dt
	if _sec_t > 1.0:
		_sec_t = 0.0
		_check_ach()
	_save_t += dt
	if _save_t > 10.0:
		_save_t = 0.0
		save()
	_emit_t += dt
	if _emit_t > 0.25:
		_emit_t = 0.0
		_emit()


func _emit() -> void:
	changed.emit()


# ---------- travel and shop ----------

func can_travel(k: String) -> bool:
	return S.unlocked.has(k)


func unlock(k: String) -> bool:
	var P: Dictionary = Places.get_place(k)
	if S.unlocked.has(k):
		return true
	if S.coins < P.price:
		toast.emit("You need %s coins to go to %s" % [D.fmt_int(P.price), P.name], "info")
		return false
	S.coins -= P.price
	S.unlocked[k] = true
	synth.buy()
	save()
	_emit()
	return true


func travel(k: String) -> void:
	if not S.unlocked.has(k) or k == loc:
		return
	_reset_line()
	catch_info = {}
	loc = k
	S.loc = k
	place = Places.get_place(k)
	var first: bool = not S.visited.has(k)
	S.visited[k] = true
	amb.clear()
	birds.clear()
	splashes.clear()
	ripples.clear()
	bubbles.clear()
	_legend_hint = false
	_build_place()
	_new_weather(true)
	_populate()
	synth.warm(place.music)
	world_resized.emit()
	place_changed.emit()
	if first:
		toast.emit("First visit to %s. %d new species to find." % [place.name, Species.of_place(k).size()], "new")
	save()
	_emit()


func buy_gear(kind: String) -> void:
	var lv: int = S.gear[kind]
	var tbl: Array = D.GEAR[kind]
	if lv >= tbl.size() - 1:
		return
	var nx: Dictionary = tbl[lv + 1]
	if S.coins < nx.price:
		toast.emit("Not enough coins", "info")
		return
	S.coins -= nx.price
	S.gear[kind] = lv + 1
	synth.buy()
	toast.emit(nx.name + " ready", "good")
	save()
	_emit()


func buy_bait(k: String) -> void:
	if S.baits.has(k):
		set_bait(k)
		return
	var b: Dictionary = D.BAITS[k]
	if S.coins < b.price:
		toast.emit("Not enough coins", "info")
		return
	S.coins -= b.price
	S.baits[k] = true
	S.bait = k
	synth.buy()
	toast.emit(b.name + " in the tackle box", "good")
	save()
	_emit()


func set_bait(k: String) -> void:
	if not S.baits.has(k):
		return
	if phase == "fight" or phase == "land" or phase == "show":
		toast.emit("Land this fish first", "info")
		return
	S.bait = k
	if phase == "sink":
		_reset_line()
	synth.click()
	_emit()


func set_sound(v: bool) -> void:
	synth.set_on(v)
	_save_settings()
	_emit()


func cheat(n: int) -> void:
	S.coins += n
	synth.ach()
	toast.emit("+%d coins" % n, "ach")
	save()
	_emit()


func reset() -> void:
	S = _fresh_state()
	loc = S.loc
	place = Places.get_place(loc)
	catch_info = {}
	_reset_line()
	_build_place()
	_new_weather(true)
	_populate()
	world_resized.emit()
	place_changed.emit()
	save()
	toast.emit("A fresh start in Lofoten. Tight lines!", "info")
	_emit()


# ---------- hover ----------

func hover_at(p: Vector2, sticky: bool) -> void:
	hover = p
	if sticky:
		hover_until = T + 2.5


func fish_at(p: Vector2):
	var best = null
	var bd := 1e9
	for f in fish:
		var hs := fish_half(f)
		if absf(p.x - f.x) < hs.x + 2.0 and absf(p.y - f.y) < hs.y + 3.0:
			var d := p.distance_squared_to(Vector2(f.x, f.y))
			if d < bd:
				bd = d
				best = f
	return best


# ---------- achievements ----------

func _check_ach() -> void:
	for a in D.ACH:
		if S.ach.has(a.id):
			continue
		if _ach_met(a.id):
			S.ach[a.id] = 1
			S.coins += a.r
			S.total += a.r
			synth.ach()
			toast.emit("Achievement: %s · +%d coins" % [a.name, a.r], "ach")


func _place_complete() -> bool:
	for k in Places.ORDER:
		var all := true
		for sp in Species.of_place(k):
			if not S.book.has(sp):
				all = false
				break
		if all:
			return true
	return false


func _ach_met(id: String) -> bool:
	var st: Dictionary = S.stats
	match id:
		"first":
			return st.caught >= 1
		"ten":
			return st.caught >= 10
		"fifty":
			return st.caught >= 50
		"hundred":
			return st.caught >= 200
		"species10":
			return S.book.size() >= 10
		"species30":
			return S.book.size() >= 30
		"species60":
			return S.book.size() >= 60
		"all":
			return S.book.size() >= Species.count()
		"place":
			return _place_complete()
		"travel":
			return S.visited.size() >= 2
		"travel5":
			return S.visited.size() >= 6
		"world":
			return S.visited.size() >= Places.ORDER.size()
		"rare":
			for k in S.book:
				if Species.ALL[k].r >= 2:
					return true
			return false
		"legend":
			return st.legend >= 1
		"legend5":
			var n := 0
			for k in S.book:
				if Species.ALL[k].r == 3:
					n += 1
			return n >= 5
		"night":
			return st.night >= 1
		"dawn":
			return st.dawn >= 1
		"rain":
			return st.rain >= 1
		"release":
			return st.released >= 10
		"record":
			return st.record >= 1
		"heavy":
			return st.heavy >= 1
		"snap":
			return st.snaps >= 1
		"gear":
			return S.gear.rod >= 3 and S.gear.reel >= 3 and S.gear.line >= 3
		"tackle":
			return S.baits.size() >= D.BAIT_KEYS.size()
		"rich":
			return S.total >= 10000
	return false


# ---------- save ----------

func save() -> void:
	if S.is_empty():
		return
	var file := FileAccess.open(D.SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(S))
		file.close()


func _load() -> Dictionary:
	if not FileAccess.file_exists(D.SAVE_PATH):
		return {}
	var s = JSON.parse_string(FileAccess.get_file_as_string(D.SAVE_PATH))
	if typeof(s) != TYPE_DICTIONARY or int(s.get("v", 0)) != 1:
		return {}
	var base := _fresh_state()
	for k in base:
		if not s.has(k):
			s[k] = base[k]
	for k in ["coins", "total", "day", "tut"]:
		s[k] = int(s[k])
	s.utc = float(s.utc)
	s.wx_t = float(s.get("wx_t", 0.0))
	for k in ["rod", "reel", "line"]:
		s.gear[k] = clampi(int(s.gear.get(k, 0)), 0, 3)
	for k in base.stats:
		s.stats[k] = int(s.stats.get(k, 0))
	for k in s.book:
		var e: Dictionary = s.book[k]
		e.n = int(e.get("n", 1))
		e.best = float(e.get("best", 0.0))
		e.len = float(e.get("len", 0.0))
	var clean := {}
	for k in s.book:
		if Species.ALL.has(k):
			clean[k] = s.book[k]
	s.book = clean
	if not Places.ALL.has(s.loc):
		s.loc = "lofoten"
	if not D.BAITS.has(s.bait) or not s.baits.has(s.bait):
		s.bait = "worm"
	return s


func _load_settings() -> void:
	if not FileAccess.file_exists(D.SETTINGS_PATH):
		return
	var s = JSON.parse_string(FileAccess.get_file_as_string(D.SETTINGS_PATH))
	if typeof(s) == TYPE_DICTIONARY and synth:
		synth.set_on(bool(s.get("sound", true)))


func _save_settings() -> void:
	var file := FileAccess.open(D.SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"sound": synth.on}))
		file.close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		save()


# ---------- snapshot for the HUD ----------

func snapshot() -> Dictionary:
	var h := local_hours()
	var ph := D.phase_of(h)
	var action := "HOLD TO CAST"
	var hint := ""
	match phase:
		"aim":
			action = "LET GO TO CAST"
		"fly":
			action = "..."
		"sink":
			action = "HOLD TO REEL"
			var f = fish_by_id(lure.eng)
			if f != null and f.st == "bite":
				action = "STRIKE!"
			elif f != null and f.st == "nibble":
				action = "WAIT..."
		"fight":
			action = "HOLD TO REEL"
		"land", "show":
			action = "NICE CATCH"
	if S.tut == 0:
		hint = "Hold the button, or hold anywhere on the water, to charge a cast. Let go to throw."
	elif S.tut == 1 and phase == "sink":
		hint = "Let the lure sink to the fish. Hold to reel it in. Wait for a bite."
	elif S.tut <= 2 and phase == "sink":
		var f = fish_by_id(lure.eng)
		if f != null and f.st == "nibble":
			hint = "A fish is nibbling. Do not strike yet. Wait for the big bite."
		elif f != null and f.st == "bite":
			hint = "BITE! Press now to set the hook."
	elif S.tut == 3 and phase == "fight":
		hint = "Hold to reel. Let go when the line turns red, or it snaps."
	var pool := Species.of_place(loc)
	var found := 0
	for k in pool:
		if S.book.has(k):
			found += 1
	return {"coins": S.coins, "place": place, "loc": loc, "clock": "%02d:%02d" % [floori(h), floori(fmod(h, 1.0) * 60.0)], "phase": ph,
		"wx": S.wx, "bait": S.bait, "action": action, "hint": hint, "sound": synth.on, "found": found, "total_here": pool.size(),
		"book": S.book.size(), "book_total": Species.count(), "state": phase, "gear": S.gear}
