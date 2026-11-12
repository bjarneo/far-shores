extends Control
## Builds the scene. The world renders at low resolution into a SubViewport. SceneDisplay shows
## it scaled up with nearest filtering. The HUD and the world map sit on top.
##
## Debug flags after "--": --loc=KEY, --hour=H, --wx=KEY, --cast=POWER, --fresh, --coins=N,
## --shot=PATH (saves a screenshot and quits), --frames=N, --sheet=PATH (saves every fish sprite), --map,
## --perf (prints the frame rate and the script time every 5 seconds), --contest (joins a contest),
## --visit (sends in the special visitor now).

var game: Game
var synth: Synth
var vp: SubViewport
var bg: ColorRect
var tint: ColorRect
var display: SceneDisplay
var hud: Hud
var fade: ColorRect
var _args := {}
var _bedtex: ImageTexture


func _ready() -> void:
	_parse_args()
	if _args.has("shot") or _args.has("tour"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_setup_window()
	if OS.has_feature("web"):
		_web_setup()
	if _args.has("fresh"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(D.SAVE_PATH))
	synth = Synth.new()
	add_child(synth)
	game = Game.new()
	game.synth = synth
	add_child(game)

	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(320, 200)
	add_child(vp)
	bg = ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/scene.gdshader")
	bg.material = m
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	vp.add_child(bg)
	var sky := SkyView.new()
	sky.g = game
	vp.add_child(sky)
	var sv := SceneView.new()
	sv.g = game
	vp.add_child(sv)
	tint = ColorRect.new()
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = mul
	tint.mouse_filter = MOUSE_FILTER_IGNORE
	vp.add_child(tint)
	var ov := OverlayView.new()
	ov.g = game
	vp.add_child(ov)

	display = SceneDisplay.new()
	display.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	display.g = game
	display.vp = vp
	add_child(display)
	hud = Hud.new()
	add_child(hud)
	hud.build(game, display, self)
	fade = ColorRect.new()
	fade.color = Color(UI.BG, 0.0)
	fade.mouse_filter = MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fade)

	game.world_resized.connect(_on_world_resized)
	await get_tree().process_frame
	await get_tree().process_frame
	game.ui_scale = hud.ui_scale()
	game.start(hud.size, hud.top_inset(), hud.bottom_inset())
	hud._show_banner()
	print("Far Shores is ready after %d ms" % Time.get_ticks_msec())
	_apply_debug()
	if _args.has("sheet"):
		_save_sheet(_args.sheet)
	if _args.has("icon"):
		for n in [64, 128, 192, 512]:
			_icon(n).save_png("%s/icon-%d.png" % [_args.icon, n])
	if _args.has("tour"):
		var dir: String = _args.tour
		for k in Places.ORDER:
			game.S.unlocked[k] = true
			if k != game.loc:
				game.travel(k)
			game.S.utc = fposmod(float(_args.get("hour", "11")) - game.place.tz, 24.0)
			game.S.wx = _args.get("wx", "clear")
			game.S.wx_t = 999.0
			game._make_clouds()
			game._populate()
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, k])
		get_tree().quit()
		return
	if _args.has("shot"):
		var frames := int(_args.get("frames", "40"))
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_args.shot)
		get_tree().quit()


var _auto_t := 0.0
var _auto_hold := 0.0
var _auto_log := {}


