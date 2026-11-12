class_name D
extends RefCounted
## Static game data and the small math helpers that the simulation and the renderer share.

## Seconds of real time for one day of game time.
const DAY := 420.0
const SAVE_PATH := "user://far-shores-save.json"
const SETTINGS_PATH := "user://far-shores-settings.json"
const M32 := 0xFFFFFFFF
## The market pays this many times the base price of a species.
const SELL_MULT := 1.4
## Scene pixels per meter, for the line length readout.
const PX_PER_M := 4.0

const RODS := [
	{"name": "Bamboo rod", "price": 0, "cast": 0.55, "hook": 0.0, "desc": "Short casts"},
	{"name": "Glass rod", "price": 150, "cast": 0.7, "hook": 0.1, "desc": "Longer casts, more time to strike"},
	{"name": "Carbon rod", "price": 550, "cast": 0.85, "hook": 0.2, "desc": "Long casts, quick strikes"},
	{"name": "Pro rod", "price": 1600, "cast": 1.0, "hook": 0.32, "desc": "Casts across the water"},
]
const REELS := [
	{"name": "Tin reel", "price": 0, "speed": 0.13, "desc": "Slow and steady"},
	{"name": "Brass reel", "price": 130, "speed": 0.17, "desc": "Reels in faster"},
	{"name": "Spin reel", "price": 500, "speed": 0.22, "desc": "Fast retrieve"},
	{"name": "Pro reel", "price": 1450, "speed": 0.28, "desc": "Very fast retrieve"},
]
const LINES := [
	{"name": "Cotton line", "price": 0, "str": 0.5, "desc": "Snaps under big fish"},
	{"name": "Nylon line", "price": 190, "str": 0.75, "desc": "Holds most fish"},
	{"name": "Braid line", "price": 680, "str": 1.0, "desc": "Holds big fish"},
	{"name": "Titan line", "price": 2000, "str": 1.35, "desc": "Holds legends"},
]
const GEAR := {"rod": RODS, "reel": REELS, "line": LINES}
const GEAR_KEYS: Array[String] = ["rod", "reel", "line"]

const BAITS := {
	"worm": {"name": "Worm", "price": 0, "desc": "Most fish take a worm", "sink": 1.0},
	"shrimp": {"name": "Shrimp", "price": 60, "desc": "Sea fish love it", "sink": 1.0},
	"spinner": {"name": "Spinner", "price": 140, "desc": "Flashes when reeled. Hunters chase it", "sink": 0.9},
	"jig": {"name": "Deep jig", "price": 250, "desc": "Sinks fast to the bottom", "sink": 2.2},
	"plug": {"name": "Big plug", "price": 550, "desc": "Small fish ignore it. Big fish do not", "sink": 0.7},
}
const BAIT_KEYS: Array[String] = ["worm", "shrimp", "spinner", "jig", "plug"]

const RARITY := [
	{"name": "Common", "w": 10.0, "col": "#b9c5db"},
	{"name": "Uncommon", "w": 5.0, "col": "#75d78d"},
	{"name": "Rare", "w": 1.8, "col": "#58b4ff"},
	{"name": "Legendary", "w": 0.32, "col": "#f7c243"},
	# Special visitors never spawn by weight. The game sends one in now and then.
	{"name": "Special", "w": 0.0, "col": "#ff7ad9"},
]

const WEATHER := {
	"clear": {"name": "Clear", "light": 1.0, "bite": 1.0, "clouds": 2},
	"cloud": {"name": "Cloudy", "light": 0.86, "bite": 1.1, "clouds": 6},
	"rain": {"name": "Rain", "light": 0.72, "bite": 1.3, "clouds": 9},
	"snow": {"name": "Snow", "light": 0.82, "bite": 1.1, "clouds": 7},
	"fog": {"name": "Fog", "light": 0.8, "bite": 1.15, "clouds": 3},
}

