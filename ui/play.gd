# S2 プレイ(画面設計書 §3)。押されているキーの組を持ち、押す・離すを sim に渡し、たまった時間ぶん進める(1 フレーム 8 tick まで)。
# events で演出(§9.9 と、磨きで足した §14 の物)と音を出し、snapshot から空・発射台・町を描く。ゲームの決まりは持たない(INV-1)。
# 押されているキーの組は ui が持つ(共通 §3 の 5)。フォーカスが外れたら空にし、sim へ「離す」は送らない。
# v0.3.0(画面設計書 §10): 上の帯(硝子の板と目盛り。点を一番大きく、表示用の字体で)・空の両端の高さの物差し・キーの札。
# 飾りは全部この _draw の中で、落ちる先の印より前に描く(子の Control は印の上に重なるので、空の下の方には置かない)。
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

const POINTS_PX := 46  # 上の帯の点の大きさ(型紙の字は細いので、ゴシックの 40 より大きく)
const HINT_Y := 66.0  # 最初の案内の板の上(上の帯のすぐ下)

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
var _hint: Label
var _esc: Button
var _popups: Array = []  # { pos, text, at, big }
var _flashes: Array = []  # 白い芯の光 { pos, r, at, ms }
var _sparks: Array = []  # 落とした所の火花 { pos, at, big, turn }
var _ghosts: Array = []  # 落としたミサイルの線 { from, to, at, kind }
var _impacts: Array = []  # 着弾 { col, at }
var _heads: Array = []  # 前のフレームのミサイル [先頭, 出た所, 種類](落とした線を残すため)
var _lit := {}  # 発射台 → 光らせる種類と時刻 { kind: "empty"/"disabled", at }
var _crumble := {}  # 列 → 崩れ始めた時刻
var _banner_until := 0
var _clear := {}  # 波をしのいだ時の { wave, bonus, towns, ammo, at }
var _bump_at := -100000
var _bump_big := false
var _aim_voice := {}
var _ime_until := 0
var _proc_us := 0
var _unit: Label
var _wave_l: Label
var hint_rect := Rect2()  # 最初の案内の板(上の帯のすぐ下、案内する列の横)
var view := Rect2(0, 0, 1280, 720)  # 窓に見えている範囲(main が入れる。上の帯を横いっぱいに描く)


