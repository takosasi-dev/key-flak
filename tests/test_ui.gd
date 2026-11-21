# 画面の流れのテスト(AC-20〜AC-22・FR-18・FR-23・FR-25・E-11・E-17)。main.tscn を木に置き、キーのイベントを直接渡し、
# フレームは _process を呼んで進める。作りは RootCall の tests/test_ui.gd。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Score := preload("res://core/score.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func press(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func release(m: Node, pk: int) -> void:
	m._input(kev(pk, false))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


# S0 → S1 → 今日の空
func _to_daily(m: Node) -> void:
	press(m, KEY_X)
	press(m, KEY_ENTER)


static func _finish(m: Node) -> void:
	while not m.play.sim.is_over():
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())  # 終わりの 600 ms を待たない


func test_ac20_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	press(m, KEY_X)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	eq(String(m.current.menu.buttons[0].name), "daily", "一番上は今日の空")
	press(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で今日の空")
	eq(int(m.run["mode"]), 0, "今日の空")
	press(m, KEY_F)
	frames(m, 46)  # 約 90 tick
	ok(m.play.sim.aim_h[3] > 80, "F を押している間は照準が昇る")
	release(m, KEY_F)
	frames(m, 1)
	eq(m.play.sim.ammo[3], 2, "離すと爆発して弾が減る")
	eq(m.play.sim.shots, 1, "爆発が 1 つ")
	_finish(m)
	eq(m.screen, "result", "町が 0 になると S3")
	ok(m.current.share.begins_with("KeyFlak "), "共有する文字")
	ok(m.current.share.contains(S.DAILY_FIRST), "今日の空の 1 回目")
	var seed_before: int = m.run["seed"]
	press(m, KEY_ENTER)
	eq(m.screen, "result", "300 ms の前は押せない")
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(int(m.run["seed"]), seed_before, "今日の空は同じ種(FR-18)")
	_finish(m)
	ok(not m.current.share.contains(S.DAILY_FIRST), "2 回目は「今日の空」だけ")
	ok(m.store.daily(m.run["day"])["first"] != null, "今日の 1 回目を保存")
	_done(m)
	return true


func test_practice_and_retry_r() -> bool:
	var m := _main()
	press(m, KEY_X)
	press(m, KEY_DOWN)
	press(m, KEY_SPACE)
	eq(int(m.run["mode"]), 1, "練習")
	_finish(m)
	ok(m.current.share.contains("(" + S.MODE_LABEL[1] + ")"), "共有する文字は練習")
	ok(m.store.practice_best() != null, "練習の最高を保存")
	m.current._shown_at -= 1000
	frames(m, 1)
	var e := kev(KEY_R)
	e.ctrl_pressed = true
	m._input(e)
	eq(m.screen, "result", "Ctrl 付きの R ではもう1回にならない(FR-25)")
	var seed_before: int = m.run["seed"]
	OS.delay_usec(10)
	press(m, KEY_R)
	eq(m.screen, "play", "R でもう1回")
	eq(int(m.run["mode"]), 1, "同じ入口")
	ok(int(m.run["seed"]) != seed_before, "練習は毎回ちがう空(種を引き直す)")
	_done(m)
	return true


func test_ac21_pause_cancels_aims_and_freezes() -> bool:
	var m := _main()
	_to_daily(m)
	press(m, KEY_A)
	press(m, KEY_L)
	frames(m, 10)
	ok(m.play.sim.aim_h[0] >= 0 and m.play.sim.aim_h[8] >= 0, "照準が 2 本")
	press(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	eq(m.play.sim.aim_h.count(-1), 10, "照準が全部消える")
	eq(m.play.sim.ammo[0] + m.play.sim.ammo[8], 6, "弾は減らない")
	var t: int = m.play.sim.tick
	frames(m, 120)
	eq(m.play.sim.tick, t, "一時停止の間は進まない(ミサイルが動かない)")
	release(m, KEY_A)
	press(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	release(m, KEY_L)
	frames(m, 2)
	ok(m.play.sim.tick > t, "続けると進む")
	eq(m.play.sim.shots, 0, "一時停止の後の「離す」は爆発させない")
	_done(m)
	return true


func test_e11_focus_out() -> bool:
	var m := _main()
	_to_daily(m)
	press(m, KEY_D)
	frames(m, 5)
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止")
	eq(m.play.held.size(), 0, "押されている組を空にする")
	eq(m.play.sim.aim_h[2], -1, "照準を取り消す")
	eq(m.play.sim.ammo[2], 3, "弾は減らない")
	frames(m, 30)
	ok(m.pause_view != null, "戻っても自動では再開しない")
	_done(m)
	return true


func test_ac22_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	_to_daily(m)
	eq(m.play.shake_on, false, "設定がプレイに届く")
	m.play._on_event({"type": "impact", "col": 1, "lost": true})
	frames(m, 3)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると着弾しても動かない")
	m.play.shake_on = true
	m.play._on_event({"type": "impact", "col": 1, "lost": true})
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_fr25_echo_and_modifiers() -> bool:
	var m := _main()
	_to_daily(m)
	var e := kev(KEY_G)
	e.ctrl_pressed = true
	m._input(e)
	m._input(kev(KEY_H, true, true))
	frames(m, 2)
	eq(m.play.sim.aim_h[4], -1, "Ctrl と一緒の押すは数えない")
	eq(m.play.sim.aim_h[5], -1, "押しっぱなしの繰り返しは数えない")
	press(m, KEY_J)
	frames(m, 2)
	m._input(kev(KEY_J, true, true))
	var r := kev(KEY_J, false)
	r.ctrl_pressed = true
	m._input(r)
	frames(m, 1)
	eq(m.play.sim.shots, 1, "押されている J の離すは、Ctrl があっても数える")
	press(m, KEY_SPACE)
	press(m, KEY_ENTER)
	press(m, KEY_Q)
	frames(m, 1)
	eq(m.play.sim.aim_h.count(-1), 10, "Space・Enter・ほかのキーは何もしない(E-1)")
	_done(m)
	return true


func test_simultaneous_hold() -> bool:
	var m := _main()
	_to_daily(m)
	for pk: int in [KEY_A, KEY_S, KEY_D]:
		press(m, pk)
	frames(m, 10)
	eq(m.play.sim.aim_h.slice(0, 3).filter(func(h: int) -> bool: return h >= 0).size(), 3, "3 つを同時に押さえられる(FR-7)")
	release(m, KEY_S)
	frames(m, 1)
	ok(m.play.sim.aim_h[1] == -1 and m.play.sim.aim_h[0] >= 0 and m.play.sim.aim_h[2] >= 0, "別々に離せる")
	_done(m)
	return true


func test_pause_settings_back_and_key_check() -> bool:
	var m := _main()
	_to_daily(m)
	press(m, KEY_ESCAPE)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "settings", "一時停止から設定")
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)  # 揺れを切る(上から 音量・揺れ)
	eq(m.store.settings()["shake"], false, "揺れを切って保存")
	press(m, KEY_RIGHT)
	eq(m.store.settings()["shake"], true, "→ でも変えられる")
	press(m, KEY_UP)
	press(m, KEY_RIGHT)
	eq(m.store.settings()["volume"], 100, "音量は 5 段(75 → 100)")
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	ok(m.current.keys_view, "キーの確かめ")
	press(m, KEY_A)
	press(m, KEY_SEMICOLON)
	eq(m.current.held.size(), 2, "押されているキーを数える")
	release(m, KEY_A)
	eq(m.current.held.keys(), [9], "離したキーは消える")
	ok(m.current.last_key.contains("echo"), "キーの中身を文字で出す")
	eq(m.current.key_rows.size(), 4, "最後に届いたキーは名前と値の 4 行")
	eq(m.current.key_rows[0][1], "%d (%s)" % [KEY_A, OS.get_keycode_string(KEY_A)], "1 行目は physical_keycode の値")
	press(m, KEY_ESCAPE)
	ok(not m.current.keys_view, "Esc で設定へ")
	press(m, KEY_ESCAPE)
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	press(m, KEY_ESCAPE)
	ok(m.pause_view == null, "続ける")
	_done(m)
	return true


func test_title_records() -> bool:
	var m := _main()
	press(m, KEY_X)
	var texts := func() -> Array:
		return m.current.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(not texts.call().has(S.REC_NONE), "初めての起動は記録の行を出さない")
	press(m, KEY_ENTER)
	m.play.sim.points = 18450
	_finish(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "title", "タイトルへ")
	var best: int = m.store.daily(m.run["day"])["first"]["score"]
	ok(best >= 18450, "1 回目の点を保存")
	var want := (S.REC_FIRST % Score.comma(best)) + " / " + (S.REC_TODAY_BEST % Score.comma(best))
	ok(texts.call().has(want), "今日の記録が出る")
	var daily: Button = m.current.menu.buttons[0]
	var note: Label = m.current.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == want)[0]
	var nr: Rect2 = m.current._notes[0]
	ok(nr.position.y > daily.get_rect().end.y and nr.end.y < m.current.menu.buttons[1].position.y - 7.0, "記録の札は今日の空のボタンの真下(次のボタンの照準の角に掛からない)")
	ok(absf(nr.get_center().x - daily.get_rect().get_center().x) < 1.0 and note.get_rect().intersects(nr), "札は真ん中に揃う")
	_done(m)
	return true