## Local hour, tint and light. The tint multiplies the whole scene.
const HOURS := [[0.0, "#33406f", 0.28], [4.5, "#33406f", 0.28], [6.0, "#d8a0a0", 0.6], [7.5, "#ffffff", 1.0], [17.5, "#ffffff", 1.0], [19.0, "#f0a882", 0.68], [20.5, "#33406f", 0.28], [24.0, "#33406f", 0.28]]

const ACH := [
	{"id": "first", "name": "First Bite", "desc": "Land your first fish", "r": 15},
	{"id": "ten", "name": "Getting the Hang", "desc": "Land 10 fish", "r": 40},
	{"id": "fifty", "name": "Seasoned Angler", "desc": "Land 50 fish", "r": 150},
	{"id": "hundred", "name": "Old Salt", "desc": "Land 200 fish", "r": 400},
	{"id": "species10", "name": "Field Guide", "desc": "Find 10 species", "r": 80},
	{"id": "species30", "name": "Naturalist", "desc": "Find 30 species", "r": 250},
	{"id": "species60", "name": "Ichthyologist", "desc": "Find 60 species", "r": 600},
	{"id": "all", "name": "Every Fish in the Sea", "desc": "Find every species", "r": 3000},
	{"id": "place", "name": "Local Expert", "desc": "Find every species in one place", "r": 200},
	{"id": "travel", "name": "Passport Stamp", "desc": "Travel to a new place", "r": 30},
	{"id": "travel5", "name": "Globetrotter", "desc": "Visit 6 places", "r": 200},
	{"id": "world", "name": "Around the World", "desc": "Visit every place", "r": 800},
	{"id": "rare", "name": "Rare Find", "desc": "Land a rare fish", "r": 60},
	{"id": "legend", "name": "Legend", "desc": "Land a legendary fish", "r": 300},
	{"id": "legend5", "name": "Myth Maker", "desc": "Land 5 different legends", "r": 1500},
	{"id": "night", "name": "Night Owl", "desc": "Land a fish at night", "r": 30},
	{"id": "dawn", "name": "Early Riser", "desc": "Land a fish at dawn", "r": 30},
	{"id": "rain", "name": "Wet Weather Gear", "desc": "Land a fish in the rain or snow", "r": 40},
	{"id": "release", "name": "Catch and Release", "desc": "Release 10 fish", "r": 80},
	{"id": "record", "name": "Specimen", "desc": "Land a fish in the top tenth of its size range", "r": 100},
	{"id": "heavy", "name": "Heavyweight", "desc": "Land a fish over 100 kg", "r": 300},
	{"id": "snap", "name": "The One That Got Away", "desc": "Snap a line", "r": 10},
	{"id": "gear", "name": "Fully Rigged", "desc": "Buy the best rod, reel and line", "r": 500},
	{"id": "tackle", "name": "Tackle Box", "desc": "Own every bait", "r": 150},
	{"id": "rich", "name": "Fishmonger", "desc": "Earn 10,000 coins", "r": 500},
	{"id": "visitor", "name": "Rare Visitor", "desc": "Land a special visitor", "r": 300},
	{"id": "visitor5", "name": "Guest Book", "desc": "Land 5 different special visitors", "r": 2000},
	{"id": "contest", "name": "Contender", "desc": "Enter a fishing contest", "r": 25},
	{"id": "champion", "name": "Champion", "desc": "Win a fishing contest", "r": 150},
	{"id": "champion5", "name": "World Champion", "desc": "Win contests in 5 places", "r": 1000},
]


## Rounds like JavaScript Math.round: halves go toward positive infinity.
static func jr(v: float) -> int:
	return floori(v + 0.5)


static func hash2(x: int, y: int, s: int) -> float:
	var h: int = ((x * 374761393) & M32) ^ ((y * 668265263) & M32) ^ (((s + 1) * 982451653) & M32)
	h = ((h ^ (h >> 13)) * 1274126177) & M32
	h = h ^ (h >> 16)
	return float(h) / 4294967296.0