func _ready() -> void:
	size = Vector2(1280, 720)
	_esc = Kit.place(Kit.button("Esc", S.ESC, 18), 20, 10, 64, 36)
	_esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(_esc)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _esc.get_theme_stylebox(st).duplicate() as StyleBox
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		_esc.add_theme_stylebox_override(st, sb)  # 上の帯に収まる小さな札
	_esc.size = Vector2(64, 36)  # 余白を詰めた後に大きさを戻す(先に広がった大きさは縮まない)
	# 上の帯: 左に波、真ん中に点(一番大きい)、右に連鎖
	_wave_l = Kit.label(S.HUD_WAVE, 18, Kit.C_DIM, 700)
	_wave_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_wave_l, 100, 0, 300, B.HUD_H))
	_bar["wave"] = Kit.label("", 30, Kit.C_TEXT, 800)
	_bar["wave"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_bar["wave"], 126, 0, 120, B.HUD_H))
	_bar["points"] = Kit.num_label("", POINTS_PX)  # 結果と同じ型紙の字(0 は割れ目の無い形。tools/subset_font.py)
	add_child(Kit.place(_bar["points"], 440, 0, 400, B.HUD_H))
	_bar["points"].pivot_offset = Vector2(200, B.HUD_H / 2)
	_unit = Kit.label(S.UNIT_POINTS, 18, Kit.C_DIM, 700)
	_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_unit, 640, 6, 40, B.HUD_H - 6))
	_bar["chain_l"] = Kit.label(S.HUD_CHAIN, 18, Kit.C_DIM, 700)
	_bar["chain_l"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(_bar["chain_l"], 1000, 0, 200, B.HUD_H))
	_bar["chain"] = Kit.label("", 30, Kit.C_TEXT, 800)
	_bar["chain"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(Kit.place(_bar["chain"], 1196, 0, 64, B.HUD_H))
	# 空の真ん中の大きな字(縁取りでミサイルの線の上でも読める)
	_banner = Kit.label("", 56, Kit.C_TEXT, 800)  # 太字のゴシック(型紙の字の 1 は I に見える)。両側に目盛り
	_outline(_banner, 10)
	add_child(Kit.place(_banner, 0, 260, 1280, 80))
	_bonus = Kit.label("", 26, Kit.C_TEXT, 500)
	_outline(_bonus, 8)
	add_child(Kit.place(_bonus, 0, 340, 1280, 44))
	_ime = Kit.label(S.IME, 22, Kit.C_WARN, 700)
	_outline(_ime, 8)
	_ime.visible = false
	add_child(Kit.place(_ime, 0, 400, 1280, 40))
	# 最初の案内: 上の帯のすぐ下、案内する列の横に、硝子の板(_draw)とクリームの字。ミサイルは板の上に描く(隠さない)
	_hint = Kit.label("", 22, Kit.C_TEXT, 700)
	_hint.visible = false
	add_child(Kit.place(_hint, 0, HINT_Y, 1280, 38))


static func _outline(l: Label, px: int) -> void:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", Kit.C_BG)


func set_view(v: Rect2) -> void:
	view = v


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	held.clear()
	_acc = 0.0
	_over_at = -1
	for a: Array in [_popups, _flashes, _sparks, _ghosts, _impacts, _heads]:
		a.clear()
	_lit.clear()
	_crumble.clear()
	_clear = {}
	_show_banner(S.BAR_WAVE % 1, B.WAVE_BANNER_MS)
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


func _show_banner(text: String, ms: int, sub: String = "") -> void:
	_banner.text = text
	_bonus.text = sub
	_banner_until = Time.get_ticks_msec() + ms


# 点滅を弱める時は、白い光の不透明度を REDUCED_FLASH_ALPHA までに抑える(共通 §3 の 17)。
func flash_a(a: float) -> float:
	return minf(a, B.REDUCED_FLASH_ALPHA) if reduce_flash else a


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
			_flashes.append({"pos": Vector2(Kit.col_x(e["i"]), e["y"]), "r": B.BURST_R * 0.7, "at": now, "ms": B.BURST_FLASH_MS})
			if release_at > 0 and burst_seen_at == 0:
				burst_seen_at = Time.get_ticks_usec()
		"aim_cancel":
			Sfx.stop(_aim_voice.get(e["i"]))
			_aim_voice.erase(e["i"])
		"kill":
			var n: int = e["n"]
			var big: bool = n >= 3 or e["bomber"]
			var at := Vector2(e["x"], e["y"])
			_popups.append({"pos": at, "text": S.POPUP % int(e["points"]), "at": now, "big": big})
			_flashes.append({"pos": at, "r": B.CHAIN_R * (1.25 if big else 0.85), "at": now, "ms": B.KILL_FLASH_MS})
			_sparks.append({"pos": at, "at": now, "big": big, "turn": float(n) * 0.37})
			for list: Array in [_popups, _flashes, _sparks]:
				if list.size() > B.FX_CAP:
					list.pop_front()  # 多い場面では古い物から捨てる(描く量を抑える)
			if not e["bomber"]:
				_ghost(at)
			_bump_at = now
			_bump_big = big
			Sfx.play("kill", mini(n - 1, B.KILL_PITCH_MAX))
			if big:
				_shake(B.SHAKE_KILL_PX, B.SHAKE_KILL_MS)
		"empty", "disabled":
			_lit[e["i"]] = {"kind": e["type"], "at": now}
			Sfx.play(e["type"])
		"impact":
			_impacts.append({"col": e["col"], "at": now})
			if e["lost"]:
				_crumble[e["col"]] = now
			Sfx.play("impact")
			_shake(B.SHAKE_IMPACT_PX, B.SHAKE_IMPACT_MS)
		"wave_clear":
			_clear = {"wave": e["wave"], "bonus": e["bonus"], "towns": e["towns"], "ammo": e["ammo"], "at": now}
			Sfx.play("wave_clear")
		"wave_start":
			_clear = {}
			var w: int = e["wave"]
			var sub: String = S.WAVE_NEW[w] if w < S.WAVE_NEW.size() else ""
			_show_banner(S.BAR_WAVE % w, B.WAVE_NEW_MS if sub != "" else B.WAVE_BANNER_MS, sub)
			Sfx.play("wave_start")
		"over":
			Sfx.play("over")
			_over_at = now


# 落としたミサイルの線を、少しの間残して消す。前のフレームの先頭の中から一番近い物を選ぶ(見た目だけ)。
func _ghost(at: Vector2) -> void:
	var best: Array = []
	var best_d := 40.0 * 40.0
	for h: Array in _heads:
		var d: float = (h[0] as Vector2).distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = h
	if not best.is_empty():
		_ghosts.append({"from": best[1], "to": at, "at": Time.get_ticks_msec(), "kind": best[2]})


func _shake(px: float, ms: int) -> void:
	_shake_px = px
	_shake_until = Time.get_ticks_msec() + ms


func _refresh() -> void:
	_snap = sim.snapshot()
	var now := Time.get_ticks_msec()
	_heads.clear()
	for m: Dictionary in _snap["missiles"]:
		_heads.append([Vector2(m["x"], m["y"]), Vector2(m["sx"], m["sy"]), m["kind"]])
	_bar["wave"].text = str(int(_snap["wave"]))
	_bar["wave"].visible = _clear.is_empty()
	_wave_l.text = S.HUD_WAVE if _clear.is_empty() else S.WAVE_CLEAR % int(_clear["wave"])
	var pts := Score.comma(int(_snap["points"]))
	if _bar["points"].text != pts:
		_bar["points"].text = pts
		_unit.position.x = 640.0 + Kit.num_font().get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, POINTS_PX).x / 2.0 + 6.0
	var bt := float(now - _bump_at) / B.BUMP_MS
	var k := 1.0 + ((B.BUMP_SCALE_BIG if _bump_big else B.BUMP_SCALE) - 1.0) * (1.0 - bt) if bt < 1.0 else 1.0
	_bar["points"].scale = Vector2(k, k)
	_bar["points"].add_theme_color_override("font_color", Kit.C_CHAIN if _bump_big and bt < 1.0 else Kit.C_TEXT)
	var chain: int = _snap["chain"]
	_bar["chain"].text = str(chain) if chain >= 2 else ""
	_bar["chain_l"].visible = chain >= 2
	_bar["chain"].add_theme_color_override("font_color", Kit.C_CHAIN if chain >= 3 else Kit.C_TEXT)
	if not _clear.is_empty():
		# 波の間: 中央に「波 n をしのいだ」とボーナスの数え上げ(1.5 秒)
		var t := clampf(float(now - int(_clear["at"])) / B.CLEAR_COUNT_MS, 0.0, 1.0)
		_banner.text = S.WAVE_CLEAR % int(_clear["wave"])
		_bonus.text = S.BONUS_LINE % [int(_clear["towns"]), B.BONUS_TOWN, int(_clear["ammo"]), B.BONUS_AMMO, Score.comma(int(int(_clear["bonus"]) * t))]
		_banner.visible = true
		_bonus.visible = true
	else:
		_banner.visible = now < _banner_until
		_bonus.visible = _banner.visible and _bonus.text != ""
	_update_hint()
	queue_redraw()


