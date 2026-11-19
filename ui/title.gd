# S1 タイトル(画面設計書 §2)。入口 2 つ(今日の空・練習)と設定、今日の記録と練習の最高。下に地面と発射台を薄く出す。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu


# store は save_store、day は通し日数、date は "2026-11-19"。
func build(store: RefCounted, day: int, date: String) -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 40, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 140, 1280, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 186, 1280, 28))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 300, 226, 480, 88)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 300, 330, 480, 88)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 300, 434, 240, 72)
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
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 676, 200, 32))
	menu = Menu.new([daily, practice, settings] as Array[Button], 0)


func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 18, Kit.C_DIM, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, by.position.x + by.size.x + 24, by.position.y, 460, by.size.y))


# 下に地面と 10 基の発射台を薄く出し、キーの文字を添える。
func _draw() -> void:
	Kit.draw_ground(self, 0.5)
	var f := Kit.font(700)
	for i in B.COLS:
		var x := Kit.col_x(i)
		if i in B.TOWN_COLS:
			Kit.draw_town(self, x, 0.0, 0.35)
		Kit.draw_launcher(self, x, false, false, 0.45)
		draw_string(f, Vector2(x - 40, 676), S.KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(Kit.C_TEXT, 0.5))


func key(ev: InputEventKey) -> void:
	menu.key(ev)
