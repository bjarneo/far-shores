class_name Sprites
extends RefCounted
## Builds every pixel sprite at runtime and caches the results.
## The fish builder comes from Little Reef and adds bills, whiskers, teeth, more tails and patterns.

static var _masks := {}
static var _frames := {}
static var _decor := {}
static var _plants := {}
static var _misc := {}

## Body scale for each size class. Bigger fish of a species draw bigger.
const SIZES := [0.82, 0.94, 1.06, 1.2]
## All fish draw this much larger than the numbers in Species.
const FISH_SCALE := 1.32

const SHELL := ["...ooo...", "..olplo..", ".olplplo.", "olplplplo", "olplplplo", ".ooooooo.", "...opo..."]
const SHELL_PAL := {"o": "#7a3e32", "p": "#f0a890", "l": "#ffe0cc"}
const DECOR_ART := {
	"starfish": {"pal": {"o": "#7a2e18", "y": "#ee7c3e", "Y": "#ffb070", "d": "#c8562a"}, "rows": [
		"....o....", "...oyo...", "...oYo...", "oooyYyooo", "oyyYYYyyo", ".oyYdYyo.", "..oyYyo..", ".oyyoyyo.", ".oyo.oyo.", ".oo...oo.",
	]},
	"amphora": {"pal": {"o": "#3a1a10", "c": "#c8683a", "L": "#e8925a", "d": "#8a3a20", "b": "#2a1610"}, "rows": [
		"......oooo......", "....ooLLLLoo....", "..ooLLccccLLoo..", ".oLccccccccccoo.", "oocbbbbbbbbbbcoo", "oLcccccccccccc.o",
		"ocLcccccccccccLo", "occcdcdcdcdcdcco", "ooccccccccccccoo", ".ooddddddddddoo.", "...oooooooooo...",
	]},
	"driftwood": {"pal": {"o": "#2a1c12", "L": "#b8936a", "w": "#8a6a48", "d": "#5e4430", "k": "#3e2c1e"}, "rows": [
		"...oo...................oo....", "..owLo.................owdo...", "...owLo...............owdo....", "...owLo...............owdo....",
		"....owLo.............owdo.....", "....owLo.............owdo.....", ".....owLo..ooo......owdo...o..", "..o..owLoooLLLooooo.owdooooLo.",
		".oLoooLLLLLwwwLLLLLoooLLLLLwo.", ".owLLLwwwwwwwwwwwwwLLLwwwwwwo.", ".owwwwwwkwwwwkwwwwwkwwwwkwwwo.", ".oddddddddddddddddddddddddddo.",
		"..oooooooooooooooooooooooooo..",
	]},
	"sponge": {"pal": {"o": "#4a1e3a", "p": "#a8487a", "P": "#d070a0", "d": "#7a2e5a", "k": "#2a0e20"}, "rows": [
		"..oo.......oo..", ".okko.....okko.", ".oPpo..oo.oPpo.", ".oPpo.okko.Ppo.", ".oPpo.oPpo.Ppo.", ".oPpooPpo.oPpo.",
		".oPpdoPpo.oPpd.", ".oPpdoPpooPpdo.", ".oPpdoPpdoPpdo.", "ooPpddPpddPpdoo", "oddddddddddddo.", ".ooooooooooooo.",
	]},
}