# 最初の 1 本の案内: 波 1 でまだ 1 回も撃っておらず、照準も出ていない間だけ、一番低いミサイルの列のキーを示す。
func _update_hint() -> void:
	var col := hint_col()
	_hint.visible = col >= 0
	if col >= 0:
		_hint.text = S.FIRST_HINT % S.KEYS[col]
		# 板は案内する列の横へ逃がす(1 本目のミサイルはその列を落ちてくるので、板と重ねない)
		var w := Kit.font(700).get_string_size(_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 56.0
		var cx := Kit.col_x(col)
		var x := cx + 28.0 if cx + 28.0 + w <= B.SCREEN_W - 8.0 else cx - 28.0 - w
		hint_rect = Rect2(x, HINT_Y, w, _hint.size.y)
		_hint.position.x = x + 4.0
		_hint.size.x = w - 4.0


func hint_col() -> int:
	if sim == null or sim.wave != 1 or sim.shots > 0 or sim.intermission > 0 or sim.is_over():
		return -1
	if sim.aim_h.any(func(h: int) -> bool: return h >= 0):
		return -1
	var col := -1
	var low := -1.0
	for m: Dictionary in sim.missiles:
		if m["y"] > low:
			low = m["y"]
			col = m["col"]
	return col


func _draw() -> void:
	if _snap.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	draws += 1
	var now := Time.get_ticks_msec()
	Kit.draw_sky(self)
	for r: float in [150.0, 300.0, 450.0, 600.0]:
		draw_arc(Vector2(640, B.GROUND_Y), r, PI, TAU, 96, Color(Kit.C_TOWN, 0.06), 1.5, true)
	# 空の両端の高さの物差し(タイトルのレーダーと同じ目盛り。ミサイルより弱い色で、列の外に置く)
	Kit.draw_vscale(self, 2.0, B.SKY_TOP + 8.0, B.GROUND_Y - 8.0, Color(Kit.C_TOWN, 0.22), false)
	Kit.draw_vscale(self, B.SCREEN_W - 2.0, B.SKY_TOP + 8.0, B.GROUND_Y - 8.0, Color(Kit.C_TOWN, 0.22), true)
	_draw_hint_plate()
	_draw_banner_scales()
	_draw_ghosts(now)
	_draw_missiles()
	# 爆撃機: 横長の六角形
	for bm: Dictionary in _snap["bombers"]:
		var p := Vector2(bm["x"], bm["y"])
		draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 0), p + Vector2(-18, -10), p + Vector2(18, -10), p + Vector2(30, 0), p + Vector2(18, 10), p + Vector2(-18, 10)]), Kit.C_BOMBER)
		draw_line(p + Vector2(-16, 0), p + Vector2(16, 0), Kit.C_BG, 2.0)
	_draw_bursts(now)
	_draw_aims(now)
	_draw_ground(now)
	_draw_hud()
	_draw_marks(now)
	_draw_popups(now)
	if _over_at != -1:
		# 終わり: 空を止め、600 ms で暗くしてから結果へ
		var ot := 1.0 if _over_at == -2 else clampf(float(now - _over_at) / B.OVER_MS, 0.0, 1.0)
		draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(Kit.C_BG, B.OVER_DIM * ot))  # 窓の余りも暗くする
	if cost_us.size() < 100000:
		cost_us.append(_proc_us + Time.get_ticks_usec() - t0)
	_proc_us = 0


