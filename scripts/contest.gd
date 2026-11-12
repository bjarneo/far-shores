class_name Contest
extends RefCounted
## A fishing contest against 3 rival anglers. The rivals fish from small boats, or from holes in
## the ice, and they hook the same fish that the player sees. The contest lasts LENGTH seconds.
## Rivals do not take legendary fish or special visitors.
##
## States: "offer" before the player joins, "on" while the clock runs, "horn" while the last fights
## end, "results" while the result card shows, "leave" while the rivals go home, and "done".

const LENGTH := 180.0
const RIVALS := 3
const KINDS := {
	"bag": {"name": "Heaviest bag", "rule": "The heaviest total catch wins."},
	"big": {"name": "Biggest fish", "rule": "The single heaviest fish wins."},
	"count": {"name": "Most fish", "rule": "The most fish landed wins."},
}
const KIND_KEYS: Array[String] = ["bag", "big", "count"]
## Rival names by flag. The first rival is a local when the place has a flag in this list.
const NAMES := {
	"no": ["Ingrid", "Ola", "Sigrid"], "sct": ["Morag", "Callum", "Isla"], "it": ["Giulia", "Marco", "Rosa"],
	"jp": ["Yuki", "Kenji", "Aiko"], "ca": ["Claire", "Wes", "Mona"], "us": ["Dolly", "Hank", "Ray"],
	"eg": ["Nour", "Karim", "Hoda"], "cn": ["Lan", "Wei", "Mei"], "th": ["Nok", "Somchai", "Ploy"],
	"br": ["Ana", "Tiago", "Bia"], "au": ["Shaz", "Mick", "Kylie"], "mx": ["Lupe", "Chuy", "Rocio"],
	"gl": ["Aviaja", "Hans", "Nuka"],
}
const COATS := ["#c84a3a", "#3a8a4a", "#7a4ab0", "#2a8aa0", "#d08a2a", "#c84a8a", "#4a5ac8"]
const HATS := ["#e8e4d8", "#2a2a30", "#d8b030", "#3a6ac8", "#b03a3a"]
## The boat of the rivals at each place. Other places use a dinghy.
const BOATS := {"ness": "row", "kootenay": "row", "giza": "canoe", "guilin": "canoe", "ayutthaya": "canoe", "amazon": "canoe",
	"ilulissat": "kayak", "antarctica": "ice"}
## The prize for 1st, 2nd and 3rd place, as a multiple of the entry fee.
const PRIZE_K := [6.0, 3.0, 1.5]

var kind := "bag"
var fee := 20
var loc := ""
var boat := "dinghy"
var st := "offer"
var t := LENGTH
var rivals: Array = []
var me := {"score": 0.0, "n": 0}
var _horn_t := 0.0


static func make_offer(loc_key: String, P: Dictionary, done: int) -> Contest:
	var c := Contest.new()
	c.loc = loc_key
	var idx := maxi(0, Places.ORDER.find(loc_key))
	c.kind = KIND_KEYS[(done + idx) % KIND_KEYS.size()]
	c.fee = maxi(20, snappedi(P.price * 0.06, 5))
	c.boat = BOATS.get(loc_key, "dinghy")
	var flags: Array = NAMES.keys()
	var used := {}
	# Each rival gets its own coat, hat and skin color.
	var coats := COATS.duplicate()
	coats.shuffle()
	var hats := HATS.duplicate()
	hats.shuffle()
	var skins := [0, 1, 2, 3]
	skins.shuffle()
	for i in RIVALS:
		var fl: String = P.flag if i == 0 and NAMES.has(P.flag) else flags[randi() % flags.size()]
		var nm: String = NAMES[fl][randi() % NAMES[fl].size()]
		while used.has(nm):
			fl = flags[randi() % flags.size()]
			nm = NAMES[fl][randi() % NAMES[fl].size()]
		used[nm] = true
		# Rivals get better in the places that cost more to reach.
		var skill := clampf(0.7 + 0.35 * idx / 13.0 + randf_range(-0.12, 0.15), 0.55, 1.3)
		c.rivals.append({"name": nm, "flag": fl, "skill": skill, "coat": coats[i % coats.size()], "hat": hats[i % hats.size()],
			"skin": skins[i % skins.size()], "rs": 18.0, "x": 0.0, "hx": 0.0, "face": -1, "st": "row", "t": 0.0, "lx": 0.0, "ly": 0.0, "ty": 0.0,
			"fid": -1, "fk": 0.0, "fdur": 1.0, "fx0": 0.0, "fy0": 0.0, "score": 0.0, "n": 0, "catch": {}, "chk": 0.0,
			"bend": 0.0, "mark": 0.0, "cast": 0.0, "ph": randf() * 6.0, "gone": false})
	return c