static func _img(w: int, h: int) -> Image:
	var img := Image.create_empty(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func sprite_from(rows: Array, pal: Dictionary) -> Image:
	var img := _img(rows[0].length(), rows.size())
	for y in rows.size():
		var r: String = rows[y]
		for i in r.length():
			var ch := r[i]
			if ch != "." and pal.has(ch):
				img.set_pixel(i, y, Color(pal[ch]))
	return img


static func tex_of(key: String, img: Image) -> ImageTexture:
	if not _misc.has(key):
		_misc[key] = ImageTexture.create_from_image(img)
	return _misc[key]


# ---------- fish ----------
# Mask values: 1 body, 2 lower fin, 3 spine, 4 eye, 5 eye shine, 6 body outline, 7 fin outline, 8 lure stalk,
# 9 lure light, 10 pectoral fin, 11 bill, 12 whisker, 13 tooth, 14 gill, 16 upper fin, 17 tail, 18 finlet.

static func mask(sp: String, sz: int) -> Dictionary:
	var k := sp + str(sz)
	if not _masks.has(k):
		_masks[k] = _build_mask(sp, sz)
	return _masks[k]


static func _exp_of(v: float) -> float:
	return clampf(2.0 - v * 1.15, 1.1, 3.4)


static func _build_mask(sp: String, sz: int) -> Dictionary:
	var P: Dictionary = Species.ALL[sp].body
	var sc: float = SIZES[sz] * FISH_SCALE
	var rx: float = maxf(2.0, P.rx * sc)
	var ry: float = maxf(1.2, P.ry * sc)
	var back: float = P.get("back", 1.0)
	var belly: float = P.get("belly", 1.0)
	var ef := _exp_of(P.get("nose", 0.15))
	var er := _exp_of(P.get("taper", 0.4))
	var tl: int = maxi(1, D.jr(P.tl * sc))
	var tail: String = P.tail
	var spread: float = P.get("spread", 0.6)
	var flat: bool = P.get("flat", false)
	var bill: int = D.jr(P.get("bill", 0) * sc)
	var trunk: int = D.jr(P.get("trunk", 0) * sc)
	var nbar: int = P.get("barbels", 0)
	var blen: int = maxi(1, D.jr(P.get("blen", 0) * sc)) if nbar > 0 else 0
	var tops: Array = P.get("top", [])
	var bots: Array = P.get("bot", [])
	var ft := 0
	for f in tops:
		ft = maxi(ft, D.jr(maxf(f[2], f[3]) * sc))
	if P.has("comb"):
		ft = maxi(ft, D.jr(P.comb[2] * sc))
	if P.has("rays"):
		ft = maxi(ft, 3)
	if P.has("streamer"):
		ft = maxi(ft, 3)
	var fb := 0
	for f in bots:
		fb = maxi(fb, D.jr(maxf(f[2], f[3]) * sc))
	if P.get("threads", false):
		fb = maxi(fb, D.jr(6.0 * sc))
	var lure_h := 5 if P.get("lure", false) else 0
	var spines := 2.0 if P.get("spines", false) else 0.0
	var tail_h: float
	match tail:
		"point":
			tail_h = ry
		"shark":
			tail_h = 0.6 + tl * spread * 1.3 + tl * 0.35
		"lunate":
			tail_h = 0.6 + tl * spread * 1.25
		_:
			tail_h = 0.6 + tl * spread
	var pad := 2
	var w := ceili(rx * 2.0 + tl + maxi(bill, trunk) + pad * 2 + 2)
	var half: float = maxf(ry * maxf(back, belly) + maxf(maxf(ft + lure_h, fb), blen + 1) + spines + 1.0, tail_h) + pad
	var h := ceili(half * 2.0) + 1
	var bx: float = pad + tl + rx
	var by: float = floorf(h / 2.0) + 0.5
	var g := PackedByteArray()
	g.resize(w * h)
	g.fill(0)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - bx) / rx
			if absf(dx) >= 1.0:
				continue
			var e := ef if dx > 0.0 else er
			var prof := pow(1.0 - pow(absf(dx), e), 1.0 / e)
			var yy := y + 0.5
			if yy >= by - prof * ry * back and yy <= by + prof * ry * belly:
				g[y * w + x] = 1
	var jx := floori(bx - rx)
	# Tail.
	for i in tl:
		var x := jx - i
		var hh := 0.5 + (i + 1) * spread
		var cy := by
		var top_y := 0.0
		var bot_y := 0.0
		match tail:
			"point":
				hh = ry * 0.45 * (1.0 - (i + 1.0) / (tl + 1.0)) + 0.35
			"veil":
				cy = by + i * 0.45
				hh += tl * 0.2
			"lunate":
				hh = 0.6 + (i + 1) * spread * 1.25
			"round":
				var k0 := tl * 0.55
				hh = 0.5 + minf(i + 1, k0) * spread
				if i >= k0:
					var q := (i - k0) / (tl - k0 + 0.6)
					hh *= sqrt(maxf(0.0, 1.0 - q * q))
		if tail == "shark":
			top_y = by - (0.5 + (i + 1) * spread * 1.3) - i * 0.35
			bot_y = by + (0.5 + (i + 1) * spread * 0.85 if i < tl * 0.55 else -0.2 - i * 0.1)
		else:
			top_y = cy - hh
			bot_y = cy + hh
		for y in h:
			var yy := y + 0.5
			if yy < top_y or yy > bot_y:
				continue
			var ad := absf(yy - cy)
			if tail == "fork" and i >= tl - 2 and tl > 2 and ad < hh * 0.5:
				continue
			if (tail == "fan" or tail == "fork") and i == tl - 1 and tl > 2 and ad > hh - 0.9:
				continue
			if tail == "fan" and i >= tl - 2 and tl > 3 and ad < 0.8:
				continue
			if tail == "lunate":
				var stem := tl * 0.22
				if i < stem:
					if ad > 1.0:
						continue
				else:
					var lobe := (i - stem) * spread * 1.25 + 0.6
					var th := 1.0 + (tl - i) * 0.22
					if ad > lobe + 0.8 or ad < lobe - th:
						continue
			if tail == "shark" and i >= tl * 0.55 and yy > by - (i - tl * 0.55) * 0.9:
				continue
			_mset(g, w, h, x, y, 17)
	# Fins along the back (dir -1) and the belly (dir 1).
	var fin_min := 1
	for spec_dir in [[tops, -1, 16], [bots, 1, 2]]:
		var specs: Array = spec_dir[0]
		var dir: int = spec_dir[1]
		var v: int = spec_dir[2]
		for spec in specs:
			var sweep: float = spec[4] if spec.size() > 4 else 0.0
			var x0 := D.jr(bx + spec[0] * rx)
			var x1 := D.jr(bx + spec[1] * rx)
			for x in range(x0, x1 + 1):
				var t := 0.0 if x1 == x0 else float(x - x0) / (x1 - x0)
				var round_k := 0.5 + 0.5 * sqrt(maxf(0.0, sin(clampf(t * 0.92 + 0.04, 0.0, 1.0) * PI)))
				var fh := maxi(fin_min, D.jr(lerpf(spec[2], spec[3], t) * sc * round_k))
				if x < 0 or x >= w:
					continue
				var e := _edge(g, w, h, x, dir)
				if e < 0:
					e = D.jr(by + dir * ry * 0.3)
				for k in range(1, fh + 1):
					_mset(g, w, h, x - floori(k * sweep), e + dir * k, v)
	if P.has("comb"):
		var c: Array = P.comb
		var x0 := D.jr(bx + c[0] * rx)
		var x1 := D.jr(bx + c[1] * rx)
		for x in range(x0, x1 + 1):
			var e := _edge(g, w, h, x, -1)
			var tall := (x - x0) % 2 == 0
			var fh := D.jr(c[2] * sc * (0.55 + 0.45 * sin(float(x - x0) / maxf(1.0, x1 - x0) * PI))) if tall else 1
			for k in range(1, fh + 1):
				_mset(g, w, h, x - floori(k * 0.2), e - k, 16)
	if P.has("rays"):
		var rs: Array = P.rays
		var n: int = rs[2]
		for i in n:
			var x := D.jr(bx + lerpf(rs[0], rs[1], float(i) / maxf(1, n - 1)) * rx)
			var e := _edge(g, w, h, x, -1)
			_mset(g, w, h, x, e - 1, 16)
			_mset(g, w, h, x, e - 2, 16)
			_mset(g, w, h, x - 1, e - 2, 16)
	if P.has("streamer"):
		var st: Array = P.streamer
		var x := D.jr(bx + st[0] * rx)
		var e := _edge(g, w, h, x, -1)
		for k in range(1, D.jr(st[1] * sc) + 1):
			_mset(g, w, h, x - k, e - 1 - floori(k * 0.22), 16)
	if P.get("threads", false):
		var x := D.jr(bx + 0.25 * rx)
		var e := _edge(g, w, h, x, 1)
		for k in range(1, D.jr(9.0 * sc) + 1):
			_mset(g, w, h, x - floori(k * 0.7), e + 1 + floori(k * 0.45), 2)
	if P.get("spines", false):
		for a in 16:
			var an := a / 16.0 * TAU
			if cos(an) < -0.75:
				continue
			_mset(g, w, h, D.jr(bx + cos(an) * (rx + 1.6) - 0.5), D.jr(by + sin(an) * (ry + 1.6) - 0.5), 3)
	if P.get("headspines", false):
		for i in 3:
			var x := D.jr(bx + rx * (0.3 + i * 0.14))
			var e := _edge(g, w, h, x, -1)
			_mset(g, w, h, x, e - 1, 3)
	# Pectoral fin, drawn on the side of the body.
	if P.has("pect"):
		var pc: Array = P.pect
		var sx := D.jr(bx + pc[0] * rx)
		var sy := D.jr(by + ry * 0.12)
		for k in maxi(1, D.jr(pc[1] * sc)):
			var px := sx - k
			var py := sy + floori(k * 0.5)
			if px >= 0 and py >= 0 and px < w and py < h:
				g[py * w + px] = 10
	# Gill line, or gill slits on sharks.
	var nslit: int = P.get("gill", 0)
	if nslit > 0:
		for j in nslit:
			var gx := D.jr(bx + rx * 0.5) - j * 2
			for yy in range(D.jr(by - ry * 0.35), D.jr(by + ry * 0.3) + 1):
				if gx >= 0 and gx < w and yy >= 0 and yy < h and g[yy * w + gx] == 1:
					g[yy * w + gx] = 14
	elif ry >= 2.4 and not flat and not P.get("wave", false):
		var gx0 := floori(bx + rx * (P.get("eyex", 0.55) - 0.22))
		for yy in range(D.jr(by - ry * 0.55), D.jr(by + ry * 0.5) + 1):
			var gx := gx0 + (1 if absf(yy + 0.5 - by) < ry * 0.25 else 0)
			if gx >= 0 and gx < w and yy >= 0 and yy < h and g[yy * w + gx] == 1:
				g[yy * w + gx] = 14
	# Snout parts.
	var snout := floori(bx + rx) - 1
	while snout > 0 and g[floori(by) * w + snout] != 1:
		snout -= 1
	var mouth_y := floori(by + ry * 0.18)
	if bill > 0:
		var sy := floori(by)
		for k in range(1, bill + 1):
			_mset(g, w, h, snout + k, sy, 11)
			if k < bill * 0.35:
				_mset(g, w, h, snout + k, sy + 1, 11)
	if trunk > 0:
		for k in range(1, trunk + 1):
			_mset(g, w, h, snout + floori(k * 0.75), mouth_y + floori(k * 0.6), 11)
	for j in nbar:
		var sx := snout - 1 - j
		var sy := floori(by + ry * 0.4)
		for k in range(1, blen + 1):
			_mset(g, w, h, sx - floori(k * (0.25 + j * 0.3)), sy + k, 12)
	if P.get("chin", false):
		var cx := D.jr(bx + rx * 0.55)
		var e := _edge(g, w, h, cx, 1)
		_mset(g, w, h, cx, e + 1, 12)
		_mset(g, w, h, cx, e + 2, 12)
	if P.get("chinbar", false):
		var e := _edge(g, w, h, snout, 1)
		for k in range(1, D.jr(3 * sc) + 1):
			_mset(g, w, h, snout + k, e + floori(k * 0.4), 12)
	if P.get("teeth", false) or P.get("fangs", false):
		for tx in [snout, snout - 2]:
			if tx > 0 and mouth_y < h and g[mouth_y * w + tx] == 1:
				g[mouth_y * w + tx] = 13
		if P.get("fangs", false):
			_mset(g, w, h, snout - 1, _edge(g, w, h, snout - 1, 1) + 1, 13)
	# Eyes.
	var ex := floori(bx + rx * P.get("eyex", 0.55))
	var ey := floori(by - ry * P.get("eyey", 0.35))
	var big: int = P.get("eye", 1)
	if flat:
		ey = _edge(g, w, h, ex, -1)
		_set_eye(g, w, h, ex, ey, 1)
		_set_eye(g, w, h, ex - 2, _edge(g, w, h, ex - 2, -1), 1)
	else:
		_set_eye(g, w, h, ex, ey, big)
	if P.get("parasite", false):
		_mset(g, w, h, ex + 1, ey + 1, 13)
		if ey + 1 >= 0 and ey + 1 < h:
			g[(ey + 1) * w + ex + 1] = 13
	var lx := -1
	var ly := -1
	if lure_h > 0:
		var sx := ex + 1
		var e := _edge(g, w, h, sx, -1)
		_mset(g, w, h, sx, e - 1, 8)
		_mset(g, w, h, sx, e - 2, 8)
		_mset(g, w, h, sx + 1, e - 3, 8)
		_mset(g, w, h, sx + 2, e - 3, 9)
		lx = sx + 2
		ly = e - 3
	var out := g.duplicate()
	for y in h:
		for x in w:
			var i := y * w + x
			if g[i] != 0:
				continue
			var nb := false
			var nf := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var X: int = x + o.x
				var Y: int = y + o.y
				if X < 0 or Y < 0 or X >= w or Y >= h:
					continue
				var v := g[Y * w + X]
				if v == 1 or v == 4 or v == 5 or v == 10 or v == 13 or v == 14:
					nb = true
				elif v == 2 or v == 16 or v == 17:
					nf = true
			if nb:
				out[i] = 6
			elif nf:
				out[i] = 7
	var mx := snout + 1 + maxi(bill, 0)
	return {"w": w, "h": h, "g": out, "bx": bx, "by": by, "rx": rx, "ry": ry, "jx": jx, "tl": tl, "lx": lx, "ly": ly,
		"mx": mx, "my": mouth_y, "ex": ex, "ey": ey, "sn": snout}


