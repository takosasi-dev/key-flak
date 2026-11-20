# 画面の切り替え(S0〜S5)・入力の振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。作りは RootCall の ui/main.gd。
# --auto で S0 → タイトル → 今日の空(迎える bot)→ 結果 → もう1回 → 結果 を自動で通して終わる(ヘッドレスの smoke。Web では効かない)。
# ?debug=1(または --debug)で window.kfState に状態を出す(読むだけ。tests/web が読む)。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Bots := preload("res://core/bots.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")

var stage: Control
var store: Store
var screen := "gate"  # gate / title / play / result / settings
var current: Control = null  # 今の画面(play の時は play)
var play: Play = null
var pause_view: Pause = null
var settings_from := "title"
var run := {}  # 今の回 { mode, seed, day, date }
var auto := false
var debug := false
var frame_ms: Array = []  # フレームの間隔(ms。tests/web が読む)
var _last_frame := 0
var lat_ms: Array = []  # 離してから爆発を描くまで(NFR-2)
var _touch_note: Label = null
var _visibility_cb: Variant = null
var _auto_results := 0
var _auto_keys := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	# 窓の縦横比が違う時は、余りを背景色で埋めてステージを真ん中に置く(共通 §3 の 1。stretch の aspect は expand)
	get_viewport().size_changed.connect(_center_stage)
	_center_stage()
	var bg := ColorRect.new()
	bg.color = Kit.C_BG
	stage.add_child(Kit.place(bg, -2000, -2000, 5280, 4720))
	store = Store.new()
	_apply_settings()
	debug = _flag("debug")
	auto = _flag("auto") and not OS.has_feature("web")  # 公開版では効かせない(bot の点を保存しない)
	if auto:
		Engine.time_scale = 4.0  # 1 フレーム 8 tick(上限)で進める
	_watch_visibility()
	RenderingServer.frame_post_draw.connect(_after_draw)
	_show_gate()


func _center_stage() -> void:
	stage.position = ((get_viewport().get_visible_rect().size - stage.size) / 2.0).round()


static func _flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		return q is String and q.contains(flag + "=1")
	return OS.get_cmdline_user_args().has("--" + flag)


func _apply_settings() -> void:
	Sfx.set_volume(int(store.settings()["volume"]))


func _clear() -> void:
	if pause_view != null:
		pause_view.queue_free()
		pause_view = null
	for c in stage.get_children():
		if c is ColorRect and c.get_index() == 0:
			continue
		c.queue_free()
	current = null
	play = null


# --- S0 始める ---

func _show_gate() -> void:
	_clear()
	screen = "gate"
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 220, 1280, 100))
	g.add_child(Kit.place(Kit.label(S.S0_START, 28, Kit.C_TEXT, 500), 0, 360, 1280, 44))
	g.add_child(Kit.place(Kit.label(S.S0_KEYBOARD, 18, Kit.C_DIM), 0, 410, 1280, 30))
	_touch_note = Kit.label(S.TOUCH, 22, Kit.C_WARN, 700)
	_touch_note.visible = false
	g.add_child(Kit.place(_touch_note, 0, 470, 1280, 40))
	stage.add_child(g)
	current = g


func _input(event: InputEvent) -> void:
	if screen == "gate":
		if event is InputEventScreenTouch and event.pressed:
			_touch_note.visible = true  # FR-26: タッチで開いた人に伝える
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # タッチから作られたマウスのイベント
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			Sfx.unlock()  # FR-24: この入力は数えない
			get_viewport().set_input_as_handled()
			_show_title()
		return
	if not (event is InputEventKey):
		return
	if screen != "play" and (event.ctrl_pressed or event.meta_pressed or event.alt_pressed):
		return  # 結果の枠の Ctrl+C などは部品に渡す(FR-25: ゲームの操作には数えない)
	get_viewport().set_input_as_handled()  # 矢印・Space を Godot のフォーカスの移動に使わせない
	if screen == "settings":
		current.key(event)
	elif pause_view != null:
		pause_view.key(event)
	elif current != null and current.has_method("key"):
		current.key(event)


# --- S1 タイトル ---