# ミサイル: 出た所から先頭までの線(先頭の近くほど明るい)と、種類ごとの先頭の形(色だけで分けない。NFR-11)。先頭には光の輪。
func _draw_missiles() -> void:
	for m: Dictionary in _snap["missiles"]:
		var head := Vector2(m["x"], m["y"])
		var from := Vector2(m["sx"], m["sy"])
		var kind := int(m["kind"])
		var c := Kit.C_SPLIT if kind == Sch.SPLIT else (Kit.C_FAST if kind == Sch.FAST else Kit.C_MISSILE)
		var dir := (head - from).normalized()
		var mid := head - dir * minf(B.TRAIL_BRIGHT, head.distance_to(from))
		draw_circle(head, B.HEAD_HALO, Color(c, 0.22))
		if kind == Sch.FAST:
			var d := dir.orthogonal() * 2.5
			for s: float in [1.0, -1.0]:
				draw_line(from + d * s, mid + d * s, Color(c, 0.35), 1.5)
				draw_line(mid + d * s, head + d * s, Color(c, 0.9), 1.5)
			draw_colored_polygon(PackedVector2Array([head + Vector2(0, -7), head + Vector2(6, 0), head + Vector2(0, 7), head + Vector2(-6, 0)]), c)
		else:
			draw_line(from, mid, Color(c, 0.35), 2.0)
			draw_line(mid, head, Color(c, 0.9), 2.0)
			if kind == Sch.SPLIT:
				for k in 3:
					var o := Vector2((k - 1) * 7.0, 0)
					draw_colored_polygon(PackedVector2Array([head + o + Vector2(-4, -3), head + o + Vector2(4, -3), head + o + Vector2(0, 5)]), c)
			else:
				draw_circle(head, 4.0, c)