static func _set_eye(g: PackedByteArray, w: int, h: int, ex: int, ey: int, big: int) -> void:
	if ex < 0 or ey < 0 or ex >= w - 1 or ey >= h - 1:
		return
	if big >= 2:
		g[ey * w + ex] = 4
		g[ey * w + ex + 1] = 5
		g[(ey + 1) * w + ex] = 4
		g[(ey + 1) * w + ex + 1] = 4
	else:
		g[ey * w + ex] = 4
		if g[ey * w + ex - 1] == 1:
			g[ey * w + ex - 1] = 5


static func _mset(g: PackedByteArray, w: int, h: int, x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := y * w + x
	if v == 1 or g[i] == 0:
		g[i] = v


## Returns the top (dir < 0) or bottom (dir > 0) body pixel in a column, or -1.
static func _edge(g: PackedByteArray, w: int, h: int, x: int, dir: int) -> int:
	if x < 0 or x >= w:
		return -1
	if dir < 0:
		for y in h:
			var v := g[y * w + x]
			if v == 1 or v == 14 or v == 10:
				return y
	else:
		for y in range(h - 1, -1, -1):
			var v := g[y * w + x]
			if v == 1 or v == 14 or v == 10:
				return y
	return -1


static func fish_tex(sp: String, sz: int, fr: int, mode: String = "") -> ImageTexture:
	var k := "%s|%d|%d|%s" % [sp, sz, fr, mode]
	if not _frames.has(k):
		_frames[k] = ImageTexture.create_from_image(fish_image(sp, sz, fr, mode))
	return _frames[k]


static func _pal(A: Dictionary) -> Dictionary:
	var p: Dictionary = A.pal
	if p.has("_c"):
		return p._c
	var c := {}
	for k in p:
		c[k] = Color(p[k])
	c.fd = c.get("fd", c.f)
	c.ft = c.get("ft", c.f)
	c.fl = c.get("fl", c.f)
	c.m = c.get("m", D.dark(c.s, 0.4))
	c.m2 = c.get("m2", c.m)
	c.e = c.get("e", Color("#0b0b16"))
	c.out = D.dark(c.b, 0.55)
	c.fout = D.dark(c.f, 0.5)
	p["_c"] = c
	return c


static func fish_image(sp: String, sz: int, fr: int, mode: String) -> Image:
	var A: Dictionary = Species.ALL[sp]
	var P: Dictionary = A.body
	var m := mask(sp, sz)
	var c := _pal(A)
	var w: int = m.w
	var h: int = m.h
	var bx: float = m.bx
	var by: float = m.by
	var rx: float = m.rx
	var ry: float = m.ry
	var jx: int = m.jx
	var grid: PackedByteArray = m.g
	var ph := fr / 4.0 * TAU
	var wave: bool = P.get("wave", false)
	var amp := 0.8 + minf(0.5, rx * 0.012)
	var freq := clampf(7.0 / rx, 0.16, 0.55)
	var flat: bool = P.get("flat", false)
	var pats: Array = A.get("pat", [])
	var shine: bool = A.get("shine", false)
	var glass: bool = A.get("glass", false)
	var sail_spots: bool = A.get("sail_spots", false)
	var scales := rx >= 9.0 and not glass
	# Column extents of the body, for shading that follows the shape.
	var tops := PackedInt32Array()
	var bots := PackedInt32Array()
	tops.resize(w)
	bots.resize(w)
	for x in w:
		tops[x] = -1
		bots[x] = -1
		for y in h:
			var v := grid[y * w + x]
			if v == 1 or v == 4 or v == 5 or v == 10 or v == 13 or v == 14:
				if tops[x] < 0:
					tops[x] = y
				bots[x] = y
	var cols := []
	cols.resize(w * h)
	var empty := Color(0, 0, 0, 0)
	cols.fill(empty)
	for y in h:
		for x in w:
			var i := y * w + x
			var v := grid[i]
			if v == 0 or v == 6 or v == 7:
				continue
			var col: Color
			match v:
				1, 14:
					var top := tops[x]
					var bot := bots[x]
					var tn := 0.5 if bot <= top else float(y - top) / float(bot - top)
					col = _body_col(c, pats, x, y, bx, by, rx, ry, m, flat, tn)
					if scales and tn > 0.2 and tn < 0.78 and (x + 2 * (y % 2)) % 4 == 1:
						col = D.mix(col, D.dark(col, 0.3), 0.35)
					if y == top:
						col = D.light(col, 0.2)
					elif y == bot and not flat:
						col = D.dark(col, 0.18)
					elif tn > 0.36 and tn < 0.47 and x % 3 != 0 and not flat:
						col = D.light(col, 0.12)
					if x + 1 < w and grid[i + 1] == 14:
						col = D.dark(col, 0.1)
					if v == 14:
						col = D.dark(col, 0.28)
					if shine:
						var sh := ((x + y - fr * 4) % 16 + 16) % 16
						if sh == 0 and tn < 0.6:
							col = D.light(col, 0.55)
					if glass:
						col.a = 0.82
				2:
					col = _fin_col(c.f, grid, w, h, x, y, true)
				16:
					col = _fin_col(c.fd, grid, w, h, x, y, true)
					if sail_spots and D.hash2(x, y, 3) < 0.22:
						col = D.dark(c.fd, 0.45)
				17:
					col = c.ft if y % 2 == 0 else D.dark(c.ft, 0.12)
					if x == 0 or grid[i - 1] == 0 or grid[i - 1] == 7:
						col = D.dark(c.ft, 0.28)
					col.a = 0.94
				10:
					col = D.light(c.f, 0.12)
					col.a = 0.9
				18:
					col = c.fl
				3, 8:
					col = c.out
				4:
					col = c.e
				5:
					col = Color("#f5f7ff")
				9:
					col = Color("#fff4a0")
				11:
					col = D.dark(c.b, 0.1)
				12:
					col = D.dark(c.s, 0.45)
				13:
					col = Color("#f2f0e6")
				_:
					col = c.s
			cols[i] = col
	# Eye ring and mouth line.
	var ex: int = m.ex
	var ey: int = m.ey
	if not flat and ex > 0 and ey > 0 and ey < h - 1:
		var ring: Color = c.get("ring", D.light(c.s, 0.45))
		for o in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1)]:
			var q: Vector2i = Vector2i(ex, ey + (1 if P.get("eye", 1) >= 2 else 0)) + o
			var qi: int = q.y * w + q.x
			if q.x >= 0 and q.y < h and grid[qi] == 1:
				cols[qi] = ring
	var my: int = m.my
	var sn: int = m.sn
	for k in 2:
		var qx := sn - k
		if qx > 0 and my > 0 and my < h and grid[my * w + qx] == 1:
			cols[my * w + qx] = D.dark(c.s, 0.5)
	# Outlines take a dark shade of the color they wrap.
	for y in h:
		for x in w:
			var i := y * w + x
			var v := grid[i]
			if v != 6 and v != 7:
				continue
			var nb := empty
			for o in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var X: int = x + o.x
				var Y: int = y + o.y
				if X < 0 or Y < 0 or X >= w or Y >= h:
					continue
				var nv := grid[Y * w + X]
				if nv != 0 and nv != 6 and nv != 7 and cols[Y * w + X].a > 0.0:
					nb = cols[Y * w + X]
					break
			if nb.a <= 0.0:
				nb = c.b if v == 6 else c.f
			var oc := D.dark(nb, 0.55 if v == 6 else 0.45)
			oc.a = 1.0 if v == 6 else 0.95
			cols[i] = oc
	var img := _img(w, h + 2)
	var sil_body := Color("#34466f")
	var sil_eye := Color("#26355a")
	for pass_i in 2:
		for yy in h:
			for xx in w:
				var v := grid[yy * w + xx]
				if v == 0:
					continue
				var is_tail := xx < jx
				if (pass_i == 0) != is_tail:
					continue
				var col: Color = cols[yy * w + xx]
				if mode == "sil":
					col = sil_eye if (v == 4 or v == 5) else sil_body
				elif mode == "white":
					col = Color(1, 1, 1, col.a)
				var dx := 0
				var dy := 0
				if wave:
					dy = D.jr(sin(ph + xx * freq) * amp)
				elif is_tail and fr % 2 == 1:
					dx = D.jr((jx - xx) * 0.3)
				_px(img, xx + dx, yy + 1 + dy, col)
	# Finlets on tunas and mackerels sit between the last fins and the tail.
	var nfl: int = P.get("finlets", 0)
	if nfl > 0 and mode == "":
		for i in nfl:
			var x := jx + 1 + i * 2
			if x >= 0 and x < w and tops[x] >= 0:
				_px(img, x, tops[x], c.fl)
				_px(img, x, bots[x] + 2, c.fl)
	return img


