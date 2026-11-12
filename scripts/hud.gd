class_name Hud
extends Control
## The interface over the scene: the top bar, the action button, the bait picker, the fight meter,
## the catch card, the shop, the fish book, the awards, toasts and hints.

var g: Game
var display: SceneDisplay
var main: Control
var snap := {}
var panel := ""
var narrow := false
## True when the screen is short, such as a phone held sideways.
var short := false
## True when the screen is too thin for the sound button in the top bar.
var tiny := false
var _clock := 0.0
var _sig := ""
var _book_loc := ""
var _reset_arm := false
var _reset_t := 0.0
var _taps: Array = []
## Toasts that wait until the catch card closes, so they do not cover it on a small screen.
var _toast_wait: Array = []

var margin: MarginContainer
var col: VBoxContainer
var _top_row: HBoxContainer
var _top_spacer: Control
var _place_box: HBoxContainer
var _bottom_panels: Array[PanelContainer] = []
var full_btn: PxButton
var _full_icon: FullIcon
var _full_ok := false
var top_bar: PanelContainer
var bottom_bar: HBoxContainer
var middle: Control
var flag_tex: TextureRect
var place_l: Label
var country_l: Label
var clock_l: Label
var phase_l: Label
var wx_l: Label
var coins_l: Label
var map_btn: PxButton
var sound_btn: PxButton
var _speaker: UI.Speaker
var bait_btn: PxButton
var bait_icon: TextureRect
var bait_l: Label
var action: ActionButton
var panel_btns := {}
var menu_btn: PxButton
var _panels_box: HBoxContainer
var bait_pop: PanelContainer
var bait_rows: VBoxContainer
var toast_box: VBoxContainer
var hint_box: PanelContainer
var hint_l: Label
var msg_l: Label
var hover_box: PanelContainer
var hover_l: Label
var fight_box: PanelContainer
var fight_name: Label
var fight_dist: Label
var fight_state: Label
var tension: TensionBar
var stamina: UI.Bar
var card: PanelContainer
var cr := {}
var drawer: PanelContainer
var drawer_title: Label
var drawer_body: VBoxContainer
var drawer_scroll: ScrollContainer
var banner: PanelContainer
var banner_flag: TextureRect
var banner_name: Label
var banner_sub: Label
var banner_blurb: Label
var _banner_t := 99.0
var map: MapView
var cup_chip: PxButton
var cup_fee_l: Label
var board: PanelContainer
var board_time: Label
var board_kind: Label
var board_rows: VBoxContainer
var _board_sig := ""
var results: PanelContainer
var res := {}
var _res_sig := ""
var _tags: Array = []
var _country_box: HBoxContainer
var _logo: Label

const PANELS := [["shop", "Shop"], ["book", "Book"], ["awards", "Awards"]]
const RANKS := ["1ST", "2ND", "3RD", "4TH"]
const PANEL_BG := Color(14 / 255.0, 21 / 255.0, 38 / 255.0, 0.95)
const BAR_BG := Color(11 / 255.0, 17 / 255.0, 32 / 255.0, 0.88)
const WX_ICON := {"clear": "SUN", "cloud": "CLOUD", "rain": "RAIN", "snow": "SNOW", "fog": "FOG"}


func build(game: Game, disp: SceneDisplay, main_node: Control) -> void:
	g = game
	display = disp
	main = main_node
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	col = UI.vbox(12)
	margin.add_child(col)
	_build_top(col)
	middle = Control.new()
	middle.size_flags_vertical = SIZE_EXPAND_FILL
	middle.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(middle)
	_build_middle()
	_build_bottom(col)
	map = MapView.new()
	add_child(map)
	map.build(g, self)
	map.visible = false
	g.changed.connect(_on_changed)
	g.toast.connect(_on_toast)
	g.landed.connect(_on_landed)
	g.place_changed.connect(_show_banner)


## Screen pixels per UI pixel.
func ui_scale() -> float:
	var w := get_window()
	var base := Vector2(w.content_scale_size)
	if base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	return minf(w.size.x / base.x, w.size.y / base.y)


func top_inset() -> float:
	return top_bar.global_position.y + top_bar.size.y + 4.0


func bottom_inset() -> float:
	return size.y - bottom_bar.global_position.y + 4.0


# ---------- build ----------

func _build_top(col: VBoxContainer) -> void:
	top_bar = UI.px_panel(BAR_BG, UI.BORDER, 3, Vector4(12, 7, 10, 7))
	col.add_child(top_bar)
	var row := UI.hbox(14)
	_top_row = row
	top_bar.add_child(row)
	_logo = UI.label("FAR SHORES", UI.silk, 15, UI.GOLD_TEXT)
	_logo.size_flags_vertical = SIZE_SHRINK_CENTER
	_logo.mouse_filter = MOUSE_FILTER_STOP
	_logo.gui_input.connect(_on_logo_input)
	row.add_child(_logo)
	var pl := UI.hbox(8)
	pl.size_flags_vertical = SIZE_SHRINK_CENTER
	_place_box = pl
	flag_tex = TextureRect.new()
	flag_tex.custom_minimum_size = Vector2(Sprites.FLAG_W * 2, Sprites.FLAG_H * 2)
	flag_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_tex.texture_filter = TEXTURE_FILTER_NEAREST
	flag_tex.size_flags_vertical = SIZE_SHRINK_CENTER
	flag_tex.mouse_filter = MOUSE_FILTER_IGNORE
	pl.add_child(flag_tex)
	place_l = UI.label("", UI.pix_bold, 17)
	place_l.size_flags_vertical = SIZE_SHRINK_CENTER
	pl.add_child(place_l)
	country_l = UI.label("", UI.silk, 10, UI.MUTED)
	country_l.size_flags_vertical = SIZE_SHRINK_CENTER
	pl.add_child(country_l)
	row.add_child(pl)
	_top_spacer = UI.spacer()
	row.add_child(_top_spacer)
	var ck := UI.hbox(8)
	ck.size_flags_vertical = SIZE_SHRINK_CENTER
	wx_l = UI.label("", UI.silk, 10, UI.MUTED)
	clock_l = UI.label("", UI.silk, 12)
	phase_l = UI.label("", UI.silk, 11)
	for l in [wx_l, clock_l, phase_l]:
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		ck.add_child(l)
	row.add_child(ck)
	var coin := UI.hbox(7)
	coin.size_flags_vertical = SIZE_SHRINK_CENTER
	coin.add_child(UI.CoinIcon.new())
	coins_l = UI.label("0", UI.silk, 15, UI.GOLD_TEXT)
	coin.add_child(coins_l)
	row.add_child(coin)
	map_btn = PxButton.new("MAP", UI.silk, 11, UI.LOGO, UI.BTN, Vector2(0, 32))
	map_btn.tooltip_text = "Travel the world (M)"
	map_btn.pressed.connect(open_map)
	row.add_child(map_btn)
	sound_btn = PxButton.new("", UI.silk, 11, UI.TEXT, UI.BTN, Vector2(36, 32), Vector2(8, 6))
	_speaker = UI.Speaker.new()
	sound_btn.add_child(_speaker)
	sound_btn.pressed.connect(func(): g.set_sound(not g.synth.on))
	row.add_child(sound_btn)
	_full_ok = _fullscreen_supported()
	full_btn = PxButton.new("", UI.silk, 11, UI.TEXT, UI.BTN, Vector2(36, 32), Vector2(8, 6))
	full_btn.tooltip_text = "Full screen"
	_full_icon = FullIcon.new()
	full_btn.add_child(_full_icon)
	full_btn.pressed.connect(toggle_fullscreen)
	full_btn.visible = false
	row.add_child(full_btn)


## The browser can show the game in full screen. iPhone Safari cannot, so the button stays hidden there.
func _fullscreen_supported() -> bool:
	if not OS.has_feature("web") or not DisplayServer.is_touchscreen_available():
		return false
	return bool(JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true))


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	g.synth.click()