# 落としたミサイルの線: 先頭の側から消えていく。
func _draw_ghosts(now: int) -> void:
	var keep: Array = []
	for g: Dictionary in _ghosts:
		var t := float(now - int(g["at"])) / B.GHOST_MS
		if t >= 1.0:
			continue
		keep.append(g)
		var kind := int(g["kind"])
		var c := Kit.C_SPLIT if kind == Sch.SPLIT else (Kit.C_FAST if kind == Sch.FAST else Kit.C_MISSILE)
		var from: Vector2 = g["from"]
		var to: Vector2 = g["to"]
		draw_line(from, to.lerp(from, t), Color(c, 0.35 * (1.0 - t)), 2.0)
	_ghosts = keep


# 爆発: 縁の太い円と外の光。生まれた時の白い芯と、落とした所の火花。
func _draw_bursts(now: int) -> void:
	for b: Dictionary in _snap["bursts"]:
		var r: float = b["r"]
		if r <= 0.0:
			continue
		var c: Color = Kit.C_CHAIN if b["chain"] else Kit.C_BURST
		var at := Vector2(b["x"], b["y"])
		draw_circle(at, r, Color(c, 0.14))
		draw_arc(at, r + 3.0, 0, TAU, 28, Color(c, 0.18), 8.0)
		draw_arc(at, r, 0, TAU, 40, c, 3.0)
	var keep: Array = []
	for f: Dictionary in _flashes:
		var t := float(now - int(f["at"])) / int(f["ms"])
		if t >= 1.0:
			continue
		keep.append(f)
		draw_circle(f["pos"], float(f["r"]) * (0.5 + 0.5 * t), Color(1, 1, 1, flash_a(B.BURST_FLASH_A * (1.0 - t))))
	_flashes = keep
	keep = []
	for s: Dictionary in _sparks:
		var t := float(now - int(s["at"])) / B.SPARK_MS
		if t >= 1.0:
			continue
		keep.append(s)
		var big: bool = s["big"]
		var n := B.SPARKS_BIG if big else B.SPARKS
		var reach := (B.SPARK_LEN_BIG if big else B.SPARK_LEN) * (1.0 - (1.0 - t) * (1.0 - t))
		var c := Color(Kit.C_CHAIN.lightened(0.0 if big else 0.5), 1.0 - t * t)
		for k in n:
			var a := float(s["turn"]) + TAU * k / n
			var d := Vector2(cos(a), sin(a))
			draw_line(s["pos"] + d * (reach * 0.55 + 4.0), s["pos"] + d * (reach + 6.0), c, 3.0 if big else 2.0)
		draw_arc(s["pos"], reach * 0.8 + 6.0, 0, TAU, 32, Color(c, 0.6 * (1.0 - t)), 2.0, true)
	_sparks = keep


# 照準: 発射台から高さまでの線(画面設計書の点線。昇る光の切れ目で点線に見せる)、幅 96 の横線、離した時の爆発の大きさの輪。
func _draw_aims(now: int) -> void:
	var ls: Array = _snap["launchers"]
	var flow := fmod(now * B.AIM_FLOW_SPEED, B.AIM_FLOW_GAP)
	for i in B.COLS:
		var ay: float = ls[i]["aim_y"]
		if ay < 0.0:
			continue
		var x := Kit.col_x(i)
		draw_circle(Vector2(x, B.GROUND_Y - 12), 34.0, Color(Kit.C_AIM, 0.16))
		draw_line(Vector2(x, B.GROUND_Y - 30), Vector2(x, ay), Color(Kit.C_AIM, 0.35), 2.0)
		var y := B.GROUND_Y - 30 - flow
		while y > ay + 4:
			draw_line(Vector2(x, y), Vector2(x, maxf(y - 8.0, ay)), Kit.C_AIM.lightened(0.3), 3.0)
			y -= B.AIM_FLOW_GAP
		draw_arc(Vector2(x, ay), B.BURST_R, 0, TAU, 40, Color(Kit.C_AIM, B.AIM_RING_A), 1.5, true)
		var half := B.AIM_LINE_W / 2
		draw_line(Vector2(x - half, ay), Vector2(x + half, ay), Color(Kit.C_AIM, 0.3), 9.0)
		draw_line(Vector2(x - half, ay), Vector2(x + half, ay), Kit.C_AIM.lightened(0.35), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, ay - 3), Vector2(x + 7, ay - 3), Vector2(x, ay - 11)]), Kit.C_AIM.lightened(0.35))