static func _fin_col(base: Color, grid: PackedByteArray, w: int, h: int, x: int, y: int, vertical: bool) -> Color:
	var col := base if x % 2 == 0 else D.dark(base, 0.14)
	var up := y - 1
	var dn := y + 1
	var edge := (up < 0 or grid[up * w + x] == 0 or grid[up * w + x] == 7) or (dn >= h or grid[dn * w + x] == 0 or grid[dn * w + x] == 7)
	if edge:
		col = D.light(base, 0.18)
	col.a = 0.9
	return col


static func _body_col(c: Dictionary, pats: Array, x: int, y: int, bx: float, by: float, rx: float, ry: float, m: Dictionary, flat: bool, tn: float) -> Color:
	var t := tn * 2.0 - 1.0
	var u := (x + 0.5 - bx) / rx
	var col: Color
	var ck := (x + y) % 2 == 0
	if flat:
		col = c.u if tn > 0.82 else (c.s if tn > 0.5 and ck else c.b)
	elif tn < 0.3:
		col = c.b
	elif tn < 0.37:
		col = c.b if ck else c.s
	elif tn < 0.64:
		col = c.s
	elif tn < 0.71:
		col = c.s if ck else c.u
	else:
		col = c.u
	var left := bx - rx
	for p in pats:
		var name: String = p[0]
		match name:
			"wavy":
				if t < -0.05 and sin(x * 1.25 + sin(y * 1.4) * 1.7) > 0.4:
					col = c.m
			"mottle":
				if t < 0.45 and D.hash2(x >> 1, y >> 1, 7) < p[1]:
					col = c.m
			"line":
				var lt := -0.1 + 0.1 * u
				if absf(t - lt) < 0.13 and absf(u) < 0.88:
					col = c.m2 if c.has("m2") and c.m2 != c.m else c.m
			"patch":
				var key: String = p[4] if p.size() > 4 else "m"
				var pcx: float = bx + p[1] * rx
				var pcy: float = by + p[2] * ry
				if Vector2(x + 0.5 - pcx, y + 0.5 - pcy).length() < p[3]:
					col = c[key]
			"bars":
				var n: float = p[1]
				var wd: float = p[2]
				var full: bool = p[3] if p.size() > 3 else false
				var ph := (x + 0.5 - left) / (2.0 * rx) * n
				if fposmod(ph, 1.0) < wd and u > -0.92 and u < 0.8 and (full or t < 0.42):
					col = c.m
			"spots":
				var key: String = p[3] if p.size() > 3 else "m"
				var lim: float = p[2]
				var ok := t < lim if lim >= 0.0 else t > 0.1
				if lim >= 0.99:
					ok = true
				if ok and D.hash2(x, y, 13) < p[1]:
					col = c[key]
			"speckle":
				if t < 0.32 and D.hash2(x, y, 17) < p[1]:
					col = c.m
				elif t > -0.45 and t < 0.3 and D.hash2(x, y, 29) < p[2]:
					col = c.m2
			"stripe":
				if absf(t - p[1]) < p[2] and u > -0.95 and u < 0.85:
					col = c.m
			"stripes":
				if y % 2 == 0 and t > -0.65 and t < 0.6 and u < 0.7:
					col = D.mix(col, c.m, p[1])
			"scales":
				if ((x + (y % 2) * 2) % 4 == 0) and t < 0.5 and u < 0.7:
					col = D.mix(col, c.m, 0.4)
			"bigscales":
				if ((x + y) % 4 == 0 or (x - y + 400) % 4 == 0) and t < 0.55 and u < 0.65:
					col = D.mix(col, c.m, 0.55)
			"scutes":
				var full_len: bool = p.size() > 1
				var toff: float = p[1] if full_len else 0.0
				if x % 2 == 0 and absf(t - toff) < 0.16 and (u < -0.15 or full_len) and u < 0.7:
					col = c.m
			"eyespot":
				var pcx := bx - rx * 0.82
				var pcy := by - ry * 0.05
				var d := Vector2(x + 0.5 - pcx, y + 0.5 - pcy).length()
				if d < 1.1:
					col = c.m
				elif d < 1.8 and c.m2 != c.m:
					col = c.m2
			"ocellus":
				var pcx: float = bx + p[1] * rx
				var pcy: float = by + p[2] * ry
				var d := Vector2(x + 0.5 - pcx, y + 0.5 - pcy).length()
				if d < p[3] * 0.62:
					col = c.m
				elif d < p[3]:
					col = c.m2
			"ocelli":
				var n: int = p[1]
				for i in n:
					var pcx := bx + rx * (-0.78 + i * 0.17)
					var pcy := by + ry * 0.42
					var d := Vector2(x + 0.5 - pcx, y + 0.5 - pcy).length()
					if d < 0.8:
						col = c.m
					elif d < 1.4:
						col = c.m2
			"brow":
				if u > 0.42 and u < 0.62 and t < -0.12:
					col = c.m
			"chevron":
				var ph: float = ((x + 0.5 - left) + (y + 0.5 - by) * 0.8) / (2.0 * rx) * p[1]
				if fposmod(ph, 1.0) < 0.3 and t < 0.45 and u < 0.7:
					col = c.m
			"tilted":
				var ph: float = ((x + 0.5 - left) - (y + 0.5 - by) * 0.7) / (2.0 * rx) * p[1] * 1.4
				if fposmod(ph, 1.0) < 0.32 and u < 0.75 and u > -0.85:
					col = c.m
			"blotch":
				if t < 0.4 and D.hash2(floori(x / 3.0), floori(y / 2.0), 5) < p[1] and D.hash2(x, y, 6) < 0.85:
					col = c.m
			"eyeband":
				var ex: int = m.ex
				var ey: int = m.ey
				if absf((x - ex) + (y - ey) * 0.9) < 0.9 and u > 0.2 and y > ey:
					col = c.m
			"redtail":
				if u < -0.3:
					var k := clampf((-u - 0.3) / 0.5, 0.0, 0.85)
					if (x + y) % 2 == 0 or k > 0.6:
						col = D.mix(col, c.m, k)
			"dashes":
				if t < 0.45 and D.hash2(floori(x / 3.0), y, 41) < 0.22:
					col = c.m
			"rooster":
				var a1 := u - (0.32 - 0.22 * (t + 1.0))
				var a2 := u - (-0.12 - 0.22 * (t + 1.0))
				if (absf(a1) < 0.07 or absf(a2) < 0.07) and t > -0.9 and t < 0.55:
					col = c.m
			"lumps":
				if t < 0.5 and D.hash2(x, y, 23) < 0.2:
					col = c.m
			"facelines":
				if u > 0.5 and t > -0.35 and t < 0.4 and y % 2 == 0:
					col = c.m
	return col