func test_gate_ignores_touch_mouse() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.device = InputEvent.DEVICE_ID_EMULATION
	m._input(mb)
	eq(m.screen, "gate", "タッチと、そこから作られたマウスでは進まない(FR-26)")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る")
	_done(m)
	return true


func test_ime_note_on_zero_keycode() -> bool:
	var m := _main()
	_to_daily(m)
	m._input(kev(0))
	frames(m, 1)
	ok(m.play._ime.visible, "physical_keycode が 0 の押すで日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


func test_result_shows_best_diff() -> bool:
	var m := _main()
	_to_daily(m)
	m.play.sim.points = 1000
	_finish(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)
	m.play.sim.points = 400
	_finish(m)
	var labels: Array = m.current.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	ok(labels.any(func(t: String) -> bool: return t.begins_with(S.RES_TO_BEST % "600")), "最高まで −600 が出る: %s" % [labels])
	_done(m)
	return true


# --- 磨きで足した演出(v0.2.0、仕様書 §14) ---

func test_polish_reduce_flash_caps_white() -> bool:
	var m := _main()
	_to_daily(m)
	var p: Control = m.play
	p.reduce_flash = false
	eq(p.flash_a(B.BURST_FLASH_A), B.BURST_FLASH_A, "点滅を弱めない時は爆発の白い芯をそのまま")
	p.reduce_flash = true
	for a: float in [B.BURST_FLASH_A, B.IMPACT_FLASH_A, 1.0]:
		ok(p.flash_a(a) <= B.REDUCED_FLASH_ALPHA, "点滅を弱めると白い光は 20%% 以下(%.2f)" % a)
	eq(p.flash_a(0.1), 0.1, "弱い光はそのまま")
	_done(m)
	return true


func test_polish_kill_fx() -> bool:
	var m := _main()
	_to_daily(m)
	var p: Control = m.play
	p._heads = [[Vector2(448, 300), Vector2(448, 64), Sch.STRAIGHT]]
	p._on_event({"type": "kill", "x": 448.0, "y": 304.0, "n": 1, "points": 25, "bomber": false})
	eq(p._sparks.size(), 1, "落とすと火花")
	eq(p._flashes.size(), 1, "落とした所の白い光")
	eq(p._ghosts.size(), 1, "落としたミサイルの線を残す")
	eq(p._popups.size(), 1, "浮かぶ点")
	ok(not p._sparks[0]["big"], "1 本目は小さい演出")
	eq(p.position, Vector2.ZERO, "1 本目では揺れない")
	p._on_event({"type": "kill", "x": 900.0, "y": 140.0, "n": 1, "points": 100, "bomber": true})
	ok(p._sparks[1]["big"], "爆撃機は派手な演出")
	eq(p._ghosts.size(), 1, "爆撃機は線を残さない")
	p._on_event({"type": "kill", "x": 600.0, "y": 300.0, "n": 3, "points": 75, "bomber": false})
	ok(p._sparks[2]["big"] and p._popups[2]["big"], "組の 3 本目から派手な演出")
	_done(m)
	return true


func test_polish_first_hint() -> bool:
	var m := _main()
	_to_daily(m)
	var p: Control = m.play
	eq(p.hint_col(), -1, "ミサイルが出るまでは案内しない")
	while p.sim.missiles.is_empty():
		p.sim.step()
	p._refresh()
	eq(p.hint_col(), B.TEACH_COL1, "1 本目の列(F)を案内する")
	ok(p._hint.visible and p._hint.text == S.FIRST_HINT % "F", "案内の文: %s" % p._hint.text)
	ok(p._hint.position.y >= B.HUD_H and p._hint.get_rect().end.y < B.HUD_H + 60.0, "案内は上の帯のすぐ下(地面の近くを横切らない)")
	var fx := B.COL_X0 + B.COL_W * B.TEACH_COL1
	ok(p.hint_rect.size.x > 0.0 and not (p.hint_rect.position.x <= fx and fx <= p.hint_rect.end.x), "案内の板は案内する列(1 本目が落ちてくる所)に重ならない %s" % p.hint_rect)
	press(m, KEY_F)
	frames(m, 2)
	ok(not p._hint.visible, "押すと案内が消える")
	release(m, KEY_F)
	frames(m, 2)
	eq(p.hint_col(), -1, "1 回撃った後は出さない")
	_done(m)
	return true


func test_polish_wave_subtitle() -> bool:
	var m := _main()
	_to_daily(m)
	var p: Control = m.play
	for w in [2, 3, 4, 5]:
		p._on_event({"type": "wave_start", "wave": w})
		p._refresh()
		ok(p._bonus.visible and p._bonus.text == S.WAVE_NEW[w] and S.WAVE_NEW[w] != "", "波 %d の一言: %s" % [w, p._bonus.text])
	p._on_event({"type": "wave_start", "wave": 6})
	p._refresh()
	ok(p._banner.visible and not p._bonus.visible, "新しい種類の無い波は「波 6」だけ")
	_done(m)
	return true


func test_polish_mark_above_launcher_and_town() -> bool:
	# 落ちる先の印は、発射台(高さ 30)と町(高さ 30 まで)に隠れない高さに描く(v0.1.0 では発射台の後ろに隠れていた)
	ok(B.MARK_ICON_Y < B.GROUND_Y - 30.0, "印の下の先 %.0f は発射台と町の上" % B.MARK_ICON_Y)
	return true