func _build_middle() -> void:
	toast_box = UI.vbox(8)
	toast_box.z_index = 3
	middle.add_child(toast_box)

	msg_l = UI.label("", UI.silk, 20, UI.TEXT)
	msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	msg_l.add_theme_constant_override("shadow_offset_x", 2)
	msg_l.add_theme_constant_override("shadow_offset_y", 2)
	middle.add_child(msg_l)

	hover_box = UI.px_panel(Color(BAR_BG, 0.92), UI.BORDER, 2, Vector4(8, 4, 8, 4))
	hover_box.mouse_filter = MOUSE_FILTER_IGNORE
	hover_l = UI.label("", UI.pix, 13)
	hover_box.add_child(hover_l)
	hover_box.visible = false
	add_child(hover_box)

	hint_box = UI.px_panel(BAR_BG, UI.BORDER, 2, Vector4(14, 8, 14, 8))
	hint_box.mouse_filter = MOUSE_FILTER_IGNORE
	hint_l = UI.wrap_label("", UI.pix, 14, UI.HINT)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_box.add_child(hint_l)
	hint_box.visible = false
	middle.add_child(hint_box)

	fight_box = UI.px_panel(PANEL_BG, UI.BORDER, 3, Vector4(14, 10, 14, 10))
	fight_box.mouse_filter = MOUSE_FILTER_IGNORE
	var fv := UI.vbox(8)
	fight_box.add_child(fv)
	var fh := UI.hbox(10)
	fight_name = UI.label("", UI.pix_bold, 16)
	fh.add_child(fight_name)
	fh.add_child(UI.spacer())
	fight_dist = UI.label("", UI.silk, 11, UI.MUTED)
	fight_dist.size_flags_vertical = SIZE_SHRINK_CENTER
	fh.add_child(fight_dist)
	fv.add_child(fh)
	var tl := UI.hbox(8)
	var tt := UI.label("LINE", UI.silk, 10, UI.MUTED)
	tt.custom_minimum_size.x = 40
	tt.size_flags_vertical = SIZE_SHRINK_CENTER
	tl.add_child(tt)
	tension = TensionBar.new()
	tl.add_child(tension)
	fv.add_child(tl)
	var sl := UI.hbox(8)
	var st := UI.label("FISH", UI.silk, 10, UI.MUTED)
	st.custom_minimum_size.x = 40
	st.size_flags_vertical = SIZE_SHRINK_CENTER
	sl.add_child(st)
	stamina = UI.Bar.new(6, true)
	stamina.size_flags_vertical = SIZE_SHRINK_CENTER
	sl.add_child(stamina)
	fv.add_child(sl)
	fight_state = UI.label("", UI.silk, 12)
	fight_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(fight_state)
	fight_box.visible = false
	middle.add_child(fight_box)

	_build_contest_ui()
	_build_card()
	_build_results()
	_build_drawer()
	_build_bait_pop()
	_build_banner()


func _build_contest_ui() -> void:
	cup_chip = PxButton.new("", null, 12, UI.TEXT, Color(BAR_BG, 0.92), Vector2(0, 32), Vector2(8, 4))
	cup_chip.tooltip_text = "Join a fishing contest (C)"
	var h := UI.hbox(6)
	h.add_child(CupIcon.new())
	var l := UI.label("CONTEST", UI.silk, 11, UI.GOLD_TEXT)
	l.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(l)
	cup_fee_l = UI.label("", UI.silk, 9, UI.MUTED)
	cup_fee_l.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(cup_fee_l)
	cup_chip.add_child(h)
	cup_chip.pressed.connect(func(): _set_panel("" if panel == "contest" else "contest"))
	cup_chip.visible = false
	middle.add_child(cup_chip)

	board = UI.px_panel(Color(BAR_BG, 0.92), UI.BORDER, 2, Vector4(10, 6, 10, 7))
	board.mouse_filter = MOUSE_FILTER_IGNORE
	board.custom_minimum_size.x = 176
	var v := UI.vbox(3)
	board.add_child(v)
	var bh := UI.hbox(6)
	bh.add_child(CupIcon.new())
	var bt := UI.label("CONTEST", UI.silk, 10, UI.GOLD_TEXT)
	bt.size_flags_vertical = SIZE_SHRINK_CENTER
	bh.add_child(bt)
	bh.add_child(UI.spacer())
	board_time = UI.label("", UI.silk, 12)
	board_time.size_flags_vertical = SIZE_SHRINK_CENTER
	bh.add_child(board_time)
	v.add_child(bh)
	board_kind = UI.label("", UI.silk, 9, UI.MUTED)
	v.add_child(board_kind)
	board_rows = UI.vbox(1)
	v.add_child(board_rows)
	board.visible = false
	middle.add_child(board)


func _build_results() -> void:
	results = UI.px_panel(PANEL_BG, UI.GOLD, 3, Vector4(18, 14, 18, 14))
	var v := UI.vbox(8)
	results.add_child(v)
	res.head = UI.label("CONTEST RESULTS", UI.silk, 13, UI.GOLD_TEXT)
	res.head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(res.head)
	res.kind = UI.label("", UI.pix_bold, 20)
	res.kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(res.kind)
	res.rows = UI.vbox(4)
	v.add_child(res.rows)
	res.text = UI.wrap_label("", UI.pix, 14, UI.SUB)
	res.text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(res.text)
	res.btn = PxButton.new("COLLECT", UI.silk, 13, UI.BG, UI.GOLD, Vector2(180, 42), Vector2(14, 8))
	res.btn.size_flags_horizontal = SIZE_SHRINK_CENTER
	res.btn.pressed.connect(func(): g.collect_contest(); _refresh())
	v.add_child(res.btn)
	results.visible = false
	middle.add_child(results)


## One row of a contest table: place, flag, name and score.
func _cup_row(rank: int, row: Dictionary, c: Contest, fs: int) -> HBoxContainer:
	var h := UI.hbox(6)
	var col := UI.AQUA if row.me else UI.TEXT
	var rl := UI.label(RANKS[clampi(rank - 1, 0, 3)], UI.silk, fs - 3, UI.GOLD_TEXT if rank == 1 else UI.MUTED)
	rl.custom_minimum_size.x = fs * 2.2
	rl.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(rl)
	var fl := TextureRect.new()
	fl.custom_minimum_size = Vector2(Sprites.FLAG_W, Sprites.FLAG_H)
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.texture_filter = TEXTURE_FILTER_NEAREST
	fl.size_flags_vertical = SIZE_SHRINK_CENTER
	fl.mouse_filter = MOUSE_FILTER_IGNORE
	if row.flag != "":
		fl.texture = Sprites.flag_tex(row.flag)
	h.add_child(fl)
	var nl := UI.clip(UI.label(row.name, UI.pix_bold if row.me else UI.pix, fs, col))
	nl.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(nl)
	var sl := UI.label(c.fmt(row.score), UI.silk, fs - 3, col)
	sl.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(sl)
	return h


func _build_card() -> void:
	card = UI.px_panel(PANEL_BG, UI.GOLD, 3, Vector4(18, 16, 18, 16))
	var v := UI.vbox(10)
	card.add_child(v)
	cr.head = UI.label("", UI.silk, 13, UI.GOLD_TEXT)
	cr.head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr.head)
	# The body stacks the picture over the text. On a short screen it puts them side by side.
	cr.body = BoxContainer.new()
	cr.body.vertical = true
	cr.body.add_theme_constant_override("separation", 10)
	v.add_child(cr.body)
	var sb := UI.sprite_box(Vector2(0, 120), Vector2(0, 0))
	cr.box = sb[0]
	cr.tex = sb[1]
	cr.tex.size_flags_horizontal = SIZE_EXPAND_FILL
	cr.tex.size_flags_vertical = SIZE_EXPAND_FILL
	cr.body.add_child(sb[0])
	v = UI.vbox(10)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.size_flags_vertical = SIZE_SHRINK_CENTER
	cr.info = v
	cr.body.add_child(v)
	cr.name = UI.label("", UI.pix_bold, 22)
	cr.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr.name)
	cr.latin = UI.label("", UI.pix, 13, UI.MUTED)
	cr.latin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr.latin)
	var stats := UI.hbox(18)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.rarity = UI.label("", UI.silk, 11)
	cr.weight = UI.label("", UI.silk, 11)
	cr.length = UI.label("", UI.silk, 11)
	for l in [cr.rarity, cr.weight, cr.length]:
		stats.add_child(l)
	v.add_child(stats)
	cr.desc = UI.wrap_label("", UI.pix, 14, UI.SUB)
	cr.desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cr.desc)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.sell = PxButton.new("SELL", UI.silk, 13, UI.BG, UI.GOLD, Vector2(140, 42), Vector2(14, 8))
	cr.sell.pressed.connect(func(): g.sell_catch(); _refresh())
	cr.release = PxButton.new("RELEASE", UI.silk, 13, UI.TEXT, UI.BTN2, Vector2(120, 42), Vector2(14, 8))
	cr.release.pressed.connect(func(): g.release_catch(); _refresh())
	row.add_child(cr.sell)
	row.add_child(cr.release)
	v.add_child(row)
	card.visible = false
	middle.add_child(card)