# ---------- decor ----------

static func _outline(g: Array, w: int, h: int, img: Image, col: Color) -> void:
	for y in h:
		for x in w:
			if g[y * w + x] != 0:
				continue
			if (x > 0 and g[y * w + x - 1] != 0) or (x < w - 1 and g[y * w + x + 1] != 0) or (y > 0 and g[(y - 1) * w + x] != 0) or (y < h - 1 and g[(y + 1) * w + x] != 0):
				img.set_pixel(x, y, col)


static func _gen_rock(seed_value: int, arch: bool, tone := "") -> Image:
	var r := D.Rng.new(seed_value * 7919 + 13)
	var w := 40 if arch else 14 + floori(r.next() * 10)
	var h := 24 if arch else 8 + floori(r.next() * 6)
	var pal: Array
	match tone:
		"warm":
			pal = ["#c8ad8a", "#9c7f63", "#715a46", "#33271d", "#86705a"]
		"dark":
			pal = ["#7a7e86", "#5e626a", "#484c54", "#202228", "#54585f"]
		"moss":
			pal = ["#9fae9a", "#728470", "#526351", "#232c23", "#637561"]
		_:
			pal = ["#a3b1c0", "#76859a", "#526073", "#262e3b", "#66748a"] if r.next() < 0.5 else ["#9fae9a", "#728470", "#526351", "#232c23", "#637561"]
	var cw := w + 4
	var chh := h + 4
	var g := []
	g.resize(cw * chh)
	g.fill(0)
	var cx := cw / 2.0
	var base := h + 2.0
	var rx := w / 2.0
	var ry := float(h)
	var p1 := r.next() * 6.0
	var p2 := r.next() * 6.0
	for y in chh:
		for x in cw:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - base) / ry
			if dy > 0:
				continue
			var an := atan2(dy, dx)
			var rr := 1.0 + 0.1 * sin(an * 3.0 + p1) + 0.07 * sin(an * 7.0 + p2)
			var ins := dx * dx + dy * dy <= rr * rr
			if ins and arch:
				var ix := (x + 0.5 - cx) / (rx * 0.45)
				var iy := (y + 0.5 - base) / (ry * 0.6)
				if ix * ix + iy * iy < 1.0:
					ins = false
			if ins:
				g[y * cw + x] = 1
	var img := _img(cw, chh)
	for y in chh:
		for x in cw:
			if g[y * cw + x] == 0:
				continue
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - base) / ry
			var l := -dx * 0.55 - dy * 0.85
			if y == 0 or g[(y - 1) * cw + x] == 0:
				l += 0.35
			var ck := (x + y) % 2 == 0
			var col: String
			if l > 0.85:
				col = pal[0]
			elif l > 0.6:
				col = pal[0] if ck else pal[1]
			elif l > 0.3:
				col = pal[1]
			elif l > 0.1:
				col = pal[1] if ck else pal[2]
			else:
				col = pal[2]
			if D.hash2(x, y, seed_value) < 0.07:
				col = pal[4]
			img.set_pixel(x, y, Color(col))
	_outline(g, cw, chh, img, Color(pal[3]))
	return img