func _show_title() -> void:
	_clear()
	screen = "title"
	var d := _today()
	var t := Title.new()
	t.build(store, d["day"], d["date"])
	t.chosen.connect(_on_title)
	stage.add_child(t)
	current = t


func _on_title(what: String) -> void:
	var d := _today()
	match what:
		"settings":
			_show_settings("title")
		"daily":
			_start({"mode": Sim.MODE_DAILY, "seed": Day.day_seed(d["day"]), "day": d["day"], "date": d["date"]})
		"practice":
			var s := Time.get_ticks_usec() & 0xFFFFFFFF
			_start({"mode": Sim.MODE_PRACTICE, "seed": s if s != 0 else 1, "day": d["day"], "date": d["date"]})


# 端末の今日の日付。始めた時の日付で空を決める(E-15)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	return {"day": Day.day_index(y, m, dd), "date": Day.date_string(y, m, dd)}


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
	_clear()
	run = r
	screen = "play"
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	stage.add_child(play)
	play.start(int(r["mode"]), int(r["seed"]))
	if auto:
		play.bot = Bots.new(Bots.INTERCEPT)
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	current = play


# もう1回・やり直す。今日の空は同じ種、練習は毎回ちがう空(種を引き直す)。
func _again() -> void:
	if int(run["mode"]) == Sim.MODE_PRACTICE:
		var s := Time.get_ticks_usec() & 0xFFFFFFFF
		run["seed"] = s if s != 0 else 1
	_start(run)


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	play.cancel_input()  # FR-23: 照準を全部取り消す(弾は減らさない)
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			pause_view.queue_free()
			pause_view = null
			play.paused = false  # 押した tick から再開(待ち時間なし)
		"restart":
			_again()
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focus_lost()


# フォーカスが外れた・タブが裏に回った(E-11)。押されている組を空にし、プレイ中なら一時停止。戻っても自動では再開しない。
func _focus_lost() -> void:
	if play != null:
		play.cancel_input()
	if screen == "settings" and current != null:
		current.release_all()
	_pause()


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(ParryDuel と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _focus_lost())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary) -> void:
	var r := run
	var rec := store.record(int(r["mode"]), int(r["day"]), result)
	var text := Share.make(r["date"], int(r["mode"]), rec["first_today"], result)
	_clear()
	screen = "result"
	var v := Result.new()
	v.build(int(r["mode"]), result, rec, text)
	v.retry.connect(_again)  # FR-18: 同じ入口
	v.to_title.connect(_show_title)
	stage.add_child(v)
	current = v
	if auto:
		_auto_results += 1
		print("SMOKE result %d: %s" % [_auto_results, JSON.stringify(result)])
		print(text)


# --- S4 設定 ---

var _settings_overlay: Control = null


func _show_settings(from: String) -> void:
	settings_from = from
	var s := Settings.new()
	s.build(store)
	s.back.connect(_settings_back.bind(s))
	if from == "pause":
		pause_view.visible = false
		var dim := ColorRect.new()
		dim.color = Color(Kit.C_BG, 0.96)
		s.add_child(Kit.place(dim, -2000, -2000, 5280, 4720))
		s.move_child(dim, 0)
		stage.add_child(s)
		current = s
		screen = "settings"
		pause_view.process_mode = Node.PROCESS_MODE_DISABLED
		_settings_overlay = s
	else:
		_clear()
		screen = "settings"
		stage.add_child(s)
		current = s


func _settings_back(s: Control) -> void:
	_apply_settings()
	if settings_from == "pause" and play != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.reduce_flash = st["reduce_flash"]
		s.queue_free()
		_settings_overlay = null
		pause_view.visible = true
		pause_view.process_mode = Node.PROCESS_MODE_INHERIT
		current = play
		screen = "play"
	else:
		_show_title()


# --- 自動の確かめ(smoke)と測定 ---