func _build_drawer() -> void:
	drawer = UI.px_panel(PANEL_BG, UI.BORDER, 3, Vector4(0, 0, 0, 0))
	var vv := UI.vbox(0)
	drawer.add_child(vv)
	var hm := MarginContainer.new()
	hm.mouse_filter = MOUSE_FILTER_IGNORE
	for side in [["left", 14], ["right", 10], ["top", 8], ["bottom", 8]]:
		hm.add_theme_constant_override("margin_" + side[0], side[1])
	var hh := UI.hbox(8)
	hm.add_child(hh)
	drawer_title = UI.label("", UI.silk, 14, UI.LOGO)
	drawer_title.size_flags_vertical = SIZE_SHRINK_CENTER
	hh.add_child(drawer_title)
	hh.add_child(UI.spacer())
	var close := PxButton.new("CLOSE", UI.silk, 11, UI.MUTED, Color(0, 0, 0, 0), Vector2(0, 32), Vector2(6, 6))
	close.pressed.connect(func(): _set_panel(""))
	hh.add_child(close)
	vv.add_child(hm)
	var line := ColorRect.new()
	line.color = UI.BORDER
	line.custom_minimum_size.y = 3
	line.mouse_filter = MOUSE_FILTER_IGNORE
	vv.add_child(line)
	drawer_scroll = ScrollContainer.new()
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vv.add_child(drawer_scroll)
	var inner := MarginContainer.new()
	inner.size_flags_horizontal = SIZE_EXPAND_FILL
	inner.mouse_filter = MOUSE_FILTER_PASS
	for side in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	drawer_scroll.add_child(inner)
	drawer_body = UI.vbox(10)
	drawer_body.mouse_filter = MOUSE_FILTER_PASS
	inner.add_child(drawer_body)
	drawer.visible = false
	middle.add_child(drawer)


func _build_bait_pop() -> void:
	bait_pop = UI.px_panel(PANEL_BG, UI.BORDER, 3, Vector4(8, 8, 8, 8))
	bait_rows = UI.vbox(6)
	bait_pop.add_child(bait_rows)
	bait_pop.visible = false
	middle.add_child(bait_pop)


func _build_banner() -> void:
	banner = UI.px_panel(Color(BAR_BG, 0.9), UI.GOLD, 3, Vector4(22, 12, 22, 14))
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	var v := UI.vbox(6)
	banner.add_child(v)
	var h := UI.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_flag = TextureRect.new()
	banner_flag.custom_minimum_size = Vector2(Sprites.FLAG_W * 3, Sprites.FLAG_H * 3)
	banner_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_flag.texture_filter = TEXTURE_FILTER_NEAREST
	banner_flag.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(banner_flag)
	banner_name = UI.label("", UI.pix_bold, 26)
	h.add_child(banner_name)
	v.add_child(h)
	banner_sub = UI.label("", UI.silk, 11, UI.GOLD_TEXT)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_sub)
	banner_blurb = UI.wrap_label("", UI.pix, 14, UI.SUB)
	banner_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_blurb)
	banner.visible = false
	middle.add_child(banner)


func _build_bottom(col: VBoxContainer) -> void:
	bottom_bar = UI.hbox(10)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom_bar)
	var bp := UI.px_panel(BAR_BG, UI.BORDER, 3, Vector4(6, 6, 6, 6))
	bottom_bar.add_child(bp)
	_bottom_panels.append(bp)
	bait_btn = PxButton.new("", null, 12, UI.TEXT, UI.BTN, Vector2(0, 48), Vector2(10, 4))
	bait_btn.tooltip_text = "Change bait (1 to 5)"
	var bh := UI.hbox(8)
	bh.size_flags_vertical = SIZE_SHRINK_CENTER
	bait_icon = TextureRect.new()
	bait_icon.custom_minimum_size = Vector2(28, 28)
	bait_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bait_icon.texture_filter = TEXTURE_FILTER_NEAREST
	bait_icon.size_flags_vertical = SIZE_SHRINK_CENTER
	bait_icon.mouse_filter = MOUSE_FILTER_IGNORE
	bh.add_child(bait_icon)
	var bv := UI.vbox(1)
	bv.size_flags_vertical = SIZE_SHRINK_CENTER
	bv.add_child(UI.label("BAIT", UI.silk, 9, UI.MUTED))
	bait_l = UI.label("", UI.silk, 12)
	bv.add_child(bait_l)
	bh.add_child(bv)
	bait_btn.add_child(bh)
	bait_btn.pressed.connect(_toggle_bait_pop)
	bp.add_child(bait_btn)
	var ap := UI.px_panel(BAR_BG, UI.BORDER, 3, Vector4(6, 6, 6, 6))
	bottom_bar.add_child(ap)
	_bottom_panels.append(ap)
	action = ActionButton.new()
	action.down.connect(func(): _close_pop(); g.action_down())
	action.up.connect(func(): g.action_up())
	ap.add_child(action)
	var pp := UI.px_panel(BAR_BG, UI.BORDER, 3, Vector4(6, 6, 6, 6))
	bottom_bar.add_child(pp)
	_bottom_panels.append(pp)
	_panels_box = UI.hbox(6)
	pp.add_child(_panels_box)
	for p in PANELS:
		var b := PxButton.new(p[1], UI.silk, 12, UI.TEXT, UI.BTN, Vector2(66, 48), Vector2(8, 6))
		var key: String = p[0]
		b.pressed.connect(func(): _set_panel("" if panel == key else key))
		_panels_box.add_child(b)
		panel_btns[key] = b
	menu_btn = PxButton.new("MENU", UI.silk, 12, UI.TEXT, UI.BTN, Vector2(60, 48), Vector2(8, 6))
	menu_btn.pressed.connect(func(): _set_panel("" if panel != "" else "shop"))
	menu_btn.visible = false
	_panels_box.add_child(menu_btn)


# ---------- events ----------

func _on_logo_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var now := _clock
		_taps = _taps.filter(func(t): return now - t < 4.0)
		_taps.append(now)
		if _taps.size() >= 10:
			_taps.clear()
			g.cheat(5000)


func _set_panel(k: String) -> void:
	panel = k
	_sig = ""
	_close_pop()
	g.synth.click()
	_refresh()


func open_map() -> void:
	if g.contest != null and g.contest.st in ["on", "horn", "results"]:
		g.toast.emit("Finish the contest first. Then you can travel.", "info")
		return
	_set_panel("")
	display.cancel()
	map.open()


func _toggle_bait_pop() -> void:
	bait_pop.visible = not bait_pop.visible
	if bait_pop.visible:
		_fill_bait_pop()
	g.synth.click()


func _close_pop() -> void:
	bait_pop.visible = false


func _fill_bait_pop() -> void:
	for c in bait_rows.get_children():
		c.queue_free()
	bait_rows.add_child(UI.label("CHOOSE BAIT", UI.silk, 10, UI.MUTED))
	for i in D.BAIT_KEYS.size():
		var k: String = D.BAIT_KEYS[i]
		var owned: bool = g.S.baits.has(k)
		var b := PxButton.new("", null, 12, UI.TEXT, UI.BTN2 if g.S.bait == k else UI.BTN, Vector2(210, 38), Vector2(8, 4))
		var h := UI.hbox(8)
		var ic := TextureRect.new()
		ic.texture = Sprites.bait_tex(k)
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = TEXTURE_FILTER_NEAREST
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := UI.label("%d  %s" % [i + 1, D.BAITS[k].name], UI.silk, 11, UI.TEXT if owned else UI.DIM)
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(l)
		h.add_child(UI.spacer())
		if not owned:
			var pl := UI.label(str(D.BAITS[k].price), UI.silk, 10, UI.GOLD_TEXT)
			pl.size_flags_vertical = SIZE_SHRINK_CENTER
			h.add_child(pl)
		b.add_child(h)
		b.set_dim(1.0 if owned else 0.7)
		b.pressed.connect(func():
			if owned:
				g.set_bait(k)
				_close_pop()
			else:
				_close_pop()
				_set_panel("shop"))
		bait_rows.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or e.echo:
		return
	if e.keycode == KEY_SPACE:
		if map.visible:
			return
		if e.pressed:
			g.action_down()
		else:
			g.action_up()
		get_viewport().set_input_as_handled()
		return
	if not e.pressed:
		return
	match e.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if results.visible:
				g.collect_contest()
				_refresh()
			elif card.visible:
				g.sell_catch()
				_refresh()
		KEY_C:
			_set_panel("" if panel == "contest" else "contest")
		KEY_R:
			if card.visible:
				if g.catch_info.release:
					g.sell_catch()
				else:
					g.release_catch()
				_refresh()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var k: String = D.BAIT_KEYS[e.keycode - KEY_1]
			if g.S.baits.has(k):
				g.set_bait(k)
		KEY_M:
			if map.visible:
				map.close()
			else:
				open_map()
		KEY_B:
			_set_panel("" if panel == "book" else "book")
		KEY_F11:
			toggle_fullscreen()
		KEY_ESCAPE:
			if map.visible:
				map.close()
			elif bait_pop.visible:
				_close_pop()
			else:
				_set_panel("")
		_:
			return
	get_viewport().set_input_as_handled()


