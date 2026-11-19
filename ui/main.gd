# 画面の切り替え(S0〜S5)・入力の振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。作りは RootCall の ui/main.gd。
# --auto(Web では ?auto=1)で S0 → タイトル → 今日の空(迎える bot)→ 結果 → もう1回 → 結果 を自動で通して終わる(ヘッドレスの smoke)。
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
var lat_ms: Array = []  # 離してから爆発を描くまで(NFR-2)
var _touch_note: Label = null
var _visibility_cb: Variant = null
var _auto_results := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Kit.C_BG
	stage.add_child(Kit.place(bg, -2000, -2000, 5280, 4720))
	store = Store.new()
	_apply_settings()
	auto = _flag("auto")
	if auto:
		Engine.time_scale = 4.0  # 1 フレーム 8 tick(上限)で進める
	_watch_visibility()
	RenderingServer.frame_post_draw.connect(_after_draw)
	_show_gate()


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
			_start(run)
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
	v.retry.connect(func() -> void: _start(run))  # FR-18: 同じ入口。今日の空は同じ種
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
		s.add_child(Kit.place(dim, 0, 0, 1280, 720))
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
			_input(_key(KEY_ENTER))  # 今日の空
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
	if play != null and play.burst_seen_at > 0 and play.release_at > 0:
		if lat_ms.size() < 2000:
			lat_ms.append((Time.get_ticks_usec() - play.release_at) / 1000.0)
		play.release_at = 0
		play.burst_seen_at = 0