func _process(_delta: float) -> void:
	if not auto:
		return
	match screen:
		"gate":
			print("SMOKE gate")
			_input(_key(KEY_X))
		"title":
			print("SMOKE title")
			if not _auto_keys:
				_input(_key(KEY_DOWN))
				_input(_key(KEY_DOWN))
				_input(_key(KEY_ENTER))  # 設定
			else:
				_input(_key(KEY_ENTER))  # 今日の空
		"settings":
			# 設定 → キーの確かめ → A を押す → 戻る(一時停止から開いた時の図も描く)
			if not current.keys_view and current.keys_drawn == 0:
				for k in 3:
					_input(_key(KEY_DOWN))
				_input(_key(KEY_ENTER))
				_input(_key(KEY_A))
			elif current.keys_view and current.keys_drawn > 0:
				print("SMOKE keys drawn %d held %d" % [current.keys_drawn, current.held.size()])
				_auto_keys += 1
				_input(_key(KEY_ESCAPE))
				_input(_key(KEY_ESCAPE))
		"play":
			# 1 回目の回の途中で 1 度、一時停止 → 設定 → キーの確かめ → 戻る → 続ける
			if _auto_keys == 1 and play.sim.tick > 600 and pause_view == null:
				_input(_key(KEY_ESCAPE))
				_input(_key(KEY_DOWN))
				_input(_key(KEY_DOWN))
				_input(_key(KEY_ENTER))
			elif _auto_keys == 2 and pause_view != null:
				print("SMOKE pause back")
				_auto_keys += 1
				_input(_key(KEY_ESCAPE))
		"result":
			if not current._retry.disabled:
				if _auto_results >= 2:
					print("SMOKE done")
					get_tree().quit(0)
					auto = false
				else:
					_input(_key(KEY_ENTER))  # もう1回


static func _key(pk: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	return e


func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000:
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if play != null and play.burst_seen_at > 0 and play.release_at > 0:
		if lat_ms.size() < 2000:
			lat_ms.append((now - play.release_at) / 1000.0)
		play.release_at = 0
		play.burst_seen_at = 0
	if debug and OS.has_feature("web"):
		JavaScriptBridge.eval("window.kfState=" + JSON.stringify(JSON.stringify(state())), true)
		if frame_ms.size() % 60 == 0:
			JavaScriptBridge.eval("window.kfStats=" + JSON.stringify(JSON.stringify(stats())), true)


# --- デバッグ用の窓口(読むだけ) ---

func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null, "version": S.VERSION, "buttons": {}, "sfx": Sfx.played,
		"unlocked": Sfx.unlocked, "save_failed": store.write_failed, "load_failed": store.load_failed}
	var root: Control = pause_view if pause_view != null and pause_view.visible else current
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				var c := btn.global_position - stage.global_position + btn.size / 2  # ゲームの座標(1280×720)
				out["buttons"][String(btn.name)] = [c.x, c.y]
	if screen == "settings" and current != null:
		out["keys_view"] = current.keys_view
		out["keys_held"] = current.held.keys()
	if play != null and play.sim != null:
		var sim := play.sim
		var ms: Array = []
		for m: Dictionary in sim.missiles:
			ms.append([snappedf(m["x"], 0.1), snappedf(m["y"], 0.1), snappedf(m["vx"], 0.001), snappedf(m["vy"], 0.001), m["col"], m["kind"], m["id"]])
		var ls: Array = []
		for i in B.COLS:
			ls.append([sim.ammo[i], sim.disabled[i], snappedf(Sim.aim_y(sim.aim_h[i]), 0.1) if sim.aim_h[i] >= 0 else -1.0])
		out["play"] = {"tick": sim.tick, "wave": sim.wave, "points": sim.points, "kills": sim.kills, "towns": sim.town_count(),
			"chain": sim.chain_now(), "max_chain": sim.max_chain, "intermission": sim.intermission > 0, "over": sim.over,
			"missiles": ms, "bombers": sim.bombers.size(), "bursts": sim.bursts.size(), "launchers": ls, "held": play.held.keys(),
			"pos": [play.position.x, play.position.y]}
	return out


func stats() -> Dictionary:
	return {"frame": _pct(frame_ms), "lat": _pct(lat_ms)}


static func _pct(a: Array) -> Dictionary:
	if a.is_empty():
		return {"n": 0}
	var s := a.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[mini(int(s.size() * 0.95), s.size() - 1)], "max": s[-1]}