func _on_changed() -> void:
	snap = g.snapshot()
	_refresh()


func _on_landed(_info: Dictionary) -> void:
	_set_panel("")
	_refresh()


func _show_banner() -> void:
	var p := g.place
	banner_flag.texture = Sprites.flag_tex(p.flag)
	banner_name.text = p.name
	banner_sub.text = p.country.to_upper()
	banner_blurb.text = p.blurb
	_banner_t = 0.0
	_book_loc = g.loc


func _on_toast(text: String, kind: String) -> void:
	if card.visible and (narrow or short):
		_toast_wait.append([text, kind])
		return
	var colors := {"good": UI.GOOD, "bad": UI.BAD, "ach": UI.GOLD, "new": UI.AQUA, "info": UI.INFO, "legend": UI.GOLD,
		"special": Color("#ff7ad9"), "contest": UI.AQUA}
	var box := UI.px_panel(Color(15 / 255.0, 23 / 255.0, 41 / 255.0, 0.96), colors.get(kind, UI.INFO), 3, Vector4(16, 9, 16, 9))
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = SIZE_SHRINK_CENTER
	var fs := 14 if narrow else 15
	var l := UI.wrap_label(text, UI.pix, fs)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := UI.pix.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
	l.set_meta("tw", tw)
	l.custom_minimum_size.x = _toast_w(tw)
	box.add_child(l)
	toast_box.add_child(box)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	box.modulate.a = 0.0
	var tw2 := box.create_tween()
	for i in 3:
		tw2.tween_property(box, "modulate:a", (i + 1) / 3.0, 0.0).set_delay(0.066)
	get_tree().create_timer(4.2).timeout.connect(box.queue_free)


## The width of a toast text. It fits the free space, which can change after the toast shows.
func _toast_w(tw: float) -> float:
	return minf(tw, minf(520.0, maxf(140.0, middle.size.x - 64.0)))


# ---------- refresh ----------

func _refresh() -> void:
	if snap.is_empty():
		return
	var s := snap
	var p: Dictionary = s.place
	flag_tex.texture = Sprites.flag_tex(p.flag)
	place_l.text = p.name
	country_l.text = p.country.to_upper()
	clock_l.text = s.clock
	phase_l.text = s.phase
	phase_l.add_theme_color_override("font_color", UI.PHASES.get(s.phase, UI.TEXT))
	wx_l.text = WX_ICON.get(s.wx, "")
	coins_l.text = D.fmt_int(s.coins)
	_speaker.set_on(s.sound)
	bait_icon.texture = Sprites.bait_tex(s.bait)
	bait_l.text = D.BAITS[s.bait].name.to_upper()
	for k in panel_btns:
		var b: PxButton = panel_btns[k]
		var open: bool = panel == k
		b.set_colors(UI.BTN2 if open else UI.BTN, UI.AQUA if open else UI.TEXT)
	menu_btn.set_colors(UI.BTN2 if panel != "" else UI.BTN, UI.AQUA if panel != "" else UI.TEXT)
	_refresh_card()
	_refresh_drawer()


func _refresh_card() -> void:
	var c: Dictionary = g.catch_info
	var show := g.phase == "show" and not c.is_empty()
	card.visible = show
	if not show:
		return
	var rar: Dictionary = D.RARITY[c.r]
	var rc := Color(rar.col)
	card.add_theme_stylebox_override("panel", UI.px_box(PANEL_BG, rc if c.r > 0 else UI.BORDER, 3, Vector4(18, 16, 18, 16)))
	cr.head.text = "NEW SPECIES!" if c.new else ("NEW RECORD!" if c.record else "NICE CATCH")
	cr.head.add_theme_color_override("font_color", UI.AQUA if c.new else (UI.GOLD_TEXT if c.record else UI.MUTED))
	if c.special:
		cr.head.text = "RARE VISITOR!"
		cr.head.add_theme_color_override("font_color", rc)
	cr.tex.texture = Sprites.fish_tex(c.sp, c.sz, int(_clock * 4.0) % 4)
	cr.name.text = c.name
	cr.latin.text = c.latin
	cr.rarity.text = rar.name.to_upper()
	cr.rarity.add_theme_color_override("font_color", rc)
	cr.weight.text = D.fmt_kg(c.w)
	cr.length.text = "%d cm" % roundi(c.len)
	cr.desc.text = c.desc
	if c.release:
		cr.sell.set_text("RELEASE +%s" % D.fmt_int(c.price))
		cr.release.visible = false
		if c.legend:
			cr.desc.text = c.desc + " Legends go back to the water. The fishing club pays a bounty."
		else:
			cr.desc.text = c.desc + " The fishing club pays a bounty."
	else:
		cr.sell.set_text("SELL +%s" % D.fmt_int(c.price))
		cr.release.visible = true


func _panel_sig() -> String:
	var cup := ""
	if panel == "contest":
		var c := g.contest
		cup = "none|%d" % ceili(g._cup_cool) if c == null else "%s|%d|%s" % [c.st, ceili(c.t), str(c.standings().map(func(r): return r.score))]
	return "%s|%d|%s|%s|%d|%d|%s|%s|%s|%s" % [panel, g.S.coins, str(g.S.gear), str(g.S.baits.keys()), g.S.book.size(), g.S.ach.size(), g.S.bait, _book_loc, _reset_arm, cup]


func _refresh_drawer() -> void:
	drawer.visible = panel != "" and not map.visible
	if not drawer.visible:
		return
	var sig := _panel_sig()
	if sig == _sig:
		return
	_sig = sig
	var keep := drawer_scroll.scroll_vertical
	for c in drawer_body.get_children():
		c.queue_free()
	match panel:
		"shop":
			drawer_title.text = "TACKLE SHOP"
			_build_shop()
		"book":
			drawer_title.text = "FISH BOOK  %d/%d" % [g.S.book.size(), Species.count()]
			_build_book()
		"awards":
			drawer_title.text = "AWARDS  %d/%d" % [g.S.ach.size(), D.ACH.size()]
			_build_awards()
		"contest":
			drawer_title.text = "FISHING CONTEST"
			_build_contest()
	if narrow:
		var tabs := UI.hbox(6)
		for p in PANELS:
			var k: String = p[0]
			var b := PxButton.new(p[1], UI.silk, 11, UI.AQUA if panel == k else UI.TEXT, UI.BTN2 if panel == k else UI.BTN, Vector2(0, 34), Vector2(6, 4))
			b.size_flags_horizontal = SIZE_EXPAND_FILL
			b.pressed.connect(func(): _set_panel(k))
			tabs.add_child(b)
		if tiny:
			var sb := PxButton.new("", UI.silk, 11, UI.TEXT, UI.BTN, Vector2(36, 34), Vector2(8, 6))
			var sp := UI.Speaker.new()
			sp.set_on(g.synth.on)
			sb.add_child(sp)
			sb.pressed.connect(func():
				g.set_sound(not g.synth.on)
				sp.set_on(g.synth.on))
			tabs.add_child(sb)
			if _full_ok:
				var fb := PxButton.new("", UI.silk, 11, UI.TEXT, UI.BTN, Vector2(36, 34), Vector2(8, 6))
				fb.add_child(FullIcon.new())
				fb.pressed.connect(toggle_fullscreen)
				tabs.add_child(fb)
		drawer_body.add_child(tabs)
		drawer_body.move_child(tabs, 0)
	await get_tree().process_frame
	drawer_scroll.scroll_vertical = keep


func _section(text: String) -> Label:
	var l := UI.label(text, UI.silk, 11, UI.MUTED)
	drawer_body.add_child(l)
	return l


