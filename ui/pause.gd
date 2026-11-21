# S5 一時停止(共通 §6・画面設計書 §10)。プレイ画面を暗くした上に、照準の角のある硝子の板を重ねる。続ける・やり直す・設定・タイトルへ。
# Esc で続ける、R でやり直す(板の下に案内)。作りは RootCall の ui/pause.gd。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const PANEL := Rect2(430, 92, 420, 520)

var menu: Menu


func build() -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label(S.PAUSE, 36, Kit.C_TEXT, 700), PANEL.position.x, 112, PANEL.size.x, 56))
	var list: Array[Button] = []
	var y := 200.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 26), 490, y, 300, 64)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 80
	add_child(Kit.place(KeyHint.new([[["Esc"], S.B_RESUME], [["R"], S.B_RESTART]]), PANEL.position.x, 548, PANEL.size.x, 40))
	menu = Menu.new(list, 0)


func _draw() -> void:
	draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(0.02, 0.03, 0.07, 0.74))  # 窓の余り(ステージの外)も暗くする
	Kit.draw_plate(self, PANEL, Color(Kit.C_PANEL, 0.97), Kit.C_RULE, 18.0, Kit.C_AMBER)
	Kit.draw_scale(self, PANEL.position.x + 60, PANEL.end.x - 60, 176, Color(Kit.C_AMBER, 0.4), 12.0, 4)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)