# 地面・町・発射台・キーの文字・弾、着弾の閃光と土煙、やられた町の煙。
func _draw_ground(now: int) -> void:
	var ls: Array = _snap["launchers"]
	var keep: Array = []
	for im: Dictionary in _impacts:
		var t := float(now - int(im["at"])) / B.DUST_MS
		if t >= 1.0:
			continue
		keep.append(im)
		var x := Kit.col_x(im["col"])
		var w := B.IMPACT_COL_W / 2
		var top := Color(1, 1, 1, 0)
		var bottom := Color(1, 1, 1, flash_a(B.IMPACT_FLASH_A * maxf(0.0, 1.0 - 2.0 * t)))
		draw_polygon(PackedVector2Array([Vector2(x - w * 0.5, B.GROUND_Y - B.IMPACT_COL_H), Vector2(x + w * 0.5, B.GROUND_Y - B.IMPACT_COL_H), Vector2(x + w, B.GROUND_Y + 8), Vector2(x - w, B.GROUND_Y + 8)]),
			PackedColorArray([top, top, bottom, bottom]))
		draw_arc(Vector2(x, B.GROUND_Y), B.DUST_R * (0.3 + 0.7 * t), PI, TAU, 24, Color(Kit.C_TOWN, 0.6 * (1.0 - t)), 3.0, true)
	_impacts = keep
	# 地面の下は硝子の台(キーの札を載せる。上の帯と揃える)
	var x0 := view.position.x - 8.0 - position.x
	var x1 := view.end.x + 8.0 - position.x
	draw_rect(Rect2(x0, B.GROUND_Y + 8.0, x1 - x0, view.end.y - B.GROUND_Y), Color(Kit.C_PANEL, 0.94))
	Kit.draw_scale(self, x0, x1, B.GROUND_Y + 8.0, Color(Kit.C_AMBER, 0.3), 32.0, 4)
	Kit.draw_ground(self)
	var towns: Array = _snap["towns"]
	for c in B.TOWN_COLS:
		var ruin := 0.0
		if not towns[c]:
			ruin = clampf(float(now - int(_crumble.get(c, -100000))) / B.CRUMBLE_MS, 0.0, 1.0)
			for k in 3:
				var ph := fmod(float(now) / B.SMOKE_PERIOD_MS + k / 3.0, 1.0)
				draw_circle(Vector2(Kit.col_x(c) - 20 + 18 * k + 10 * ph, B.GROUND_Y - 10 - 60 * ph), 5.0 + 10.0 * ph, Color(Kit.C_RUIN.lightened(0.2), 0.35 * (1.0 - ph)))
		Kit.draw_town(self, Kit.col_x(c), ruin)
	var hint := hint_col()
	for i in B.COLS:
		var x := Kit.col_x(i)
		var off: bool = ls[i]["disabled"]
		var lit := held.has(i) and float(ls[i]["aim_y"]) >= 0.0
		Kit.draw_launcher(self, x, off, lit)
		var flash: Dictionary = _lit.get(i, {})
		var flashing := not flash.is_empty() and now - int(flash["at"]) < B.FLASH_MS
		if flashing and flash["kind"] == "disabled":
			Kit.draw_cross(self, Vector2(x, B.GROUND_Y - 44), 14.0, Kit.C_EMPTY)
		var cap := Rect2(x - 19, 650, 38, 34)
		if i == hint and not lit:
			# 案内しているキーの札に脈打つ枠(点滅を弱める 入なら脈打たせない)
			var a := 1.0 if reduce_flash else 0.55 + 0.45 * absf(fmod(now / 500.0, 2.0) - 1.0)
			draw_rect(cap.grow(4), Color(Kit.C_AIM, a), false, 2.0)
		Kit.draw_keycap(self, cap, S.KEYS[i], 22, lit, off)
		var red: bool = flashing and flash["kind"] == "empty"
		for k in B.AMMO_PER_WAVE:
			var p := Vector2(x - 16 + 16 * k, 700)
			if k < int(ls[i]["ammo"]):
				draw_circle(p, 5.0, Kit.C_AIM if not off else Kit.C_OFF)
			else:
				draw_arc(p, 5.0, 0, TAU, 16, Kit.C_EMPTY if red else Kit.C_OFF, 1.5, true)