func _build_shop() -> void:
	_section("GEAR")
	var names := {"rod": "ROD", "reel": "REEL", "line": "LINE"}
	for k in D.GEAR_KEYS:
		var lv: int = g.S.gear[k]
		var tbl: Array = D.GEAR[k]
		var cur: Dictionary = tbl[lv]
		var row := UI.px_panel(UI.BTN, UI.BORDER, 2, Vector4(10, 8, 10, 8))
		row.mouse_filter = MOUSE_FILTER_PASS
		var v := UI.vbox(6)
		row.add_child(v)
		var h := UI.hbox(8)
		h.add_child(UI.label(names[k], UI.silk, 10, UI.MUTED))
		h.add_child(UI.label(cur.name, UI.pix_bold, 15))
		h.add_child(UI.spacer())
		var dots := UI.hbox(3)
		dots.size_flags_vertical = SIZE_SHRINK_CENTER
		for i in tbl.size():
			var d := ColorRect.new()
			d.custom_minimum_size = Vector2(8, 8)
			d.color = UI.AQUA if i <= lv else UI.INFO
			d.mouse_filter = MOUSE_FILTER_IGNORE
			dots.add_child(d)
		h.add_child(dots)
		v.add_child(h)
		if lv < tbl.size() - 1:
			var nx: Dictionary = tbl[lv + 1]
			var h2 := UI.hbox(8)
			var dl := UI.clip(UI.label("Next: %s. %s" % [nx.name, nx.desc], UI.pix, 13, UI.SUB))
			dl.size_flags_vertical = SIZE_SHRINK_CENTER
			h2.add_child(dl)
			var can: bool = g.S.coins >= nx.price
			var b := PxButton.new("BUY %s" % D.fmt_int(nx.price), UI.silk, 11, UI.BG if can else UI.MUTED, UI.GOLD if can else UI.BTN2, Vector2(0, 32), Vector2(10, 4))
			b.mouse_filter = MOUSE_FILTER_PASS
			b.pressed.connect(func(): g.buy_gear(k))
			h2.add_child(b)
			v.add_child(h2)
		else:
			v.add_child(UI.label("The best there is.", UI.pix, 13, UI.GOOD))
		drawer_body.add_child(row)
	_section("BAIT")
	for k in D.BAIT_KEYS:
		var b: Dictionary = D.BAITS[k]
		var owned: bool = g.S.baits.has(k)
		var on: bool = g.S.bait == k
		var row := UI.px_panel(UI.BTN2 if on else UI.BTN, UI.AQUA if on else UI.BORDER, 2, Vector4(8, 6, 10, 6))
		row.mouse_filter = MOUSE_FILTER_PASS
		var h := UI.hbox(10)
		row.add_child(h)
		var ic := TextureRect.new()
		ic.texture = Sprites.bait_tex(k)
		ic.custom_minimum_size = Vector2(36, 36)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = TEXTURE_FILTER_NEAREST
		ic.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := UI.vbox(2)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		v.add_child(UI.label(b.name, UI.pix_bold, 15))
		v.add_child(UI.clip(UI.label(b.desc, UI.pix, 13, UI.SUB)))
		h.add_child(v)
		var btn: PxButton
		if on:
			btn = PxButton.new("IN USE", UI.silk, 11, UI.AQUA, Color(0, 0, 0, 0), Vector2(0, 32), Vector2(6, 4))
		elif owned:
			btn = PxButton.new("USE", UI.silk, 11, UI.TEXT, UI.BTN2, Vector2(0, 32), Vector2(10, 4))
			btn.pressed.connect(func(): g.set_bait(k))
		else:
			var can: bool = g.S.coins >= b.price
			btn = PxButton.new("BUY %s" % D.fmt_int(b.price), UI.silk, 11, UI.BG if can else UI.MUTED, UI.GOLD if can else UI.BTN2, Vector2(0, 32), Vector2(10, 4))
			btn.pressed.connect(func(): g.buy_bait(k))
		btn.size_flags_vertical = SIZE_SHRINK_CENTER
		btn.mouse_filter = MOUSE_FILTER_PASS
		h.add_child(btn)
		drawer_body.add_child(row)


func _build_book() -> void:
	if _book_loc == "" or not Places.ALL.has(_book_loc):
		_book_loc = g.loc
	var P: Dictionary = Places.ALL[_book_loc]
	var pool := Species.of_place(_book_loc)
	var found := 0
	for k in pool:
		if g.S.book.has(k):
			found += 1
	var nav := UI.hbox(8)
	var prev := PxButton.new("<", UI.silk, 13, UI.TEXT, UI.BTN, Vector2(40, 36), Vector2(4, 4))
	prev.pressed.connect(func(): _book_step(-1))
	nav.add_child(prev)
	var mid := UI.hbox(8)
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var fl := TextureRect.new()
	fl.texture = Sprites.flag_tex(P.flag)
	fl.custom_minimum_size = Vector2(22, 14)
	fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fl.texture_filter = TEXTURE_FILTER_NEAREST
	fl.size_flags_vertical = SIZE_SHRINK_CENTER
	mid.add_child(fl)
	var nl := UI.label(P.name, UI.pix_bold, 15)
	nl.size_flags_vertical = SIZE_SHRINK_CENTER
	mid.add_child(nl)
	var cl := UI.label("%d/%d" % [found, pool.size()], UI.silk, 11, UI.GOOD if found == pool.size() else UI.MUTED)
	cl.size_flags_vertical = SIZE_SHRINK_CENTER
	mid.add_child(cl)
	nav.add_child(mid)
	var nxt := PxButton.new(">", UI.silk, 13, UI.TEXT, UI.BTN, Vector2(40, 36), Vector2(4, 4))
	nxt.pressed.connect(func(): _book_step(1))
	nav.add_child(nxt)
	drawer_body.add_child(nav)
	var grid := UI.AutoGrid.new(160.0, 8)
	drawer_body.add_child(grid)
	for k in pool:
		var A: Dictionary = Species.ALL[k]
		var e: Dictionary = g.S.book.get(k, {})
		var caught := not e.is_empty()
		var rc := Color(D.RARITY[A.r].col)
		var cell := UI.px_panel(UI.BTN, rc if (caught and A.r > 0) else UI.BORDER, 2, Vector4(8, 8, 8, 8))
		cell.mouse_filter = MOUSE_FILTER_PASS
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		var v := UI.vbox(4)
		cell.add_child(v)
		var sb := UI.sprite_box(Vector2(0, 56), Vector2(0, 0), Sprites.fish_tex(k, 2, 0, "" if caught else "sil"))
		sb[1].size_flags_horizontal = SIZE_EXPAND_FILL
		sb[1].size_flags_vertical = SIZE_EXPAND_FILL
		v.add_child(sb[0])
		v.add_child(UI.clip(UI.label(A.name if caught else "???", UI.pix_bold, 14, UI.TEXT if caught else UI.DIM)))
		v.add_child(UI.label(D.RARITY[A.r].name.to_upper(), UI.silk, 9, rc))
		var bait_names: Array = A.bait.map(func(b): return D.BAITS[b].name)
		var info := "%s · %s\n%s" % [D.time_label(A.time), D.depth_label(A.depth), ", ".join(bait_names)]
		if A.r == 4:
			bait_names = ["Any bait"]
			info = "Visits now and then\n%s · Any bait" % D.depth_label(A.depth)
		if caught:
			info = "Caught %d · best %s\n%s" % [e.n, D.fmt_kg(e.best), ", ".join(bait_names)]
		var il := UI.wrap_label(info, UI.pix, 12, UI.SUB if caught else UI.MUTED)
		v.add_child(il)
		grid.add_child(cell)
	var tot := UI.label("All places: %d of %d species" % [g.S.book.size(), Species.count()], UI.silk, 10, UI.MUTED)
	drawer_body.add_child(tot)


func _build_contest() -> void:
	var running := g.contest != null
	if not running and not g.contest_ready():
		drawer_body.add_child(UI.wrap_label("The next contest starts soon. Come back in %d seconds." % ceili(g._cup_cool), UI.pix, 14, UI.SUB))
		return
	var c: Contest = g.contest if running else g.contest_offer()
	var K: Dictionary = Contest.KINDS[c.kind]
	drawer_body.add_child(UI.label(K.name, UI.pix_bold, 20, UI.GOLD_TEXT))
	drawer_body.add_child(UI.wrap_label("%s Rival anglers fish the same water as you, so be quick." % K.rule, UI.pix, 14, UI.SUB))
	if running:
		_section("STANDINGS")
		var rows := c.standings()
		for i in rows.size():
			drawer_body.add_child(_cup_row(i + 1, rows[i], c, 15))
		var left := "%d:%02d left" % [floori(c.t / 60.0), int(c.t) % 60] if c.st == "on" else "Time is up."
		drawer_body.add_child(UI.label(left.to_upper(), UI.silk, 11, UI.MUTED))
		return
	drawer_body.add_child(UI.label("%d MINUTES  ·  %d RIVALS  ·  ENTRY %s" % [roundi(Contest.LENGTH / 60.0), c.rivals.size(), D.fmt_int(c.fee)], UI.silk, 10, UI.MUTED))
	_section("PRIZES")
	drawer_body.add_child(UI.label("1ST  %s     2ND  %s     3RD  %s" % [D.fmt_int(c.prize_for(1)), D.fmt_int(c.prize_for(2)), D.fmt_int(c.prize_for(3))], UI.silk, 11, UI.GOLD_TEXT))
	_section("RIVALS")
	for r in c.rivals:
		var row := UI.px_panel(UI.BTN, UI.BORDER, 2, Vector4(10, 6, 10, 6))
		row.mouse_filter = MOUSE_FILTER_PASS
		var h := UI.hbox(8)
		row.add_child(h)
		var fl := TextureRect.new()
		fl.texture = Sprites.flag_tex(r.flag)
		fl.custom_minimum_size = Vector2(22, 14)
		fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fl.texture_filter = TEXTURE_FILTER_NEAREST
		fl.size_flags_vertical = SIZE_SHRINK_CENTER
		fl.mouse_filter = MOUSE_FILTER_IGNORE
		h.add_child(fl)
		var nl := UI.clip(UI.label(r.name, UI.pix_bold, 15))
		nl.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(nl)
		var sk := UI.label("SKILL", UI.silk, 9, UI.MUTED)
		sk.size_flags_vertical = SIZE_SHRINK_CENTER
		h.add_child(sk)
		var bar := UI.Bar.new(6, true)
		bar.custom_minimum_size.x = 60
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		var k := clampf((r.skill - 0.5) / 0.85, 0.05, 1.0)
		bar.set_value(k, UI.GOOD if k < 0.4 else (UI.WARN if k < 0.75 else UI.BAD))
		h.add_child(bar)
		drawer_body.add_child(row)
	var best: int = int(g.S.cups.get(g.loc, 0))
	var bl := "Your best result here: %s." % RANKS[clampi(best - 1, 0, 3)].to_lower() if best > 0 else "You have not fished a contest here yet."
	drawer_body.add_child(UI.label(bl, UI.pix, 14, UI.SUB))
	var can: bool = g.S.coins >= c.fee
	var b := PxButton.new("JOIN FOR %s" % D.fmt_int(c.fee) if can else "YOU NEED %s COINS" % D.fmt_int(c.fee), UI.silk, 12, UI.BG if can else UI.MUTED, UI.GOLD if can else UI.BTN2, Vector2(0, 42), Vector2(14, 8))
	b.mouse_filter = MOUSE_FILTER_PASS
	b.pressed.connect(func():
		if g.S.coins >= c.fee:
			_set_panel("")
		g.join_contest())
	drawer_body.add_child(b)