static func _gen_coral(seed_value: int) -> Image:
	var r := D.Rng.new(seed_value * 31 + 7)
	var w := 32
	var h := 28
	var g := []
	g.resize(w * h)
	g.fill(0)
	var sets := [["#c23a5e", "#ea6382", "#ffb3bf", "#5c1530"], ["#d2602a", "#f2884a", "#ffcf94", "#5e2410"], ["#7a4ac8", "#a070e8", "#d8c0ff", "#2e1a5a"], ["#c8a830", "#e8cc50", "#fff0a0", "#5a4a10"]]
	var pal: Array = sets[floori(r.next() * sets.size())]
	_coral_branch(g, w, h, r, w / 2.0, h - 2.0, -PI / 2.0 + (r.next() - 0.5) * 0.2, 7.0, 0)
	var img := _img(w, h)
	for i in w * h:
		var v: int = g[i]
		if v != 0:
			img.set_pixel(i % w, i / w, Color(pal[v - 1]))
	_outline(g, w, h, img, Color(pal[3]))
	return img


static func _coral_set(g: Array, w: int, h: int, xf: float, yf: float, v: int) -> void:
	var x := D.jr(xf)
	var y := D.jr(yf)
	if x < 1 or y < 1 or x >= w - 1 or y >= h - 1:
		return
	var i := y * w + x
	if g[i] == 0 or v < g[i]:
		g[i] = v


static func _coral_branch(g: Array, w: int, h: int, r: D.Rng, x: float, y: float, a: float, length: float, d: int) -> void:
	var i := 0
	while i < length:
		x += cos(a)
		y += sin(a)
		_coral_set(g, w, h, x, y, 1 if d < 2 else 2)
		if d < 1:
			_coral_set(g, w, h, x + 1.0, y, 1)
		i += 1
	if d < 4:
		_coral_branch(g, w, h, r, x, y, a - 0.3 - r.next() * 0.35, length * (0.62 + r.next() * 0.2), d + 1)
		_coral_branch(g, w, h, r, x, y, a + 0.3 + r.next() * 0.35, length * (0.62 + r.next() * 0.2), d + 1)
	else:
		_coral_set(g, w, h, x + cos(a), y + sin(a), 3)


static func decor_img(type: String, seed_value: int, tone := "") -> Image:
	var k := type + str(seed_value) + tone
	if not _decor.has(k):
		var img: Image
		match type:
			"rock":
				img = _gen_rock(seed_value, false, tone)
			"arch":
				img = _gen_rock(seed_value, true, tone)
			"coral":
				img = _gen_coral(seed_value)
			"shell":
				img = sprite_from(SHELL, SHELL_PAL)
			_:
				img = sprite_from(DECOR_ART[type].rows, DECOR_ART[type].pal)
		_decor[k] = {"img": img, "tex": ImageTexture.create_from_image(img)}
	return _decor[k].img


static func decor_tex(type: String, seed_value: int, tone := "") -> ImageTexture:
	decor_img(type, seed_value, tone)
	return _decor[type + str(seed_value) + tone].tex


static func plant_data(type: String, seed_value: int) -> Array:
	var k := type + str(seed_value)
	if _plants.has(k):
		return _plants[k]
	var r := D.Rng.new(seed_value * 131 + 5)
	var out := []
	match type:
		"grass", "weed":
			var n := 5 + floori(r.next() * 4)
			var cols := [Color("#4fa05a"), Color("#3d8a4c"), Color("#6cbf6a"), Color("#2f7442")] if type == "grass" else [Color("#5a7a2a"), Color("#4a6a24"), Color("#7a9a3a")]
			for i in n:
				out.append({"ox": D.jr((r.next() - 0.5) * 10.0), "h": (8 if type == "grass" else 14) + floori(r.next() * 14), "col": cols[floori(r.next() * cols.size())], "ph": r.next() * 6.0})
		"anemone":
			var sets := [["#e8709e", "#ffd0e0", "#b8487a", "#8a2e5a"], ["#a070e0", "#e0c8ff", "#7048b0", "#4e2e86"], ["#f09a4a", "#ffe0b0", "#c0602a", "#8a3e1a"], ["#e8e0d0", "#ffffff", "#b0a898", "#7a7268"]]
			var cs: Array = sets[floori(r.next() * sets.size())]
			for i in 9:
				out.append({"a": lerpf(-1.25, 1.25, i / 8.0) + (r.next() - 0.5) * 0.15, "len": 6 + floori(r.next() * 4), "ph": r.next() * 6.0,
					"body": Color(cs[0]), "tip": Color(cs[1]), "stalk": Color(cs[2]), "dark": Color(cs[3])})
		"reed":
			for i in 4 + floori(r.next() * 3):
				out.append({"ox": D.jr((r.next() - 0.5) * 9.0), "extra": 4 + floori(r.next() * 10), "ph": r.next() * 6.0, "head": r.next() < 0.6})
		_:
			for i in 2 + floori(r.next() * 2):
				out.append({"ox": D.jr((r.next() - 0.5) * 8.0), "h": floori(50.0 + r.next() * 45.0), "ph": r.next() * 6.0})
	_plants[k] = out
	return out


const KELP_DARK := Color("#3d6624")
const KELP_STALK := Color("#4e7d2e")
const KELP_LEAF := Color("#86b84a")
const KELP_TIP := Color("#a6d65e")


## Draws a swaying plant. The target is a CanvasItem (live scene) or an Image (preview).
## surf is the water surface. Reeds grow up through it.
static func draw_plant(target: Object, type: String, x: int, by: int, seed_value: int, flip: bool, t: float, top_limit: int, surf := 0) -> void:
	var data := plant_data(type, seed_value)
	var s := -1 if flip else 1
	var ci := target as CanvasItem
	var img := target as Image
	match type:
		"grass", "weed":
			for b in data:
				var col: Color = b.col
				var bh: int = mini(b.h, by - top_limit)
				var side := 1 if b.ox > 0 else -1
				var amp := 3.0 if type == "grass" else 5.0
				for j in bh:
					var k := float(j) / maxi(1, bh)
					var sx := D.jr(sin(t * 1.3 + b.ph + j * 0.12) * k * k * amp + side * k * 2.0 * s)
					_fill(ci, img, x + b.ox * s + sx, by - j, 1, 1, col)
			return
		"anemone":
			var a0: Dictionary = data[0]
			_fill(ci, img, x - 3, by - 3, 6, 3, a0.stalk)
			_fill(ci, img, x - 3, by - 1, 6, 1, a0.dark)
			_fill(ci, img, x - 2, by - 4, 4, 1, a0.stalk)
			for tn in data:
				var ln: int = tn.len
				for j in ln:
					var sw := sin(t * 2.0 + tn.ph + j * 0.5) * j * 0.12 * s
					var px := D.jr(x - 0.5 + sin(tn.a) * j * 0.95 * s + sw)
					var py := D.jr(by - 4.5 - cos(tn.a) * j * 0.95)
					_fill(ci, img, px, py, 1, 1, tn.tip if j >= ln - 1 else tn.body)
			return
		"reed":
			var stalk := Color("#6a8a3a")
			var dark := Color("#4a6a2a")
			var head := Color("#6a4a2a")
			for b in data:
				var top: int = surf - b.extra
				var px: int = x + b.ox * s
				for py in range(top, by + 1):
					var above := py < surf
					var sx := D.jr(sin(t * 0.9 + b.ph) * 0.6 * float(surf - py) / 10.0) if above else 0
					_fill(ci, img, px + sx, py, 1, 1, stalk if (py % 5 != 0) else dark)
				if b.head:
					var sx := D.jr(sin(t * 0.9 + b.ph) * 0.6 * float(b.extra) / 10.0)
					_fill(ci, img, px + sx, top - 3, 1, 3, head)
					_fill(ci, img, px + sx, top - 4, 1, 1, stalk)
			return
	for st in data:
		var sh: int = st.h
		for j in sh:
			var k := float(j) / sh
			var sx := D.jr(sin(t * 0.8 + st.ph + j * 0.06) * k * 4.0)
			var px: int = x + st.ox * s + sx
			var py := by - j
			if py < top_limit:
				break
			_fill(ci, img, px, py, 2, 1, KELP_DARK if j % 9 == 0 else KELP_STALK)
			if j % 6 == 3 and j > 2:
				var dir := (1 if (j / 6) % 2 == 1 else -1) * s
				_fill(ci, img, px + 2 if dir > 0 else px - 3, py, 3, 1, KELP_LEAF)
				_fill(ci, img, px + 4 if dir > 0 else px - 4, py - 1, 1, 1, KELP_TIP)


