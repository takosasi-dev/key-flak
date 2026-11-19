# S2 プレイ(画面設計書 §3)。押されているキーの組を持ち、押す・離すを sim に渡し、たまった時間ぶん進める(1 フレーム 8 tick まで)。
# events で演出(§9.9)と音を出し、snapshot から空・発射台・町を描く。ゲームの決まりは持たない(INV-1)。
# 押されているキーの組は ui が持つ(共通 §3 の 5)。フォーカスが外れたら空にし、sim へ「離す」は送らない。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Sch := preload("res://core/schedule.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")

var sim: Sim = null
var mode := 0
var seed_value := 1
var paused := false
var shake_on := true
var reduce_flash := false
var held := {}  # 押されている発射台の番号
var bot: RefCounted = null  # 自動の確かめ(smoke)の時だけ。step ごとに act(sim) を呼ぶ
var release_at := 0  # 最後に「離す」を受けた時刻(usec。描くまでを測る)
var burst_seen_at := 0  # その「離す」で爆発の出来事を受けた時刻(0 なら無し)
var cost_us: Array = []  # 1 フレームの _process と _draw の時間(usec。負荷の測定が読む)
var draws := 0

var _acc := 0.0
var _over_at := -1
var _shake_until := 0
var _shake_px := 0.0
var _snap := {}
var _bar := {}
var _banner: Label
var _bonus: Label
var _ime: Label
var _esc: Button
var _popups: Array = []  # { pos, text, at, big }
var _lit := {}  # 発射台 → 光らせる種類と時刻 { kind: "empty"/"disabled", at }
var _crumble := {}  # 列 → 崩れ始めた時刻
var _impact_at := -100000
var _banner_until := 0
var _clear := {}  # 波をしのいだ時の { wave, bonus, towns, ammo, at }
var _aim_voice := {}
var _ime_until := 0
var _proc_us := 0