func _book_step(d: int) -> void:
	var i := Places.ORDER.find(_book_loc)
	_book_loc = Places.ORDER[(i + d + Places.ORDER.size()) % Places.ORDER.size()]
	g.synth.click()
	_sig = ""
	_refresh()


func _build_awards() -> void:
	for a in D.ACH:
		var done: bool = g.S.ach.has(a.id)
		var row := UI.hbox(10)
		row.add_child(UI.AchBox.new(done))
		var v := UI.vbox(1)
		v.size_flags_horizontal = SIZE_EXPAND_FILL
		v.add_child(UI.label(a.name, UI.pix_bold, 15, UI.TEXT if done else UI.SUB))
		v.add_child(UI.clip(UI.label(a.desc, UI.pix, 13, UI.MUTED)))
		row.add_child(v)
		var r := UI.label("+%d" % a.r, UI.silk, 10, UI.GOLD_TEXT if done else UI.DIM)
		r.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(r)
		drawer_body.add_child(row)
	_section("STATS")
	var st: Dictionary = g.S.stats
	var lines := "Casts: %d\nFish landed: %d\nSold: %d   Released: %d\nLines snapped: %d   Fish lost: %d\nPlaces visited: %d of %d\nCoins earned: %s" % [
		st.casts, st.caught, st.sold, st.released, st.snaps, st.lost, g.S.visited.size(), Places.ORDER.size(), D.fmt_int(g.S.total)]
	drawer_body.add_child(UI.wrap_label(lines, UI.pix, 14, UI.SUB))
	var reset := PxButton.new("TAP AGAIN TO RESET" if _reset_arm else "RESET GAME", UI.silk, 11, UI.BG if _reset_arm else UI.BAD, UI.BAD if _reset_arm else UI.BTN, Vector2(0, 36), Vector2(12, 6))
	reset.size_flags_horizontal = SIZE_SHRINK_BEGIN
	reset.mouse_filter = MOUSE_FILTER_PASS
	reset.pressed.connect(_on_reset)
	drawer_body.add_child(reset)


func _on_reset() -> void:
	if _reset_arm:
		_reset_arm = false
		_set_panel("")
		g.reset()
	else:
		_reset_arm = true
		_reset_t = _clock + 3.0
		_sig = ""
		_refresh()


# ---------- frame ----------

func _process(dt: float) -> void:
	_clock += dt
	if g == null or g.S.is_empty():
		return
	if _reset_arm and _clock > _reset_t:
		_reset_arm = false
		_sig = ""
		_refresh()
	var was := [narrow, short, tiny]
	narrow = size.x < 760.0
	short = size.y < 520.0
	tiny = size.x < 400.0
	if was != [narrow, short, tiny]:
		_apply_mode()
	if _full_ok:
		_full_icon.set_on(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Rivals keep clear of the scoreboard on a short screen. Set this before the world can change size.
	g.rival_margin = (board.custom_minimum_size.x + 24.0) / maxf(1.0, g.px_scale) if short else 0.0
	g.set_view(size, top_inset(), bottom_inset(), ui_scale())
	display.blocked = map.visible or (narrow and drawer.visible) or card.visible or results.visible
	_update_contest_ui()
	_update_action()
	_update_fight()
	_update_hover()
	_layout_middle(dt)
	if card.visible:
		cr.tex.texture = Sprites.fish_tex(g.catch_info.sp, g.catch_info.sz, int(_clock * 4.0) % 4)


func _apply_mode() -> void:
	_logo.visible = not narrow
	country_l.visible = not narrow
	phase_l.visible = not narrow
	wx_l.visible = not narrow
	# On a narrow screen the place name takes the free space and ends in "..." when it is too long.
	_top_spacer.visible = not narrow
	_place_box.size_flags_horizontal = SIZE_EXPAND_FILL if narrow else SIZE_FILL
	place_l.size_flags_horizontal = SIZE_EXPAND_FILL if narrow else SIZE_FILL
	place_l.clip_text = narrow
	place_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if narrow else TextServer.OVERRUN_NO_TRIMMING
	_top_row.add_theme_constant_override("separation", 8 if narrow else 14)
	top_bar.add_theme_stylebox_override("panel", UI.px_box(BAR_BG, UI.BORDER, 3, Vector4(10, 4, 8, 4) if short else Vector4(12, 7, 10, 7)))
	sound_btn.visible = not tiny
	full_btn.visible = _full_ok and not tiny
	var top_h := 28 if short else (30 if narrow else 32)
	for b in [map_btn, sound_btn, full_btn]:
		b.custom_minimum_size.y = top_h
	for k in panel_btns:
		panel_btns[k].visible = not narrow
	menu_btn.visible = narrow
	bait_l.get_parent().visible = not narrow
	bait_btn.set_pad(6 if narrow else 10, 4)
	var bh := 42 if short else 48
	for b in [bait_btn, menu_btn] + panel_btns.values():
		b.custom_minimum_size.y = bh
	action.custom_minimum_size = Vector2(150 if narrow else 200, bh)
	var bp := 4 if short else 6
	for p in _bottom_panels:
		p.add_theme_stylebox_override("panel", UI.px_box(BAR_BG, UI.BORDER, 3, Vector4(bp, bp, bp, bp)))
	place_l.add_theme_font_size_override("font_size", 15 if narrow else 17)
	bottom_bar.add_theme_constant_override("separation", 6 if narrow else 10)
	col.add_theme_constant_override("separation", 6 if short else 12)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if short else (8 if narrow else 12))
	# The catch card puts the picture beside the text on a short screen.
	cr.body.vertical = not short
	cr.box.custom_minimum_size = Vector2(170, 96) if short else Vector2(0, 120)
	cr.body.add_theme_constant_override("separation", 14 if short else 10)
	cr.info.add_theme_constant_override("separation", 6 if short else 10)
	banner_name.add_theme_font_size_override("font_size", 20 if short else 26)
	_sig = ""
	_refresh()