func _autoplay(dt: float) -> void:
	_auto_t += dt
	if game.contest != null and game.contest.st == "results":
		var rows: Array = game.cup_result.rows.map(func(r): return "%s %s" % [r.name, game.contest.fmt(r.score)])
		print("CONTEST %s  place %d  prize %d  %s" % [game.contest.kind, game.cup_result.rank, game.cup_result.prize, ", ".join(rows)])
		game.collect_contest()
	match game.phase:
		"idle":
			if game.holding:
				game.action_up()
			_auto_hold = randf_range(0.3, 1.1)
			game.action_down()
		"aim":
			_auto_hold -= dt
			if _auto_hold <= 0.0:
				game.action_up()
				_auto_hold = 0.0
		"sink":
			var f = game.fish_by_id(game.lure.eng)
			if f != null and f.st == "bite" and randf() < dt * 6.0:
				game.action_down()
				game.action_up()
			elif f == null and game.lure.rest:
				_auto_hold += dt
				if _auto_hold > 6.0 and not game.holding:
					game.action_down()
			elif f == null and game.holding and _auto_hold > 6.0:
				pass
			if game.phase == "idle":
				_auto_hold = 0.0
		"fight":
			var want: bool = game.fight.ten < 0.82 and game.fight.strain <= 0.0 and game.fight.run <= 0.0
			if game.fight.slack > 1.5:
				want = true
			if want and not game.holding:
				game.action_down()
			elif not want and game.holding:
				game.action_up()
		"show":
			print("LANDED %s %.1f kg  price %d  coins %d  t=%.0f" % [game.catch_info.name, game.catch_info.w, game.catch_info.price, game.S.coins, _auto_t])
			if game.holding:
				game.action_up()
			game.sell_catch()
			_auto_hold = 0.0


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var i := s.find("=")
		if i >= 0:
			_args[s.substr(0, i)] = s.substr(i + 1)
		else:
			_args[s] = "1"


func _apply_debug() -> void:
	if _args.has("coins"):
		game.S.coins = int(_args.coins)
	if _args.has("loc") and Places.ALL.has(_args.loc):
		game.S.unlocked[_args.loc] = true
		if _args.loc != game.loc:
			game.travel(_args.loc)
	if _args.has("hour"):
		game.S.utc = fposmod(float(_args.hour) - game.place.tz, 24.0)
	if _args.has("wx"):
		game.S.wx = _args.wx
		game.S.wx_t = 999.0
		game._make_clouds()
	if _args.has("cast"):
		game.phase = "aim"
		game.aim_t = 1.0
		game.power = float(_args.cast)
		game.holding = false
		game._update_rod(0.1)
		game._cast()
	if _args.has("speed") and not _args.has("autoplay"):
		Engine.time_scale = float(_args.speed)
	if _args.has("visit"):
		game._visit_t = 0.0
	if _args.has("contest"):
		game.S.coins = maxi(game.S.coins, game.contest_offer().fee)
		game.join_contest()
	if _args.has("map"):
		hud.open_map()
	if _args.has("panel"):
		hud._set_panel(_args.panel)
	if _args.has("book"):
		for k in Species.ALL:
			if randf() < 0.5:
				game.S.book[k] = {"n": randi_range(1, 9), "best": Species.ALL[k].w[1] * 0.6, "len": 50.0}
	if _args.has("autoplay"):
		Engine.time_scale = float(_args.get("speed", "3"))
		game.toast.connect(func(t, k): print("TOAST [%s] %s" % [k, t]))
	if _args.has("fight") or _args.has("catch"):
		var f = null
		for x in game.fish:
			if _args.has("sp") and x.sp != _args.sp:
				continue
			f = x
			break
		if f == null and _args.has("sp"):
			game._spawn(true, _args.sp)
			f = game.fish[-1]
		if f != null:
			game.lure.st = "water"
			game.lure.x = f.x
			game.lure.y = f.y
			game.phase = "sink"
			game._hook(f)
			if _args.has("catch"):
				game._land(f)
				game.land_t = 0.7
			else:
				game.fight.d = 120.0
				game.holding = true


