# S1 タイトル(画面設計書 §2・§10)。題字(ui/logo.gd)、入口 2 つ(今日の空・練習)と設定、今日の記録と練習の最高。
# 後ろは main の backdrop(レーダーの目盛りと掃く線)。下に地面と 10 基の発射台とキーの札を薄く出す。右下にキーの案内。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Logo := preload("res://ui/logo.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var logo: Logo
var _notes: Array[Rect2] = []


# store は save_store、day は通し日数、date は "2026-11-19"。still は点滅を弱める 入(題字を動かさない)。
func build(store: RefCounted, day: int, date: String, still: bool = false) -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = Logo.new(132, still)
	add_child(Kit.place(logo, 0, 22, 1280, 170))
	add_child(Kit.place(Kit.label(S.TAGLINE, 26, Kit.C_DIM, 500), 0, 200, 1280, 40))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 236, 1280, 22))
	# 入口の下に記録の札の段(28 px)を空けておく(記録が無くても並びは同じ)
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 400, 260, 480, 74)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 400, 386, 480, 70)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 520, 508, 240, 56)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	if d["first"] != null:
		_note((S.REC_FIRST % Score.comma(d["first"]["score"])) + " / " + (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif store.practice_best() != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動は記録の行を出さない
	var pb: Variant = store.practice_best()
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	var ver := Kit.label(S.VERSION, 18, Kit.C_DIM, 500)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 690, 200, 26))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["Enter"], S.HINT_OK]], HORIZONTAL_ALIGNMENT_RIGHT), 760, 688, 496, 30))
	menu = Menu.new([daily, practice, settings] as Array[Button], 0)


# 記録の札(ボタンの真下の真ん中。琥珀の縦線と、硝子の板)。
func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 18, Kit.C_TEXT, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var w := Kit.font(500).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 36.0
	var r := Rect2(by.position.x + (by.size.x - w) / 2.0, by.position.y + by.size.y + 12, w, 28)
	_notes.append(r)
	add_child(Kit.place(l, r.position.x + 20, r.position.y, w - 20, r.size.y))


func _draw() -> void:
	# 一言の両側の目盛り
	var tw := Kit.font(500).get_string_size(S.TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	Kit.draw_scale(self, 640 - tw / 2 - 150, 640 - tw / 2 - 24, 222, Color(Kit.C_AMBER, 0.35), 16.0, 4, true)
	Kit.draw_scale(self, 640 + tw / 2 + 24, 640 + tw / 2 + 150, 222, Color(Kit.C_AMBER, 0.35), 16.0, 4, true)
	for r: Rect2 in _notes:
		draw_rect(r, Color(Kit.C_PANEL, 0.9))
		draw_line(r.position, Vector2(r.position.x, r.end.y), Kit.C_AMBER, 3.0)
	# 地面と 10 基の発射台、キーの札
	Kit.draw_ground(self, 0.7)
	for i in B.COLS:
		var x := Kit.col_x(i)
		if i in B.TOWN_COLS:
			Kit.draw_town(self, x, 0.0, 0.45)
		Kit.draw_launcher(self, x, false, false, 0.6)
		Kit.draw_keycap(self, Rect2(x - 18, 652, 36, 30), S.KEYS[i], 20, false, false, 0.8)


func key(ev: InputEventKey) -> void:
	menu.key(ev)