func _update_contest_ui() -> void:
	var c := g.contest
	var cover := map.visible or (narrow and drawer.visible)
	cup_chip.visible = g.contest_ready() and not cover and not card.visible and g.phase != "fight"
	if cup_chip.visible:
		cup_fee_l.text = "ENTRY %s" % D.fmt_int(g.contest_offer().fee)
	var live := c != null and (c.st == "on" or c.st == "horn")
	board.visible = live and not cover and not card.visible
	if board.visible:
		board_time.text = "%d:%02d" % [floori(c.t / 60.0), int(c.t) % 60] if c.st == "on" else "TIME"
		board_time.add_theme_color_override("font_color", UI.BAD if c.t < 30.0 and int(_clock * 2.0) % 2 == 0 else UI.TEXT)
		board_kind.text = Contest.KINDS[c.kind].name.to_upper()
		board_kind.visible = not narrow
		var rows := c.standings()
		var sig := str(rows.map(func(r): return [r.name, r.score]))
		if sig != _board_sig:
			_board_sig = sig
			for ch in board_rows.get_children():
				ch.queue_free()
			for i in rows.size():
				board_rows.add_child(_cup_row(i + 1, rows[i], c, 13))
	# The result card.
	var show_res := c != null and c.st == "results" and not g.cup_result.is_empty()
	results.visible = show_res and not map.visible
	if results.visible:
		var cr2: Dictionary = g.cup_result
		var sig2 := str(cr2.rows.map(func(r): return [r.name, r.score]))
		if sig2 != _res_sig:
			_res_sig = sig2
			_set_panel("")
			res.kind.text = Contest.KINDS[cr2.kind].name
			for ch in res.rows.get_children():
				ch.queue_free()
			for i in cr2.rows.size():
				res.rows.add_child(_cup_row(i + 1, cr2.rows[i], c, 16))
			var rank: int = cr2.rank
			var prize: int = cr2.prize
			if rank == 1:
				res.text.text = "You won the contest. The prize is %s coins." % D.fmt_int(prize)
			elif prize > 0:
				res.text.text = "You came %s. The prize is %s coins." % [RANKS[rank - 1].to_lower(), D.fmt_int(prize)]
			else:
				res.text.text = "You came %s. No prize this time. Try a bigger bait." % RANKS[clampi(rank - 1, 0, 3)].to_lower()
			res.head.text = "YOU WIN!" if rank == 1 else "CONTEST RESULTS"
			res.btn.set_text("COLLECT +%s" % D.fmt_int(prize) if prize > 0 else "CLOSE")
	else:
		_res_sig = ""
	# Name tags over the rivals.
	var n := c.rivals.size() if c != null and not cover and not results.visible and not card.visible else 0
	while _tags.size() < n:
		var tag := UI.px_panel(Color(BAR_BG, 0.8), UI.BORDER, 1, Vector4(4, 1, 4, 2))
		tag.mouse_filter = MOUSE_FILTER_IGNORE
		var tl := UI.label("", UI.silk, 9, UI.TEXT)
		tag.add_child(tl)
		add_child(tag)
		move_child(tag, 0)
		_tags.append(tag)
	for i in _tags.size():
		var tag: PanelContainer = _tags[i]
		if i >= n or c.rivals[i].gone:
			tag.visible = false
			continue
		var r: Dictionary = c.rivals[i]
		var tl: Label = tag.get_child(0)
		if tl.text != r.name.to_upper():
			tl.text = r.name.to_upper()
		tag.visible = true
		tag.size = Vector2.ZERO
		var sz := tag.get_combined_minimum_size()
		var cut: int = SceneView.RIVAL_CUT.get(c.boat, 4)
		var sp := display.world_to_screen(Vector2(r.x, g.SURF - 3 - (Sprites.ANGLER_H - cut) - 3))
		tag.position = Vector2(clampf(sp.x - sz.x * 0.5, 2.0, size.x - sz.x - 2.0), sp.y - sz.y)
		# A tag under the scoreboard is hidden. The scoreboard lists the names too.
		if board.visible and Rect2(tag.position, sz).intersects(Rect2(board.global_position - global_position, board.size)):
			tag.visible = false


func _update_action() -> void:
	var lbl: String = snap.get("action", "HOLD TO CAST")
	var col := UI.TEXT
	var bgc := UI.BTN
	var fill := 0.0
	var fill_col := UI.AQUA
	match g.phase:
		"aim":
			fill = g.power
			fill_col = D.mix(UI.GOOD, UI.GOLD, g.power)
		"sink":
			var f = g.fish_by_id(g.lure.eng)
			if f != null and f.st == "bite":
				bgc = UI.BAD if int(_clock * 10.0) % 2 == 0 else UI.GOLD
				col = UI.BG
				lbl = "STRIKE!"
			elif f != null and f.st == "nibble":
				lbl = "WAIT..."
				col = UI.MUTED
			else:
				lbl = "HOLD TO REEL"
		"fight":
			lbl = "HOLD TO REEL"
			fill = clampf(g.fight.get("ten", 0.0) / 1.25, 0.0, 1.0)
			fill_col = UI.GOOD if g.fight.get("ten", 0.0) < 0.85 else (UI.WARN if g.fight.get("ten", 0.0) < 1.0 else UI.BAD)
		"fly":
			lbl = "..."
		"land", "show":
			lbl = "NICE CATCH"
			col = UI.MUTED
	action.set_state(lbl, col, bgc, fill, fill_col, g.holding)


func _update_fight() -> void:
	var on := g.phase == "fight" and not g.fight.is_empty()
	fight_box.visible = on
	if not on:
		return
	var f = g.fish_by_id(g.fight.id)
	if f == null:
		return
	var A: Dictionary = Species.ALL[f.sp]
	var known := g.book_has(f.sp)
	fight_name.text = A.name if known else ("A rare visitor!" if A.r == 4 else "Something huge!" if A.r == 3 else "Something big..." if g.fight.big else "???")
	fight_dist.text = "%d M" % roundi(g.fight.d / D.PX_PER_M)
	tension.set_values(g.fight.ten, g.fight.strain, _clock)
	var stam: float = g.fight.stam
	stamina.set_value(stam, UI.GOOD if stam > 0.6 else (UI.WARN if stam > 0.25 else UI.BAD))
	var st := ""
	var sc := UI.TEXT
	if g.fight.strain > 0.05:
		st = "LET GO! THE LINE IS ABOUT TO SNAP"
		sc = UI.BAD
	elif g.fight.run > 0.0:
		st = "IT IS RUNNING. EASE OFF"
		sc = UI.WARN
	elif g.fight.slack > 1.0:
		st = "SLACK LINE. REEL IN"
		sc = UI.WARN
	elif g.holding:
		st = "REELING"
		sc = UI.GOOD
	else:
		st = "HOLD TO REEL"
		sc = UI.MUTED
	fight_state.text = st
	fight_state.add_theme_color_override("font_color", sc)


func _update_hover() -> void:
	var p := g.hover
	var touch_ok := g.T < g.hover_until
	var f = g.fish_at(p) if p.x > -50 else null
	if f == null or map.visible or card.visible or (DisplayServer.is_touchscreen_available() and not touch_ok):
		hover_box.visible = false
		return
	var A: Dictionary = Species.ALL[f.sp]
	var known := g.book_has(f.sp)
	hover_l.text = A.name if known else "???"
	hover_l.add_theme_color_override("font_color", Color(D.RARITY[A.r].col) if known else UI.MUTED)
	hover_box.visible = true
	hover_box.size = Vector2.ZERO
	var hs := g.fish_half(f)
	var sp := display.world_to_screen(Vector2(f.x, f.y - hs.y - 3.0))
	var sz := hover_box.get_combined_minimum_size()
	hover_box.position = Vector2(clampf(sp.x - sz.x * 0.5, 4.0, size.x - sz.x - 4.0), maxf(top_inset(), sp.y - sz.y))