static func _fill(ci: CanvasItem, img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	if ci != null:
		ci.draw_rect(Rect2(x, y, w, h), col)
	elif img != null:
		var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, col)


# ---------- angler ----------

## The angler faces right. Hat rows change with the climate. The body rows are shared.
const ANGLER_HATS := {
	"cap": [
		"......oooo......",
		"....oohhhhoo....",
		"...ohhhhhhllo...",
		"..ohhhhhhhhhlo..",
		"..oHhhhhhhhhhho.",
		"..okkkkkkkkkkkoo",
		"..obbssssHHHHHHo",
		"..obbsssssooooo.",
	],
	"beanie": [
		"......olo.......",
		".....ollloo.....",
		"....ohhhhhhho...",
		"...ohhHhhHhhHo..",
		"..ohhHhhHhhHhho.",
		"..okkkkkkkkkkko.",
		"..okKkKkKkKkKko.",
		"..obbssssssssso.",
	],
	"straw": [
		"................",
		"......oooo......",
		".....ohhlho.....",
		"....ohhhhhlo....",
		"....okkkkkko....",
		".oohhhhhhhhhhoo.",
		"oHHHHHHHHHHHHHHo",
		"..obbssssssooo..",
	],
	"hood": [
		"......oooo......",
		"....oohhhhoo....",
		"...ohhhhhhhho...",
		"..ohhhhhhhhhho..",
		"..ohHhhhhhhhhho.",
		"..ohHhwwwwwwwwo.",
		"..ohhwwwwwwwwwwo",
		"..ohhwssssssswo.",
	],
}
const ANGLER_BODY := [
	"..obbssssssbso..",
	"..obbSsssssesso.",
	"..obbSssssssssso",
	"..obbsssssssssSo",
	"...obsssssssmo..",
	"....obSssssso...",
	".....ooSSSSo....",
	"...oojjjjjjjoo..",
	"..oLjjjjzjjjjjo.",
	"..oLjjjjzjjjjJo.",
	"..oLvvjjzjjvvJo.",
	"..oLvVjjzjjvVJo.",
	"..oLjjjjzjjjjJo.",
	"..oJjjjjzjjjjJo.",
	"..oJdddddddddJo.",
	"...oppppPpppo...",
	"...opppPoPppo...",
	"...opppo.opppo..",
	"...oPppo.oPppo..",
	"...offfo.offffo.",
	"..offffo.offffo.",
	"..oooooo.oooooo.",
]
const ANGLER_W := 16
const ANGLER_H := 30
## Where the rod hand and the shoulder sit in the sprite.
const ANGLER_HAND := Vector2(13, 17)
const ANGLER_SHOULDER := Vector2(11, 16)
const OUTFITS := {
	"cold": {"hat": "beanie", "o": "#1e1612", "h": "#c8402e", "H": "#9a2e22", "l": "#f0f0ec", "k": "#a8301e", "K": "#7a2016", "b": "#6a4a32",
		"s": "#eab79c", "S": "#c88a72", "e": "#2a1a17", "m": "#a8584a", "j": "#e8b020", "J": "#b07a10", "L": "#f8d458", "z": "#8a5a10",
		"v": "#d8a018", "V": "#a87410", "d": "#3a2a1e", "p": "#2e3a52", "P": "#222a3c", "f": "#2a2a2e"},
	"warm": {"hat": "cap", "o": "#1e1612", "h": "#2a5a9a", "H": "#1e4070", "l": "#4a7ac0", "k": "#e8e8e4", "K": "#b8b8b8", "b": "#5a3a2a",
		"s": "#eab79c", "S": "#c88a72", "e": "#2a1a17", "m": "#a8584a", "j": "#e8e2d4", "J": "#b8b0a0", "L": "#fafaf6", "z": "#9a9080",
		"v": "#8a7a4a", "V": "#6a5a34", "d": "#4a3a2a", "p": "#5a6a4a", "P": "#46543a", "f": "#4a3020"},
	"hot": {"hat": "straw", "o": "#1e1612", "h": "#e8c878", "H": "#b8964a", "l": "#f8e0a0", "k": "#8a3a2a", "K": "#6a2a1e", "b": "#3a2a1e",
		"s": "#d89a78", "S": "#b07a5a", "e": "#2a1a17", "m": "#8a4a3a", "j": "#3a8ac8", "J": "#2a6a9a", "L": "#6aaae0", "z": "#1e4a70",
		"v": "#3a8ac8", "V": "#2a6a9a", "d": "#6a4a2a", "p": "#e8e0cc", "P": "#c0b8a0", "f": "#6a4a2a"},
	"arctic": {"hat": "hood", "o": "#1e1612", "h": "#e06a2a", "H": "#b04a1a", "l": "#f08a4a", "w": "#ece4d4", "k": "#b04a1a", "K": "#8a3a14", "b": "#e06a2a",
		"s": "#eab79c", "S": "#c88a72", "e": "#2a1a17", "m": "#a8584a", "j": "#e06a2a", "J": "#b04a1a", "L": "#f08a4a", "z": "#5a3a2a",
		"v": "#d05a20", "V": "#a04016", "d": "#2a2a34", "p": "#2a2a34", "P": "#1e1e26", "f": "#5a3a24"},
}


static func angler_tex(climate: String, blink := false) -> ImageTexture:
	var k := "angler_%s_%s" % [climate, blink]
	if not _misc.has(k):
		var pal: Dictionary = OUTFITS.get(climate, OUTFITS.warm)
		var rows: Array = ANGLER_HATS[pal.hat] + ANGLER_BODY
		if blink:
			rows = rows.duplicate()
			rows[9] = rows[9].replace("e", "S")
		_misc[k] = ImageTexture.create_from_image(sprite_from(rows, pal))
	return _misc[k]


# ---------- flags ----------

const FLAG_W := 11
const FLAG_H := 7


static func flag_tex(code: String) -> ImageTexture:
	var k := "flag_" + code
	if not _misc.has(k):
		_misc[k] = ImageTexture.create_from_image(flag_img(code))
	return _misc[k]