func start(g: Game) -> void:
	st = "on"
	t = LENGTH
	_homes(g)
	for i in rivals.size():
		var r: Dictionary = rivals[i]
		if boat == "ice":
			r.x = r.hx
			r.st = "idle"
			r.t = randf_range(0.5, 2.0)
		else:
			r.x = g.W + 24.0 + i * 26.0
			# Every rival reaches its spot in about 5 seconds, even on a wide screen.
			r.rs = maxf(18.0, (r.x - r.hx) / 5.0)
			r.st = "row"


## Spreads the rivals over the water. They keep clear of the scoreboard on a short screen.
func _homes(g: Game) -> void:
	var x0 := g.PX + 34.0
	var x1 := maxf(x0 + 30.0, g.W - 12.0 - g.rival_margin)
	for i in rivals.size():
		var r: Dictionary = rivals[i]
		r.hx = roundf(lerpf(x0, x1, (i + 0.5) / rivals.size()))
		r.face = -1 if r.hx > g.PX + 70.0 else 1


## The world changed size, for example when the phone turned. The rivals move to new spots.
func relayout(g: Game, old_w: float) -> void:
	if st == "offer" or st == "done":
		return
	_homes(g)
	var k := g.W / maxf(1.0, old_w)
	for r in rivals:
		if r.st != "row" and r.st != "away":
			r.x = r.hx
		r.lx = clampf(r.lx * k, g.PX + 4.0, g.W - 4.0)
		r.fx0 *= k
		r.ly = clampf(r.ly, g.water_top(r.lx) + 1.0, float(g.bed_at(r.lx)) - 2.0)
		r.ty = clampf(r.ty, g.water_top(r.lx) + 1.0, float(g.bed_at(r.lx)) - 2.0)
		if r.st == "sink" or r.st == "wait":
			r.lx = r.x + r.face * 7.0 if boat == "ice" else clampf(r.lx, g.PX + 8.0, g.W - 6.0)


## Adds a fish that the player landed during the contest.
func add_mine(w: float) -> void:
	me.n += 1
	me.score = _add(me.score, w)


func _add(score: float, w: float) -> float:
	match kind:
		"big":
			return maxf(score, w)
		"count":
			return score + 1.0
	return score + w


## The text of a score, in kilograms or as a count.
func fmt(score: float) -> String:
	if kind == "count":
		return str(int(score))
	if score <= 0.0:
		return "0 kg"
	return D.fmt_kg(score)


## Everyone in order, best first. A tie goes to the player.
func standings() -> Array:
	var rows := [{"name": "You", "flag": "", "score": me.score, "n": me.n, "me": true}]
	for r in rivals:
		rows.append({"name": r.name, "flag": r.flag, "score": r.score, "n": r.n, "me": false})
	rows.sort_custom(func(a, b): return a.score > b.score or (a.score == b.score and a.me and not b.me))
	return rows


func prize_for(rank: int) -> int:
	if rank < 1 or rank > PRIZE_K.size():
		return 0
	return roundi(fee * PRIZE_K[rank - 1])