## Paints the app icon: a sunset over the sea, a mountain, and a salmon on the line.
func _icon(n: int) -> Image:
	var px := 32
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in px:
		for x in px:
			var corner := (x < 2 or x > px - 3) and (y < 2 or y > px - 3)
			if corner and not ((x == 1 or x == px - 2) and (y == 1 or y == px - 2)):
				continue
			if (x == 0 or x == px - 1) and (y == 0 or y == px - 1):
				continue
			var c: Color
			if y < 15:
				var k := y / 15.0
				c = D.mix(Color("#3b4f8f"), Color("#f2a46a"), k * k)
				if (x + y) % 2 == 0 and fmod(k * 6.0, 1.0) > 0.8:
					c = D.mix(c, Color("#f2a46a"), 0.2)
			else:
				var k := (y - 15) / 17.0
				c = D.mix(Color("#2a7a90"), Color("#0b2238"), k)
			if y < 15 and y > 15 - (6 - absi(x - 9) * 0.7) and x > 2 and x < 17:
				c = Color("#3a4660")
			if Vector2(x - 22, y - 9).length() < 3.2 and y < 15:
				c = Color("#fff0c0")
			img.set_pixel(x, y, c)
	var fish := Sprites.fish_image("salmon", 0, 0, "")
	var m := Sprites.mask("salmon", 0)
	var fw := fish.get_width()
	var fh := fish.get_height()
	var fx := (px - fw) / 2
	var fy := 22 - fh / 2
	var mx: int = fx + m.mx - 1
	var my: int = fy + m.my + 1
	for y in range(1, my):
		img.set_pixel(mx, y, Color("#e8e4d8") if y < 15 else Color("#b8d0d8"))
	img.blend_rect(fish, Rect2i(0, 0, fw, fh), Vector2i(fx, fy))
	img.resize(n, n, Image.INTERPOLATE_NEAREST)
	return img


