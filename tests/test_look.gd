# v0.3.0 の UI の作り直しのテスト(画面設計書 §10): theme.tres が全部の Control に付く・5 つの状態・色の板のコントラスト・表示用の字体の字・
# 画面の切り替わりは見た目だけ(入力を飲まない・もう1回は動かない・点滅を弱める 入なら動かない)・時刻で決まる動きの関数・
# 落ちる先の印の高さに子の Control を置かない(印は play._draw の中なので、子が重なると隠れる)。作りは KeySwat の tests/test_look.gd。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Result := preload("res://ui/result.gd")
const Logo := preload("res://ui/logo.gd")
const Wipe := preload("res://ui/wipe.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const TestUi := preload("res://tests/test_ui.gd")


func _main(reduce: bool = false) -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	if reduce:
		var s := Store.new()
		s.set_setting("reduce_flash", true)
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()
	Kit.still = false


func test_theme_is_project_wide_and_complete() -> bool:
	eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres", "theme は project の設定で付ける")
	var t := load("res://ui/theme.tres") as Theme
	ok(t != null, "theme.tres を読める")
	if t == null:
		return true
	for st: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		ok(t.has_stylebox(st, "Button"), "Button の %s" % st)
	ok(t.has_stylebox("normal", "SelButton") and t.has_stylebox("disabled", "SelButton") and t.get_type_variation_base("SelButton") == &"Button", "選んだボタンの型の変種")
	for pair: Array in [["read_only", "TextEdit"], ["focus", "TextEdit"], ["normal", "LineEdit"], ["panel", "PopupMenu"], ["hover", "PopupMenu"], ["grabber", "VScrollBar"],
			["scroll", "HScrollBar"], ["slider", "HSlider"], ["panel", "TooltipPanel"], ["panel", "Panel"]]:
		ok(t.has_stylebox(pair[0], pair[1]), "%s の %s" % [pair[1], pair[0]])
	ok(t.has_icon("checked", "CheckBox") and t.has_icon("grabber", "HSlider"), "チェックとつまみの絵")
	ok(t.get_icon("checked", "CheckBox") is ImageTexture and t.get_icon("grabber", "HSlider") is ImageTexture, "絵は ImageTexture(圧縮の形は Web でエラーになった)")
	eq((t.get_stylebox("normal", "Button") as StyleBoxFlat).bg_color, Kit.C_PANEL, "theme.tres は今の色で作り直してある(tools/make_theme.gd)")
	var m := _main()
	TestUi.press(m, KEY_X)
	var b: Button = m.current.menu.buttons[1]
	eq((b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Kit.C_PANEL, "タイトルのボタンは theme の板")
	eq(b.theme_type_variation, &"", "選んでいないボタンは素の型")
	eq(m.current.menu.buttons[0].theme_type_variation, &"SelButton", "選んだボタンは SelButton")
	ok(m.current.menu.lock.get_parent() == m.current.menu.buttons[0], "選んだボタンに照準の角")
	TestUi.press(m, KEY_DOWN)
	ok(m.current.menu.lock.get_parent() == b, "選びを動かすと照準の角も動く")
	_done(m)
	return true


func test_palette_contrast() -> bool:
	var sel := Kit.C_PANEL.lerp(Kit.C_AMBER, 0.07)
	for pair: Array in [[Kit.C_TEXT, Kit.C_BG], [Kit.C_DIM, Kit.C_BG], [Kit.C_TEXT, Kit.C_PANEL], [Kit.C_DIM, Kit.C_PANEL], [Kit.C_TEXT, sel],
			[Kit.C_AMBER, Kit.C_BG], [Kit.C_AMBER, Kit.C_PANEL], [Kit.C_INK, Kit.C_AMBER], [Kit.C_INK, Kit.C_AIM], [Kit.C_CHAIN, Kit.C_INK],
			[Kit.C_WARN, Kit.C_BG], [Kit.C_GOOD, Kit.C_BG], [Kit.C_TEXT, Color("0E1524")], [Kit.C_AIM, Kit.C_BG]]:
		var c := Kit.contrast(pair[0], pair[1])
		ok(c >= 4.5, "%s と %s のコントラスト %.2f" % [pair[0].to_html(false), pair[1].to_html(false), c])
	return true


func test_display_font_has_its_glyphs() -> bool:
	var f := load(Kit.DISPLAY) as FontFile
	ok(f != null, "Big Shoulders Stencil を読める")
	if f == null:
		return true
	var missing := ""
	for c in "KeyFlakEscEnterRv0123456789,.;ASDFGHJKL":
		if not f.has_char(c.unicode_at(0)):
			missing += c
	eq(missing, "", "Big Shoulders Stencil に無い字")
	ok(FileAccess.file_exists("res://assets/fonts/OFL_BigShouldersStencil.txt"), "OFL を同梱")
	ok(Kit.num_font().has_char("点".unicode_at(0)), "日本語は Noto Sans JP へ落ちる")
	# 0 は割れ目を閉じてある(左右 2 つの輪郭 + 上下の橋 2 つ。tools/subset_font.py の bridge_zero)。小さい所の 0 が「()」に見えない
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = f.get_rids()[0]
	var gi := ts.font_get_glyph_index(rid, 64, "0".unicode_at(0), 0)
	eq((ts.font_get_glyph_contours(rid, 64, gi)["contours"] as PackedInt32Array).size(), 4, "型紙の字の 0 は閉じてある(輪郭 4 つ)")
	return true


func test_no_symbol_glyphs_in_strings() -> bool:
	# × と − は数式の字として残す(ボーナスの行・最高との差)。印は _draw で描く
	var text := FileAccess.get_file_as_string("res://core/strings.gd")
	var found := ""
	for c in "★☆✓✔✗▶◀▲▼→←↑↓●○◆◇■□♪":
		if text.contains(c):
			found += c
	eq(found, "", "画面の文字に記号の字")
	return true


func test_transition_is_visual_only_and_keeps_input() -> bool:
	var m := _main()
	TestUi.press(m, KEY_X)
	eq(m.screen, "title", "S0 のキーでその場で S1")
	ok(not m.entering.is_empty() and m.wipe.progress() < 1.0, "タイトルは入りの動きと掃く線")
	ok(m.backdrop.radar and m.backdrop.animate, "タイトルはレーダーが回る")
	TestUi.press(m, KEY_ENTER)  # 動いている間の Enter もそのまま届く
	eq(m.screen, "play", "動いている間の Enter で今日の空(飲まない)")
	ok(not m.backdrop.radar, "遊びの画面はレーダーを描かない")
	var p: Node = m.play
	TestUi.press(m, KEY_ENTER)
	ok(m.play == p, "遊びの画面の Enter で 2 回目は始まらない")
	TestUi.press(m, KEY_F)
	TestUi.frames(m, 20)
	ok(m.play.sim.aim_h[3] > 0, "入りの動きの間も F が効く")
	TestUi.release(m, KEY_F)
	TestUi._finish(m)
	eq(m.screen, "result", "結果")
	ok(m.wipe.progress() < 1.0, "結果は掃く線で入る")
	ok(m.backdrop.radar and not m.backdrop.sweep, "結果のレーダーは目盛りだけ(掃く光が点の上を横切らない)")
	eq(m.current.menu.buttons[0].theme_type_variation, &"SelButton", "もう1回は入りの最初から選んである")
	m.current._shown_at -= 1000
	TestUi.frames(m, 1)
	TestUi.press(m, KEY_R)
	eq(m.screen, "play", "もう1回")
	ok(m.entering.is_empty() and m.play.modulate.a == 1.0, "もう1回からは動きを付けない(すぐ遊べる)")
	TestUi.press(m, KEY_ESCAPE)
	ok(m.pause_view != null and m.entering.size() == 1, "一時停止の板は少し上がりながら出る")
	var pv: Node = m.pause_view
	TestUi.press(m, KEY_ESCAPE)
	ok(m.pause_view == null and pv.get_parent() == null, "続けると板はすぐ木から外れる(押しを飲まない)")
	ok(not m.play.paused, "続ける")
	_done(m)
	return true


func test_enter_alpha_reaches_one() -> bool:
	var m := _main()
	TestUi.press(m, KEY_X)
	var t: Control = m.current
	ok(t.modulate.a < 1.0, "入りの最初は薄い")
	m.entering[0][1] -= B.ENTER_MS + 10
	m._process(0.016)
	eq(t.modulate.a, 1.0, "ENTER_MS で濃くなりきる")
	ok(m.entering.is_empty(), "動きが終わると外す")
	_done(m)
	return true


func test_reduce_flash_stops_motion() -> bool:
	var m := _main(true)
	ok(m.reduce_motion() and Kit.still, "点滅を弱める 入")
	TestUi.press(m, KEY_X)
	ok(m.entering.is_empty() and m.wipe.progress() >= 1.0, "切り替わりの動きなし")
	ok(m.backdrop.radar and not m.backdrop.animate, "レーダーの掃く線も止まる")
	ok(m.current.logo.still and m.current.logo.burst() == 1.0, "題字は最初から出来上がった形")
	ok(m.current.menu.lock.k() == 1.0, "照準の角は最初から寄っている")
	_done(m)
	var n := _main()
	TestUi.press(n, KEY_X)
	ok(n.backdrop.animate and not n.current.logo.still, "ふだんはレーダーが回り、題字が動く")
	# 設定で入れるとその場で止まる
	TestUi.press(n, KEY_DOWN)
	TestUi.press(n, KEY_DOWN)
	TestUi.press(n, KEY_ENTER)
	TestUi.press(n, KEY_DOWN)
	TestUi.press(n, KEY_DOWN)
	TestUi.press(n, KEY_ENTER)
	ok(Kit.still and not n.backdrop.animate, "設定で入れるとすぐ動きを止める")
	_done(n)
	return true


func test_motion_curves() -> bool:
	eq(Result.shown_points(1000, 0, false), 0, "結果の点は 0 から")
	eq(Result.shown_points(1000, B.COUNT_MS, false), 1000, "COUNT_MS で数え上がる")
	eq(Result.shown_points(1000, 0, true), 1000, "点滅を弱めると数え上げない")
	eq(Result.stamp_k(B.COUNT_MS - 1, false), -1.0, "新しい記録の印は数え上げの後")
	eq(Result.stamp_k(B.COUNT_MS + B.STAMP_MS, false), 1.0, "STAMP_MS で押し終わる")
	eq(Result.stamp_k(0, true), 1.0, "点滅を弱めると最初から押してある")
	var logo := Logo.new()
	logo.start_ms = 1000
	logo.now_ms = 1000
	eq(logo.reveal(0), 0.0, "題字の 1 字目はまだ出ていない")
	eq(logo.burst(), -1.0, "炸裂はまだ")
	logo.now_ms = 1000 + B.LOGO_MS
	eq(logo.reveal(6), 1.0, "最後の字まで出た")
	eq(logo.lock(), 1.0, "照準が F に合った")
	eq(logo.burst(), 1.0, "炸裂した")
	logo.free()
	var w := Wipe.new()
	w.start_ms = 1000
	w.now_ms = 1000 + B.WIPE_MS / 2
	ok(w.progress() > 0.0 and w.progress() < 1.0, "掃く線は途中")
	w.now_ms = 1000 + B.WIPE_MS
	eq(w.progress(), 1.0, "WIPE_MS で終わる")
	w.free()
	near(Backdrop.sweep_angle(0), -PI, "レーダーの掃く線は左から")
	near(Backdrop.sweep_angle(B.SWEEP_PERIOD_MS / 2), 0.0, "半周で右")
	near(Backdrop.since_sweep(1000, Backdrop.sweep_angle(1000)), 0.0, "掃く線の上の点は今通った", 0.5)
	return true


func test_new_best_result_has_stamp() -> bool:
	var res := {"points": 500, "wave": 3, "kills": 5, "max_chain": 2}
	var r := Result.new()
	r.build(0, res, {"prev_best": {"score": 300}, "new_best": true, "first_today": false}, "KeyFlak x")
	ok(r.new_best, "前の最高を超えたら印を押す")
	r.free()
	var q := Result.new()
	q.build(0, res, {"prev_best": null, "new_best": true, "first_today": true}, "KeyFlak x")
	ok(not q.new_best, "初めての回(比べる最高が無い)には印を押さない")
	ok(not (q.find_child("share", true, false) as TextEdit).context_menu_enabled, "共有の枠で右クリックのメニューを出さない")
	q.free()
	return true


func test_no_child_over_impact_marks() -> bool:
	# 落ちる先の印(y 572〜590)は play._draw の中。子の Control はその上に描かれるので、印の高さに置かない
	var m := _main()
	TestUi.press(m, KEY_X)
	TestUi.press(m, KEY_ENTER)
	var band := Rect2(-2000, B.MARK_ICON_Y - 22.0, 5280, 26.0)
	for c in m.play.get_children():
		if c is Control:
			ok(not (c as Control).get_rect().intersects(band), "%s が印の高さに重なる %s" % [c.name, (c as Control).get_rect()])
	ok(m.wipe.get_index() == m.stage.get_child_count() - 1, "掃く線は一番上(動き終わると何も描かない)")
	_done(m)
	return true