## Smooth value noise in one dimension, from 0 to 1.
static func noise1(x: float, s: int) -> float:
	var i := floori(x)
	var f := x - i
	var a := hash2(i, 0, s)
	var b := hash2(i + 1, 0, s)
	var t := f * f * (3.0 - 2.0 * f)
	return a + (b - a) * t


## Mixes two colors and rounds each channel to 8 bits.
static func mix(a: Color, b: Color, t: float) -> Color:
	var c := Color8(jr(a.r8 + (b.r8 - a.r8) * t), jr(a.g8 + (b.g8 - a.g8) * t), jr(a.b8 + (b.b8 - a.b8) * t))
	c.a = a.a + (b.a - a.a) * t
	return c


static func dark(c: Color, t: float) -> Color:
	return mix(c, Color(0, 0, 0, c.a), t)


static func light(c: Color, t: float) -> Color:
	return mix(c, Color(1, 1, 1, c.a), t)


## Local hour at a place for a UTC hour.
static func local_hours(utc: float, tz: float) -> float:
	return fposmod(utc + tz, 24.0)


static func sky_at(h: float) -> Dictionary:
	for i in HOURS.size() - 1:
		var a: Array = HOURS[i]
		var b: Array = HOURS[i + 1]
		if h >= a[0] and h <= b[0]:
			var span: float = b[0] - a[0]
			var k: float = (h - a[0]) / (span if span != 0.0 else 1.0)
			return {"tint": mix(Color(a[1]), Color(b[1]), k), "light": lerpf(a[2], b[2], k)}
	return {"tint": Color.WHITE, "light": 1.0}


static func phase_of(h: float) -> String:
	if h >= 5.0 and h < 7.5:
		return "Dawn"
	if h >= 7.5 and h < 17.5:
		return "Day"
	if h >= 17.5 and h < 20.5:
		return "Dusk"
	return "Night"


## How well a species' active time matches the local hour. 1 is a match.
static func time_factor(when: String, h: float) -> float:
	var p := phase_of(h)
	match when:
		"day":
			return 1.0 if p == "Day" else (0.5 if p == "Dawn" or p == "Dusk" else 0.12)
		"night":
			return 1.0 if p == "Night" else (0.5 if p == "Dusk" or p == "Dawn" else 0.1)
		"dawn":
			return 1.0 if p == "Dawn" else (0.4 if p == "Dusk" else 0.12)
		"dusk":
			return 1.0 if p == "Dusk" else (0.4 if p == "Dawn" else 0.12)
		"twilight":
			return 1.0 if p == "Dawn" or p == "Dusk" else (0.3 if p == "Night" else 0.15)
	return 1.0


static func time_label(when: String) -> String:
	match when:
		"day":
			return "Day"
		"night":
			return "Night"
		"dawn":
			return "Dawn"
		"dusk":
			return "Dusk"
		"twilight":
			return "Dawn and dusk"
	return "Any time"


static func depth_label(d: Array) -> String:
	var mid := (float(d[0]) + float(d[1])) * 0.5
	if d[0] >= 0.75:
		return "Bottom"
	if mid < 0.3:
		return "Surface"
	if mid < 0.62:
		return "Mid water"
	return "Deep"


static func fmt_kg(w: float) -> String:
	if w < 1.0:
		return "%d g" % roundi(w * 1000.0)
	if w < 10.0:
		return "%.1f kg" % w
	return "%d kg" % roundi(w)


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## The xorshift32 generator from the original engine. Seeds give the same shapes every time.
class Rng:
	var s: int

	func _init(seed_value: int) -> void:
		s = seed_value & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s ^ (s << 13)) & 0xFFFFFFFF
		s = s ^ (s >> 17)
		s = (s ^ (s << 5)) & 0xFFFFFFFF
		return float(s) / 4294967296.0

	func range_f(a: float, b: float) -> float:
		return a + (b - a) * next()

	func range_i(a: int, b: int) -> int:
		return a + floori(next() * (b - a + 1))