# 上の帯: 硝子の板を横いっぱいに、下の縁に目盛り。点・波・連鎖の字は子の Label(帯の中だけ)。
func _draw_hud() -> void:
	var x0 := view.position.x - 8.0 - position.x
	var x1 := view.end.x + 8.0 - position.x
	draw_rect(Rect2(x0, view.position.y - 8.0, x1 - x0, B.HUD_H - view.position.y + 8.0), Color(Kit.C_PANEL, 0.94))
	Kit.draw_scale(self, x0, x1, B.HUD_H, Color(Kit.C_AMBER, 0.45), 32.0, 4, true)
	Kit.draw_brackets(self, Rect2(436, 6, 408, B.HUD_H - 12), 10.0, Color(Kit.C_AMBER, 0.55), 2.0)


# 最初の案内の板(上の帯から下がる札。左に琥珀の縦線)。ミサイルより先に描くので、板の上を通るミサイルは隠れない。
func _draw_hint_plate() -> void:
	if not _hint.visible:
		return
	var r := hint_rect
	draw_rect(r, Color(Kit.C_PANEL, 0.9))
	draw_rect(r, Color(Kit.C_RULE, 0.9), false, 1.0)
	draw_line(r.position + Vector2(1.5, 0), Vector2(r.position.x + 1.5, r.end.y), Kit.C_AMBER, 3.0)


# 真ん中の大きな字(波 n・波 n をしのいだ)の両側の目盛り。空の中なので琥珀でなく字の灰色。
func _draw_banner_scales() -> void:
	if not _banner.visible:
		return
	var tw := Kit.font(800).get_string_size(_banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	var y := _banner.position.y + _banner.size.y / 2.0
	var c := Color(Kit.C_DIM, 0.55)
	Kit.draw_scale(self, 640.0 - tw / 2.0 - 160.0, 640.0 - tw / 2.0 - 28.0, y, c, 16.0, 4, true)
	Kit.draw_scale(self, 640.0 + tw / 2.0 + 28.0, 640.0 + tw / 2.0 + 160.0, y, c, 16.0, 4, true)


# 落ちる先の印(着弾 1 秒前)。発射台と町より上に、下向きの三角を出す。点滅を弱める時は脈打たせない。
func _draw_marks(now: int) -> void:
	var pulse := 1.0 if reduce_flash else 0.75 + 0.25 * absf(fmod(float(now) / B.MARK_PULSE_MS, 2.0) - 1.0)
	for c: int in _snap["impact_marks"]:
		var x := Kit.col_x(c)
		var y := B.MARK_ICON_Y
		var pts := PackedVector2Array([Vector2(x - 12, y - 18), Vector2(x + 12, y - 18), Vector2(x, y)])
		draw_colored_polygon(pts, Color(Kit.C_MARK, pulse))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(Kit.C_BG, 0.8), 1.5, true)


# 浮かぶ点: 爆発の上に、縁取りつきで。組の 3 本目以降と爆撃機は大きく、出た時に少し弾む。
func _draw_popups(now: int) -> void:
	var f := Kit.font(800)
	var keep: Array = []
	for p: Dictionary in _popups:
		var pt := float(now - int(p["at"])) / B.POPUP_MS
		if pt >= 1.0:
			continue
		keep.append(p)
		var big: bool = p["big"]
		var pop := 1.0 + (0.35 * (1.0 - pt * 5.0) if big and pt < 0.2 else 0.0)
		var px := int(22 * (B.POPUP_BIG if big else 1.0) * pop)
		var at: Vector2 = p["pos"] + Vector2(-80, -B.BURST_R - 12.0 - B.POPUP_RISE * pt)
		var a := 1.0 - pt * pt
		draw_string_outline(f, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, px, 6, Color(Kit.C_BG, a))
		draw_string(f, at, p["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, px, Color(Kit.C_CHAIN if big else Kit.C_TEXT, a))
	_popups = keep