static func flag_img(code: String) -> Image:
	var w := FLAG_W
	var h := FLAG_H
	var img := _img(w, h)
	var R := Color("#d42a2a")
	var Wh := Color("#f4f4f4")
	var B := Color("#1e3a8a")
	var G := Color("#1e8a3a")
	var Y := Color("#f2c41a")
	var K := Color("#1a1a1a")
	for y in h:
		for x in w:
			var c := Wh
			match code:
				"no":
					c = R
					if x == 3 or x == 4 or y == 3:
						c = B
					elif x == 2 or x == 5 or y == 2 or y == 4:
						c = Wh
				"sct":
					c = Color("#1e5ab8")
					if absi(x - roundi(y * 10.0 / 6.0)) <= 0 or absi(x - roundi((6 - y) * 10.0 / 6.0)) <= 0:
						c = Wh
				"it":
					c = G if x < 4 else (Wh if x < 7 else R)
				"eg":
					c = R if y < 2 else (Wh if y < 5 else K)
					if y == 3 and x == 5:
						c = Color("#c8a030")
				"jp":
					c = R if Vector2(x - 5, y - 3).length() < 2.2 else Wh
				"cn":
					c = R
					if (x == 1 and y == 1) or (x == 2 and y == 1) or (x == 1 and y == 2) or (x == 2 and y == 2) or (x == 4 and y == 0) or (x == 5 and y == 2) or (x == 4 and y == 3):
						c = Y
				"th":
					c = R if y == 0 or y == 6 else (Wh if y == 1 or y == 5 else Color("#2a2a7a"))
				"au":
					c = Color("#1a2a7a")
					if x < 5 and y < 4 and (x == 2 or y == 1 or x == y + 0 or x == 4 - y):
						c = R if (x == 2 or y == 1) else Wh
					if (x == 8 and y == 1) or (x == 9 and y == 3) or (x == 7 and y == 4) or (x == 8 and y == 5) or (x == 2 and y == 5):
						c = Wh
				"br":
					c = G
					if absf(x - 5.0) / 5.0 + absf(y - 3.0) / 3.0 <= 1.0:
						c = Y
					if Vector2(x - 5, y - 3).length() < 1.6:
						c = Color("#1e3a8a")
				"ca":
					c = R if x < 3 or x > 7 else Wh
					if (x == 5 and y >= 1 and y <= 5) or (y == 3 and x >= 4 and x <= 6) or (y == 2 and (x == 4 or x == 6)):
						c = R
				"us":
					c = R if y % 2 == 0 else Wh
					if x < 5 and y < 4:
						c = B
						if (x + y) % 2 == 0 and x > 0 and y > 0:
							c = Wh
				"mx":
					c = G if x < 4 else (Wh if x < 7 else R)
					if (x == 5 and y == 3) or (x == 5 and y == 2):
						c = Color("#8a5a2a")
				"gl":
					var top := y < 3
					var inside := Vector2(x - 4, y - 3 + 0.5).length() < 2.4
					c = (R if top else Wh) if inside else (Wh if top else R)
				"aq":
					c = Color("#2a6ac8")
					if Vector2((x - 5) * 0.8, y - 3.4).length() < 2.2:
						c = Wh
			img.set_pixel(x, y, c)
	return img


# ---------- bait icons ----------

const BAIT_ART := {
	"worm": {"pal": {"o": "#6a2a3a", "p": "#e87890", "l": "#ffb0c0"}, "rows": [
		"............", ".......oo...", "......oplo..", ".....op.op..", "....op...o..", "...op.......", "..opo.......", ".oplo.......", ".opo........", "..o.........", "............", "............",
	]},
	"shrimp": {"pal": {"o": "#7a2a10", "p": "#f08a4a", "l": "#ffc890", "e": "#1a1a1a"}, "rows": [
		"............", "..oooo......", ".opllpo.....", "oplpplpo....", "oe.oopplo...", ".o...oppo...", "......oplo..", ".......opo..", "......oplo..", ".....oppo...", "....oo.oo...", "............",
	]},
	"spinner": {"pal": {"o": "#3a4048", "s": "#d8e0e8", "l": "#ffffff", "r": "#e03a3a", "k": "#7a8088"}, "rows": [
		".....k......", ".....k......", "....oso.....", "...osls.....", "...osls.....", "....oso.....", ".....k......", ".....r......", ".....k......", "....k.k.....", "....kk......", "............",
	]},
	"jig": {"pal": {"o": "#1a1a1e", "g": "#8a8a92", "l": "#c8c8d0", "y": "#e8c030", "Y": "#f8e070", "k": "#5a5a62"}, "rows": [
		"............", "...oo.......", "..oglo......", "..oggo......", "...ooyY.....", "....yYyY....", "....YyYyy...", ".....yYyY...", "......yy.k..", "........kk..", "............", "............",
	]},
	"plug": {"pal": {"o": "#1a1a1e", "r": "#e8402a", "w": "#f4f0e8", "y": "#e8c030", "k": "#5a5a62", "e": "#1a1a1a"}, "rows": [
		"............", "............", ".ooooooo....", "orrwrrwro...", "oerwrrwrrro.", "orrwrrwro.o.", ".ooooooo....", "..k...k.....", ".kk..kk.....", "............", "............", "............",
	]},
}


static func bait_tex(k: String) -> ImageTexture:
	var key := "bait_" + k
	if not _misc.has(key):
		var a: Dictionary = BAIT_ART[k]
		_misc[key] = ImageTexture.create_from_image(sprite_from(a.rows, a.pal))
	return _misc[key]


# ---------- birds ----------

const BIRD_UP := ["w...w", ".w.w.", "..b.."]
const BIRD_DN := [".....", "wwbww", "w...w"]
const BIG_UP := ["w.....w", ".w...w.", "..wbw..", "...b..."]
const BIG_DN := [".......", "..wbw..", ".ww.ww.", "w.....w"]
const BIRDS := {
	"gull": {"w": "#f2f4f6", "b": "#c8ccd4", "big": false},
	"goose": {"w": "#6a6a62", "b": "#2a2a28", "big": true},
	"kite": {"w": "#6a4a32", "b": "#4a3020", "big": true},
	"eagle": {"w": "#3a2a1e", "b": "#f4f4f0", "big": true},
	"pelican": {"w": "#8a7a68", "b": "#f0ece0", "big": true},
	"ibis": {"w": "#f0f0ec", "b": "#1a1a1a", "big": false},
	"cormorant": {"w": "#1e2226", "b": "#3a3e44", "big": false},
	"egret": {"w": "#f8f8f4", "b": "#e8c040", "big": false},
	"macaw": {"w": "#d82a2a", "b": "#2a6ad8", "big": false},
	"frigate": {"w": "#1a1a20", "b": "#d82a2a", "big": true},
	"raven": {"w": "#14141a", "b": "#2a2a34", "big": false},
	"skua": {"w": "#5a4a3a", "b": "#8a7a64", "big": false},
}


static func bird_tex(kind: String, frame: int) -> ImageTexture:
	var key := "bird_%s_%d" % [kind, frame]
	if not _misc.has(key):
		var b: Dictionary = BIRDS.get(kind, BIRDS.gull)
		var rows: Array = (BIG_UP if frame == 0 else BIG_DN) if b.big else (BIRD_UP if frame == 0 else BIRD_DN)
		_misc[key] = ImageTexture.create_from_image(sprite_from(rows, {"w": b.w, "b": b.b}))
	return _misc[key]