func _save_sheet(path: String) -> void:
	var keys: Array = Species.ALL.keys()
	if _args.has("only"):
		keys = Array(_args.only.split(","))
	var big := keys.size() <= 16
	var cell := Vector2i(400, 150) if big else Vector2i(230, 84)
	var cols := 4 if big else 7
	var rows := ceili(keys.size() / float(cols))
	var sheet := Image.create_empty(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#1b466c"))
	for i in keys.size():
		var img := Sprites.fish_image(keys[i], 2, 0, "")
		var sc := 6 if big else 3
		while sc > 1 and (img.get_width() * sc > cell.x - 4 or img.get_height() * sc > cell.y - 4):
			sc -= 1
		img.resize(img.get_width() * sc, img.get_height() * sc, Image.INTERPOLATE_NEAREST)
		var cx := (i % cols) * cell.x + (cell.x - img.get_width()) / 2
		var cy := (i / cols) * cell.y + (cell.y - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(cx, cy))
	sheet.save_png(path)


## Keeps the phone screen on while the player fishes, because a bite can take a while.
## The lock ends 2 minutes after the last touch, and when the page is hidden.
const WAKE_JS := """
(function () {
	if (!('wakeLock' in navigator)) return;
	var lock = null, last = Date.now();
	function take() {
		last = Date.now();
		if (lock || document.visibilityState !== 'visible') return;
		navigator.wakeLock.request('screen').then(function (l) {
			lock = l;
			l.addEventListener('release', function () { lock = null; });
		}).catch(function () {});
	}
	document.addEventListener('pointerdown', take, {passive: true});
	document.addEventListener('keydown', take, {passive: true});
	document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'visible') take(); });
	setInterval(function () {
		if (lock && Date.now() - last > 120000) { lock.release(); lock = null; }
	}, 10000);
})();
"""


func _web_setup() -> void:
	JavaScriptBridge.eval(WAKE_JS, true)


func _setup_window() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.size_changed.connect(_fit_scale)
	_fit_scale()


## Keeps one UI pixel equal to one CSS pixel on high-density screens such as phones.
func _fit_scale() -> void:
	var win := get_window()
	if _args.has("vsize"):
		var p: PackedStringArray = _args.vsize.split("x")
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		win.content_scale_size = Vector2i(int(p[0]), int(p[1]))
		return
	var dpr := clampf(DisplayServer.screen_get_scale(), 1.0, 4.0)
	var base := Vector2i((Vector2(win.size) / dpr).round()).max(Vector2i(1, 1))
	if win.content_scale_size != base:
		win.content_scale_size = base


func _on_world_resized() -> void:
	var sz := Vector2(game.W, game.H)
	vp.size = Vector2i(game.W, game.H)
	for r in [bg, tint]:
		r.position = Vector2.ZERO
		r.size = sz
	var p := game.place
	var mat: ShaderMaterial = bg.material
	mat.set_shader_parameter("W", float(game.W))
	mat.set_shader_parameter("H", float(game.H))
	mat.set_shader_parameter("SURF", float(game.SURF))
	mat.set_shader_parameter("BED", float(game.BED))
	mat.set_shader_parameter("water_top", Color(p.water[0]))
	mat.set_shader_parameter("water_deep", Color(p.water[1]))
	var cols: Array = p.bed.cols
	for i in 4:
		mat.set_shader_parameter("bed%d" % i, Color(cols[i]))
	mat.set_shader_parameter("bed_style", {"sand": 0, "rock": 1, "pebble": 2, "mud": 3}.get(p.bed.style, 0))
	var bytes := PackedByteArray()
	bytes.resize(game.W * 2)
	for x in game.W:
		var y: int = game.bed[x]
		bytes[x * 2] = (y >> 8) & 0xFF
		bytes[x * 2 + 1] = y & 0xFF
	var img := Image.create_from_data(game.W, 1, false, Image.FORMAT_RG8, bytes)
	_bedtex = ImageTexture.create_from_image(img)
	mat.set_shader_parameter("bedtex", _bedtex)


var _perf_t := 0.0
var _perf_n := 0
var _perf_sum := 0.0
var _perf_max := 0.0


## Prints the frame rate and the script time per frame every 5 seconds.
func _perf(dt: float) -> void:
	var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_perf_t += dt
	_perf_n += 1
	_perf_sum += ms
	_perf_max = maxf(_perf_max, ms)
	if _perf_t >= 5.0:
		print("PERF fps %.1f  process %.2f ms avg  %.2f ms max  fish %d  view %s  scene %dx%d x%.2f" % [_perf_n / _perf_t, _perf_sum / _perf_n, _perf_max, game.fish.size(), get_window().size, game.W, game.H, game.px_scale])
		_perf_t = 0.0
		_perf_n = 0
		_perf_sum = 0.0
		_perf_max = 0.0


func _process(_dt: float) -> void:
	if game.S.is_empty():
		return
	if _args.has("perf"):
		_perf(_dt)
	if _args.has("autoplay"):
		_autoplay(_dt)
		if _auto_t > float(_args.autoplay):
			print("STATS ", game.S.stats, " coins ", game.S.coins, " book ", game.S.book.size())
			get_tree().quit()
	var sk := game.sky()
	tint.color = sk.tint
	var mat: ShaderMaterial = bg.material
	var p := game.place
	var top := Color(p.sky[0])
	var hor := Color(p.sky[1])
	var wl: float = D.WEATHER[game.S.wx].light
	if wl < 1.0:
		var grey := Color("#8a96a6")
		top = D.mix(top, grey, (1.0 - wl) * 2.2)
		hor = D.mix(hor, D.light(grey, 0.3), (1.0 - wl) * 2.2)
	mat.set_shader_parameter("sky_top", top)
	mat.set_shader_parameter("sky_hor", hor)
	var h := game.local_hours()
	var g := 0.0
	if h > 4.5 and h < 8.0:
		g = 1.0 - absf(h - 6.2) / 1.8
	elif h > 17.0 and h < 21.0:
		g = 1.0 - absf(h - 19.0) / 2.0
	mat.set_shader_parameter("glow", Color(1.0, 0.55, 0.35, clampf(g, 0.0, 1.0) * 0.75 * wl))


## Fades the screen out, runs a callable, and fades back in.
func fade_through(f: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(f)
	tw.tween_interval(0.15)
	tw.tween_property(fade, "color:a", 0.0, 0.45)