func _ready() -> void:
	size = Vector2(1280, 720)
	_esc = Kit.place(Kit.button("Esc", S.ESC, 20), 24, 12, 72, 40)
	_esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(_esc)
	for k: String in ["wave", "points", "chain"]:
		var l := Kit.label("", 26, Kit.C_TEXT, 700)
		add_child(l)
		_bar[k] = l
	_bar["wave"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	Kit.place(_bar["wave"], 124, 8, 400, 48)
	Kit.place(_bar["points"], 440, 8, 400, 48)
	_bar["chain"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Kit.place(_bar["chain"], 856, 8, 400, 48)
	_banner = Kit.label("", 48, Kit.C_TEXT, 800)
	add_child(Kit.place(_banner, 0, 260, 1280, 80))
	_bonus = Kit.label("", 26, Kit.C_TEXT, 500)
	add_child(Kit.place(_bonus, 0, 340, 1280, 44))
	_ime = Kit.label(S.IME, 22, Kit.C_WARN, 700)
	_ime.visible = false
	add_child(Kit.place(_ime, 0, 400, 1280, 40))


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	held.clear()
	_acc = 0.0
	_over_at = -1
	_popups.clear()
	_lit.clear()
	_crumble.clear()
	_clear = {}
	_show_banner(S.BAR_WAVE % 1)
	_refresh()


func is_playing() -> bool:
	return sim != null and not sim.is_over()


# S2 のキー。Esc は一時停止、中の段の 10 キーは発射台。Space・Enter などは何もしない(画面設計書 §7)。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if sim == null or sim.is_over() or paused:
		return
	var i := Keymap.index_of(ev)
	if i < 0:
		if ev.pressed and ev.physical_keycode == 0:
			_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9
		return
	if ev.pressed:
		if ev.echo or Keymap.has_modifier(ev) or held.has(i):
			return  # FR-25・E-3
		held[i] = true
		sim.queue_press(i)
	elif held.has(i):
		held.erase(i)
		sim.queue_release(i)
		release_at = Time.get_ticks_usec()
		burst_seen_at = 0


# 一時停止・フォーカスが外れた時(FR-23・共通 §3 の 5)。照準を取り消し、押されている組を空にする。「離す」は送らない。
func cancel_input() -> void:
	held.clear()
	if sim != null:
		sim.cancel_all_aims()
		for e: Dictionary in sim.events():
			_on_event(e)
	_refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	_ime.visible = now < _ime_until
	if _over_at >= 0:
		if now - _over_at >= B.OVER_MS:
			_over_at = -2
			finished.emit(sim.result())
		queue_redraw()
		return
	if paused or _over_at == -2:
		return
	_acc += delta * B.TICK_HZ
	var n := int(_acc)
	_acc -= n
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-20: 超えた分は捨てる
		_acc = 0.0
	for k in n:
		if bot != null:
			bot.act(sim)
		sim.step()
		for e: Dictionary in sim.events():
			_on_event(e)
		if sim.is_over():
			break
	_refresh()
	_proc_us = Time.get_ticks_usec() - t0


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner_until = Time.get_ticks_msec() + B.WAVE_BANNER_MS


# 演出の表(§9.9)。events を受けたフレームに始める(FR-14)。
func _on_event(e: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	match e["type"]:
		"aim_start":
			_aim_voice[e["i"]] = Sfx.play("aim")
		"burst":
			Sfx.stop(_aim_voice.get(e["i"]))
			_aim_voice.erase(e["i"])
			Sfx.play("burst")
			if release_at > 0 and burst_seen_at == 0:
				burst_seen_at = Time.get_ticks_usec()
		"aim_cancel":
			Sfx.stop(_aim_voice.get(e["i"]))
			_aim_voice.erase(e["i"])
		"kill":
			var n: int = e["n"]
			var big: bool = n >= 3 or e["bomber"]
			_popups.append({"pos": Vector2(e["x"], e["y"]), "text": S.POPUP % int(e["points"]), "at": now, "big": big})
			Sfx.play("kill", mini(n - 1, B.KILL_PITCH_MAX))
			if big:
				_shake(B.SHAKE_KILL_PX, B.SHAKE_KILL_MS)
		"empty", "disabled":
			_lit[e["i"]] = {"kind": e["type"], "at": now}
			Sfx.play(e["type"])
		"impact":
			_impact_at = now
			if e["lost"]:
				_crumble[e["col"]] = now
			Sfx.play("impact")
			_shake(B.SHAKE_IMPACT_PX, B.SHAKE_IMPACT_MS)
		"wave_clear":
			_clear = {"wave": e["wave"], "bonus": e["bonus"], "towns": e["towns"], "ammo": e["ammo"], "at": now}
			Sfx.play("wave_clear")
		"wave_start":
			_clear = {}
			_show_banner(S.BAR_WAVE % int(e["wave"]))
			Sfx.play("wave_start")
		"over":
			Sfx.play("over")
			_over_at = now


func _shake(px: float, ms: int) -> void:
	_shake_px = px
	_shake_until = Time.get_ticks_msec() + ms


func _refresh() -> void:
	_snap = sim.snapshot()
	var now := Time.get_ticks_msec()
	_bar["wave"].text = S.WAVE_CLEAR % int(_clear["wave"]) if not _clear.is_empty() else S.BAR_WAVE % int(_snap["wave"])
	_bar["points"].text = S.BAR_POINTS % Score.comma(int(_snap["points"]))
	var chain: int = _snap["chain"]
	_bar["chain"].text = S.BAR_CHAIN % chain if chain >= 2 else ""
	if not _clear.is_empty():
		# 波の間: 中央に「波 n をしのいだ」とボーナスの数え上げ(1.5 秒)
		var t := clampf(float(now - int(_clear["at"])) / B.CLEAR_COUNT_MS, 0.0, 1.0)
		_banner.text = S.WAVE_CLEAR % int(_clear["wave"])
		_bonus.text = S.BONUS_LINE % [S.BONUS_TOWN, int(_clear["towns"]), S.BONUS_AMMO, int(_clear["ammo"]), Score.comma(int(int(_clear["bonus"]) * t))]
		_banner.visible = true
		_bonus.visible = true
	else:
		_banner.visible = now < _banner_until
		_bonus.visible = false
	queue_redraw()


func _draw() -> void:
	if _snap.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	draws += 1
	var now := Time.get_ticks_msec()
	Kit.draw_sky(self)
	# 落ちる先の印(着弾 1 秒前)
	for c: int in _snap["impact_marks"]:
		var x := Kit.col_x(c)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 10, B.GROUND_Y - 26), Vector2(x + 10, B.GROUND_Y - 26), Vector2(x, B.GROUND_Y - 10)]), Kit.C_MARK)
	# ミサイル: 出た所から先頭までの線と、種類ごとの先頭の形(色だけで分けない。NFR-11)
	for m: Dictionary in _snap["missiles"]:
		var head := Vector2(m["x"], m["y"])
		var from := Vector2(m["sx"], m["sy"])
		match int(m["kind"]):
			Sch.SPLIT:
				draw_line(from, head, Color(Kit.C_SPLIT, 0.7), 2.0)
				for k in 3:
					var o := Vector2((k - 1) * 7.0, 0)
					draw_colored_polygon(PackedVector2Array([head + o + Vector2(-4, -3), head + o + Vector2(4, -3), head + o + Vector2(0, 5)]), Kit.C_SPLIT)
			Sch.FAST:
				var d := (head - from).normalized().orthogonal() * 2.5
				draw_line(from + d, head + d, Color(Kit.C_FAST, 0.7), 1.5)
				draw_line(from - d, head - d, Color(Kit.C_FAST, 0.7), 1.5)
				draw_colored_polygon(PackedVector2Array([head + Vector2(0, -7), head + Vector2(6, 0), head + Vector2(0, 7), head + Vector2(-6, 0)]), Kit.C_FAST)
			_:
				draw_line(from, head, Color(Kit.C_MISSILE, 0.7), 2.0)
				draw_circle(head, 4.0, Kit.C_MISSILE)
	# 爆撃機: 横長の六角形
	for bm: Dictionary in _snap["bombers"]:
		var p := Vector2(bm["x"], bm["y"])
		draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 0), p + Vector2(-18, -10), p + Vector2(18, -10), p + Vector2(30, 0), p + Vector2(18, 10), p + Vector2(-18, 10)]), Kit.C_BOMBER)
	# 爆発: 縁の太い円
	for b: Dictionary in _snap["bursts"]:
		var r: float = b["r"]
		if r <= 0.0:
			continue
		var c: Color = Kit.C_CHAIN if b["chain"] else Kit.C_BURST
		var at := Vector2(b["x"], b["y"])
		draw_circle(at, r, Color(c, 0.18))
		draw_arc(at, r, 0, TAU, 40, c, 4.0, true)
	# 照準: 発射台から高さまでの点線と、幅 96 の横線
	var ls: Array = _snap["launchers"]
	for i in B.COLS:
		var ay: float = ls[i]["aim_y"]
		if ay >= 0.0:
			var x := Kit.col_x(i)
			draw_dashed_line(Vector2(x, B.GROUND_Y - 30), Vector2(x, ay), Kit.C_AIM, 2.0, 8.0)
			draw_line(Vector2(x - B.AIM_LINE_W / 2, ay), Vector2(x + B.AIM_LINE_W / 2, ay), Kit.C_AIM, 3.0)
	# 地面・町・発射台・キーの文字・弾
	Kit.draw_ground(self)
	var towns: Array = _snap["towns"]
	for c in B.TOWN_COLS:
		var ruin := 0.0
		if not towns[c]:
			ruin = clampf(float(now - int(_crumble.get(c, -100000))) / B.CRUMBLE_MS, 0.0, 1.0)
		Kit.draw_town(self, Kit.col_x(c), ruin)
	var f := Kit.font(700)
	for i in B.COLS:
		var x := Kit.col_x(i)
		var off: bool = ls[i]["disabled"]
		var lit := held.has(i) and float(ls[i]["aim_y"]) >= 0.0
		Kit.draw_launcher(self, x, off, lit)
		var flash: Dictionary = _lit.get(i, {})
		var flashing := not flash.is_empty() and now - int(flash["at"]) < B.FLASH_MS
		if flashing and flash["kind"] == "disabled":
			Kit.draw_cross(self, Vector2(x, B.GROUND_Y - 44), 14.0, Kit.C_EMPTY)
		draw_string(f, Vector2(x - 40, 678), S.KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, 80, 26, Kit.C_TEXT if not off else Kit.C_OFF)
		var red: bool = flashing and flash["kind"] == "empty"
		for k in B.AMMO_PER_WAVE:
			var p := Vector2(x - 16 + 16 * k, 700)
			if k < int(ls[i]["ammo"]):
				draw_circle(p, 5.0, Kit.C_AIM if not off else Kit.C_OFF)
			else:
				draw_arc(p, 5.0, 0, TAU, 16, Kit.C_EMPTY if red else Kit.C_OFF, 1.5, true)
	# 着弾の閃光(点滅を弱める時は不透明度 20%)
	var ft := float(now - _impact_at) / B.IMPACT_FLASH_MS
	if ft < 1.0:
		var a := (B.REDUCED_FLASH_ALPHA if reduce_flash else 0.6) * (1.0 - ft)
		draw_rect(Rect2(0, B.GROUND_Y - 40, B.SCREEN_W, 48), Color(1, 1, 1, a))
	# 浮かぶ点
	var keep: Array = []
	for p: Dictionary in _popups:
		var pt := float(now - int(p["at"])) / B.POPUP_MS
		if pt >= 1.0:
			continue
		keep.append(p)
		var size := int(22 * (B.POPUP_BIG if p["big"] else 1.0))
		draw_string(f, p["pos"] + Vector2(-60, -12 - 30 * pt), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(Kit.C_CHAIN if p["big"] else Kit.C_TEXT, 1.0 - pt))
	_popups = keep
	if cost_us.size() < 100000:
		cost_us.append(_proc_us + Time.get_ticks_usec() - t0)
	_proc_us = 0