func update(g: Game, dt: float) -> void:
	match st:
		"on":
			t -= dt
			if t <= 0.0:
				t = 0.0
				st = "horn"
				_horn_t = 0.0
				g.contest_horn()
		"horn":
			# Fights that started before the horn still count. Wait for them, but not for ever.
			_horn_t += dt
			var busy: bool = g.phase == "fight" or g.phase == "land"
			for r in rivals:
				if r.st == "fight" or r.st == "land":
					busy = true
			if not busy or _horn_t > 25.0:
				st = "results"
				g.contest_results()
		"leave":
			var all_gone := true
			for r in rivals:
				if not r.gone:
					all_gone = false
			if all_gone:
				st = "done"
	for i in rivals.size():
		_rival(g, rivals[i], i, dt)


func _rival(g: Game, r: Dictionary, i: int, dt: float) -> void:
	if r.gone:
		return
	r.ph += dt
	r.bend = maxf(0.0, r.bend - dt * 3.0)
	r.mark = maxf(0.0, r.mark - dt)
	r.cast = maxf(0.0, r.cast - dt)
	var open := st == "on"
	match r.st:
		"row":
			var d: float = r.hx - r.x
			r.x += signf(d) * minf(absf(d), r.rs * dt)
			if absf(d) < 0.5:
				r.x = r.hx
				r.st = "idle"
				r.t = randf_range(0.3, 1.2)
		"idle":
			if st == "leave":
				r.st = "away"
				r.t = 0.0
			elif open:
				r.t -= dt
				if r.t <= 0.0:
					r.st = "cast"
					r.t = 0.55
					r.cast = 0.55
		"cast":
			r.t -= dt
			if r.t <= 0.0:
				var reach := randf_range(10.0, 30.0)
				# On the ice the line goes down a hole just in front of the angler.
				r.lx = r.x + r.face * 7.0 if boat == "ice" else clampf(r.x + r.face * reach, g.PX + 8.0, g.W - 6.0)
				r.ly = g.water_top(r.lx) + 1.0
				var top := g.water_top(r.lx) + 6.0
				var bot := float(g.bed_at(r.lx)) - 4.0
				r.ty = lerpf(top, bot, randf_range(0.3, 0.95)) if bot > top else top
				r.st = "sink"
				g.rival_splash(r.lx)
		"sink":
			r.ly = minf(r.ty, r.ly + 16.0 * dt)
			if r.ly >= r.ty:
				r.st = "wait"
				r.t = 0.0
				r.chk = randf()
		"wait":
			if not open:
				r.st = "reel"
				return
			r.t += dt
			r.chk -= dt
			if r.chk <= 0.0:
				r.chk = 1.0
				var f = _pick(g, r)
				if f != null and randf() < 0.2 * r.skill * D.WEATHER[g.S.wx].bite:
					f.st = "rlook"
					f.t = 0.0
					r.fid = f.id
					r.st = "lure_in"
					r.t = 0.0
			if r.t > 15.0:
				r.st = "reel"
		"lure_in":
			var f = g.fish_by_id(r.fid)
			if f == null or f.st != "rlook":
				r.fid = -1
				r.st = "wait" if open else "reel"
				return
			r.t += dt
			var m := g.mouth_of(f)
			var to := Vector2(r.lx, r.ly) - m
			f.tx = f.x + to.x
			f.ty = f.y + to.y
			if absf(to.x) > 1.5:
				f.face = 1 if to.x > 0.0 else -1
			if to.length() < 3.0:
				_hook(r, f)
			elif r.t > 7.0 or not open:
				f.st = "swim"
				f.wt = 0.0
				f.cool = 4.0
				r.fid = -1
				r.st = "wait" if open else "reel"
		"fight":
			var f = g.fish_by_id(r.fid)
			if f == null:
				r.fid = -1
				r.st = "idle"
				return
			_fight(g, r, f, i, dt)
		"land":
			r.t += dt
			if r.t > 1.4:
				r.catch = {}
				r.st = "idle"
				r.t = randf_range(0.5, 1.5)
		"reel":
			r.ly -= 24.0 * dt
			if r.ly <= g.water_top(r.lx):
				r.st = "idle"
				r.t = randf_range(0.3, 1.0)
		"away":
			r.t += dt
			if boat == "ice":
				if r.t > 0.6:
					r.gone = true
			else:
				r.x += r.rs * dt
				if r.x > g.W + 30.0:
					r.gone = true