func _layout_middle(dt: float) -> void:
	var mw := middle.size.x
	var mh := middle.size.y
	# Drawer.
	var dw := 0.0
	if drawer.visible:
		dw = mw if narrow else minf(420.0, mw)
		drawer.size = Vector2(dw, mh)
		drawer.position = Vector2(mw - dw, 0)
	# Toasts across the top.
	if not _toast_wait.is_empty() and not card.visible:
		var t: Array = _toast_wait.pop_front()
		_on_toast(t[0], t[1])
	for box in toast_box.get_children():
		var l: Label = box.get_child(0)
		var w := _toast_w(float(l.get_meta("tw", 0.0)))
		if absf(l.custom_minimum_size.x - w) > 0.5:
			l.custom_minimum_size.x = w
	toast_box.size = Vector2(mw - (dw if not narrow else 0.0), 0)
	toast_box.position = Vector2(0, 0)
	# The contest button sits top left. The scoreboard sits top right of the free space.
	var bw0 := 0.0
	if cup_chip.visible:
		cup_chip.size = cup_chip.get_combined_minimum_size()
		cup_chip.position = Vector2(0, 0)
	if board.visible:
		var bs0 := board.get_combined_minimum_size()
		board.size = bs0
		bw0 = bs0.x
		var fw0 := mw - (dw + 12.0 if dw > 0.0 and not narrow else 0.0)
		board.position = Vector2(fw0 - bs0.x, 0)
		if narrow:
			toast_box.position.y = bs0.y + 6.0
	var free_w := mw - (dw + 12.0 if dw > 0.0 and not narrow else 0.0)
	# Message in the upper middle.
	msg_l.visible = g.msg_t > 0.0
	if msg_l.visible:
		msg_l.text = g.msg
		msg_l.modulate.a = clampf(g.msg_t / 0.4, 0.0, 1.0)
		msg_l.size = Vector2(free_w, 0)
		msg_l.position = Vector2(0, mh * 0.28)
	# Fight meter at the bottom.
	if fight_box.visible:
		var fw := minf(420.0, free_w)
		if short and board.visible:
			fw = minf(fw, free_w - 2.0 * (bw0 + 8.0))
		fight_box.size = Vector2(fw, 0)
		var fs := fight_box.get_combined_minimum_size()
		fight_box.size = Vector2(fw, fs.y)
		# On a short screen the meter goes over the sky, so it does not hide the water.
		fight_box.position = Vector2((free_w - fw) * 0.5, 0.0 if short else mh - fs.y)
	# Hint above the bottom bar.
	var hint: String = snap.get("hint", "")
	hint_box.visible = hint != "" and not drawer.visible and not card.visible and not fight_box.visible
	if hint_box.visible:
		if hint_l.text != hint:
			hint_l.text = hint
		var tw := UI.pix.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 2.0
		var w := minf(tw, minf(560.0, free_w - 40.0))
		hint_l.custom_minimum_size.x = w
		hint_box.size = Vector2(w + 28.0, 0)
		var hs := hint_box.get_combined_minimum_size()
		hint_box.size = hs
		hint_box.position = Vector2((free_w - hs.x) * 0.5, mh - hs.y)
	# Catch card in the center.
	if card.visible:
		var cw := minf(600.0 if short else 400.0, mw - 16.0)
		card.size = Vector2(cw, 0)
		var cs := card.get_combined_minimum_size()
		card.size = Vector2(cw, cs.y)
		var cy := (mh - cs.y) * 0.5
		if cs.y > mh:
			# The card is taller than the free space. Center it on the whole screen, over the bars.
			var top := middle.global_position.y - global_position.y
			cy = maxf(4.0 - top, (size.y - cs.y) * 0.5 - top)
		card.position = Vector2((mw - cw) * 0.5, cy)
	# Contest results in the center.
	if results.visible:
		var rw := minf(380.0, mw - 16.0)
		results.size = Vector2(rw, 0)
		var rs := results.get_combined_minimum_size()
		results.size = Vector2(rw, rs.y)
		var ry := (mh - rs.y) * 0.5
		if rs.y > mh:
			var top := middle.global_position.y - global_position.y
			ry = maxf(4.0 - top, (size.y - rs.y) * 0.5 - top)
		results.position = Vector2((mw - rw) * 0.5, ry)
	# Bait picker above the bait button.
	if bait_pop.visible:
		var bs := bait_pop.get_combined_minimum_size()
		bait_pop.size = bs
		var bx := bait_btn.global_position.x - middle.global_position.x
		bait_pop.position = Vector2(clampf(bx, 0.0, mw - bs.x), maxf(mh - bs.y, 4.0 - (middle.global_position.y - global_position.y)))
	# Arrival banner. It fades out early when the player starts to fish or opens a panel.
	_banner_t += dt
	var busy := drawer.visible or card.visible or results.visible or bait_pop.visible or toast_box.get_child_count() > 0 or g.phase != "idle"
	if busy and _banner_t > 0.4 and _banner_t < 4.2:
		_banner_t = 4.2
	banner.visible = _banner_t < 5.0 and not map.visible
	if banner.visible:
		var bw := minf(520.0, mw - 24.0)
		banner_blurb.custom_minimum_size.x = bw - 44.0
		banner.size = Vector2(bw, 0)
		var bs := banner.get_combined_minimum_size()
		banner.size = Vector2(bw, bs.y)
		banner.position = Vector2((mw - bw) * 0.5, mh * (0.04 if short else 0.12))
		var a := 1.0
		if _banner_t < 0.4:
			a = _banner_t / 0.4
		elif _banner_t > 4.2:
			a = (5.0 - _banner_t) / 0.8
		banner.modulate.a = clampf(a, 0.0, 1.0)


## The big hold button. It reports press and release so the game can charge and reel.
class ActionButton:
	extends Control
	signal down
	signal up

	var text := "HOLD TO CAST"
	var fg := UI.TEXT
	var bg := UI.BTN
	var fill := 0.0
	var fill_col := UI.AQUA
	var pressed_now := false
	var _held := false

	func _init() -> void:
		custom_minimum_size = Vector2(200, 48)
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		focus_mode = FOCUS_NONE

	func set_state(t: String, c: Color, b: Color, f: float, fc: Color, p: bool) -> void:
		if t != text or c != fg or b != bg or absf(f - fill) > 0.001 or fc != fill_col or p != pressed_now:
			text = t
			fg = c
			bg = b
			fill = f
			fill_col = fc
			pressed_now = p
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed and not _held:
				_held = true
				down.emit()
			elif not e.pressed and _held:
				_held = false
				up.emit()
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_held = false
			up.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, D.dark(bg, 0.2) if pressed_now else bg)
		if fill > 0.0:
			draw_rect(Rect2(0, size.y - 6, size.x * fill, 6), fill_col)
		var fs := 14
		var tw := UI.silk.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var p := Vector2((size.x - tw.x) * 0.5, (size.y + fs * 0.75) * 0.5 - 2.0)
		draw_string(UI.silk, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.4))
		draw_string(UI.silk, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## The line tension meter. Green is safe, orange is close, red snaps the line.
class TensionBar:
	extends Control
	var ten := 0.0
	var strain := 0.0
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 16)
		size_flags_horizontal = SIZE_EXPAND_FILL
		mouse_filter = MOUSE_FILTER_IGNORE

	func set_values(v: float, s: float, clock: float) -> void:
		ten = v
		strain = s
		t = clock
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var mx := 1.25
		draw_rect(Rect2(-2, -2, w + 4, h + 4), UI.BORDER)
		draw_rect(Rect2(0, 0, w, h), UI.BG)
		var z1 := w * 0.85 / mx
		var z2 := w * 1.0 / mx
		draw_rect(Rect2(0, 0, z1, h), Color(UI.GOOD, 0.18))
		draw_rect(Rect2(z1, 0, z2 - z1, h), Color(UI.WARN, 0.22))
		draw_rect(Rect2(z2, 0, w - z2, h), Color(UI.BAD, 0.28))
		var fw := clampf(ten / mx, 0.0, 1.0) * w
		var c := UI.GOOD if ten < 0.85 else (UI.WARN if ten < 1.0 else UI.BAD)
		if ten >= 1.0 and int(t * 10.0) % 2 == 0:
			c = Color.WHITE
		draw_rect(Rect2(0, 3, fw, h - 6), c)
		draw_rect(Rect2(fw - 2, 0, 4, h), Color.WHITE)
		if strain > 0.0:
			draw_rect(Rect2(0, h - 3, w * clampf(strain, 0.0, 1.0), 3), UI.BAD)
		draw_rect(Rect2(z2 - 1, -2, 2, h + 4), UI.BAD)


## Four corner marks. They point out for "go full screen" and in for "leave full screen".
class FullIcon:
	extends Control
	var on := false

	func _init() -> void:
		custom_minimum_size = Vector2(18, 16)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_on(v: bool) -> void:
		if v != on:
			on = v
			queue_redraw()

	func _draw() -> void:
		var arm := 6.0
		for cx in [0, 1]:
			for cy in [0, 1]:
				# The corner point and the directions of its two arms.
				var p := Vector2(1.0 if cx == 0 else size.x - 1.0, 1.0 if cy == 0 else size.y - 1.0)
				var d := Vector2(1.0 if cx == 0 else -1.0, 1.0 if cy == 0 else -1.0)
				if on:
					p += d * (arm - 1.0)
					d = -d
				draw_line(p, p + Vector2(d.x * arm, 0.0), UI.TEXT, 2.0)
				draw_line(p, p + Vector2(0.0, d.y * arm), UI.TEXT, 2.0)


## A small gold trophy.
class CupIcon:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var g1 := UI.GOLD
		var g2 := D.dark(UI.GOLD, 0.3)
		draw_rect(Rect2(2, 0, 8, 1), g1)
		draw_rect(Rect2(2, 1, 8, 4), g1)
		draw_rect(Rect2(3, 5, 6, 1), g1)
		draw_rect(Rect2(8, 1, 1, 4), g2)
		draw_rect(Rect2(0, 1, 2, 1), g1)
		draw_rect(Rect2(0, 2, 1, 2), g1)
		draw_rect(Rect2(10, 1, 2, 1), g1)
		draw_rect(Rect2(11, 2, 1, 2), g1)
		draw_rect(Rect2(5, 6, 2, 3), g2)
		draw_rect(Rect2(3, 9, 6, 2), g1)
		draw_rect(Rect2(3, 1, 1, 2), Color(1, 1, 1, 0.6))