## The closest free fish to a rival's bait. Rivals leave legends, visitors and the player's fish alone.
func _pick(g: Game, r: Dictionary):
	var best = null
	var bd := 50.0
	for f in g.fish:
		if f.st != "swim" or f.id == g.lure.eng or f.cool > 0.0 or f.id == g.visitor_id:
			continue
		if Species.ALL[f.sp].r >= 3:
			continue
		var d := g.mouth_of(f).distance_to(Vector2(r.lx, r.ly))
		if d < bd:
			bd = d
			best = f
	return best


func _hook(r: Dictionary, f: Dictionary) -> void:
	var A: Dictionary = Species.ALL[f.sp]
	f.st = "rhook"
	r.st = "fight"
	r.fk = 0.0
	r.fx0 = f.x
	r.fy0 = f.y
	var size_k := pow(f.w / maxf(0.01, (A.w[0] + A.w[1]) * 0.5), 0.3)
	r.fdur = clampf((2.5 + 4.5 * A.fight * size_k) / r.skill, 2.0, 12.0)
	r.mark = 0.9


func _fight(g: Game, r: Dictionary, f: Dictionary, i: int, dt: float) -> void:
	r.fk += dt
	r.bend = 1.0
	var k := clampf(r.fk / r.fdur, 0.0, 1.0)
	var hs := g.fish_half(f)
	# The fish thrashes and comes closer to the boat as it tires.
	var near := Vector2(r.x + r.face * 4.0, g.water_top(r.x) + hs.y + 3.0)
	var p := Vector2(r.fx0, r.fy0).lerp(near, k * k)
	p += Vector2(sin(r.fk * 3.1 + i) * 8.0 * (1.0 - k), sin(r.fk * 4.7 + i) * 3.0)
	p.x = clampf(p.x, g.PX + 4.0, g.W - hs.x)
	p.y = clampf(p.y, g.water_top(p.x) + hs.y, g.bed_at(p.x) - hs.y + 1.0)
	var prev: float = f.x
	f.x = lerpf(f.x, p.x, minf(1.0, dt * 5.0))
	f.y = lerpf(f.y, p.y, minf(1.0, dt * 5.0))
	if absf(f.x - prev) > 0.05:
		f.face = 1 if f.x > prev else -1
	f.anim += dt * 6.0
	var m := g.mouth_of(f)
	r.lx = m.x
	r.ly = m.y
	if f.y < g.SURF + 10.0 and randf() < dt * 1.5:
		g._splash(f.x, 2)
	if k < 1.0:
		return
	if randf() < 0.1 / r.skill:
		# It got away.
		f.st = "flee"
		f.t = 1.5
		f.cool = 10.0
		f.tx = clampf(f.x - r.face * 60.0, -40.0, g.W + 40.0)
		f.ty = f.y + 10.0
		r.fid = -1
		r.st = "idle"
		r.t = 1.0
		return
	g.fish.erase(f)
	r.fid = -1
	r.catch = {"sp": f.sp, "sz": f.sz, "w": f.w}
	r.st = "land"
	r.t = 0.0
	r.n += 1
	r.score = _add(r.score, f.w)
	var txt := "+1" if kind == "count" else "+%.1f" % f.w
	g.pops.append({"x": r.x, "y": g.SURF - 36.0, "txt": txt, "t": 0.0, "col": Color("#9ad8ff")})
	g._splash(f.x, 4)
	g.synth.splash_small()
