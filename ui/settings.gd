# S4 設定(共通 §6・画面設計書 §5)。音量(5 段)・画面の揺れ・点滅を弱める・キーの確かめ。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# キーの確かめ: 中の段の 10 キーを並べ、押されているキーを光らせる(E-17)。最後に届いたキーの中身も文字で出す(共通 §3 の 22)。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ(キーの確かめの中では Esc で設定へ)。
# v0.3.0: 項目は左に名前、右に今の値の絵(音量は 5 つの目盛り、入・切は 2 つに分かれた札)。下にキーの案内。
extends Control

signal back
signal changed  # 値を変えた(main が音量・動きを減らす設定をすぐ当てる)

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var store: RefCounted
var keys_view := false
var held := {}  # キーの確かめで押されている番号
var last_key := ""  # 最後に届いたキーの中身
var _vol: Button
var _shake: Button
var _flash: Button
var _list: Control
var _keys: Control
var key_rows: Array = []  # 最後に届いたキーの [名前, 値] の組(枠に 1 組 1 行で出す)


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	_list = Control.new()
	_list.size = size
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.draw.connect(_draw_list)  # 一時停止から開いた時の暗い幕より上に描く
	add_child(_list)
	_list.add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 700), 0, 52, 1280, 60))
	_vol = Kit.place(Kit.button("volume", S.SET_VOLUME, 26), 360, 146, 560, 68)
	_shake = Kit.place(Kit.button("shake", S.SET_SHAKE, 26), 360, 228, 560, 68)
	_flash = Kit.place(Kit.button("reduce_flash", S.SET_FLASH, 26), 360, 310, 560, 68)
	var keys := Kit.place(Kit.button("keys", S.B_KEYS, 26), 360, 392, 560, 68)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 26), 520, 500, 240, 64)
	for b: Button in [_vol, _shake, _flash, keys]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 0)
		var v := Control.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.draw.connect(_draw_value.bind(v, String(b.name)))
		b.add_child(v)
	for b: Button in [_vol, _shake, _flash, keys, ret]:
		_list.add_child(b)
	_list.add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["left", "right"], S.HINT_CHANGE], [["Enter"], S.HINT_OK], [["Esc"], S.B_BACK]]), 0, 640, 1280, 34))
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	keys.pressed.connect(func() -> void: _show_keys(true))
	ret.pressed.connect(func() -> void: back.emit())
	menu = Menu.new([_vol, _shake, _flash, keys, ret] as Array[Button], 0)
	_keys = Control.new()
	_keys.size = size
	_keys.visible = false
	_keys.draw.connect(_draw_keys)  # 一時停止から開いた時の暗い幕より上に描く
	add_child(_keys)
	_keys.add_child(Kit.place(Kit.label(S.B_KEYS, 40, Kit.C_TEXT, 700), 0, 52, 1280, 60))
	_keys.add_child(Kit.place(Kit.label(S.KEYS_HELP, 20, Kit.C_DIM, 500), 0, 126, 1280, 32))
	_keys.add_child(Kit.place(KeyHint.new([[["Esc"], S.B_BACK]]), 0, 640, 1280, 34))
	_paint()


func _paint() -> void:
	for b: Button in [_vol, _shake, _flash]:
		b.get_child(0).queue_redraw()


# 項目の右の、今の値の絵(ボタンの子に描く)。
func _draw_value(v: Control, what: String) -> void:
	var st: Dictionary = store.settings()
	var right := v.size.x - 22.0
	var cy := v.size.y / 2.0
	match what:
		"volume":
			var n: int = B.VOLUMES.find(int(st["volume"]))
			var f := Kit.num_font()
			v.draw_string(f, Vector2(right - 52, cy + 13), str(int(st["volume"])), HORIZONTAL_ALIGNMENT_RIGHT, 52, 34, Kit.C_TEXT)
			for k in B.VOLUMES.size() - 1:
				var h := 10.0 + 6.0 * k
				var r := Rect2(right - 200 + 30 * k, cy + 15 - h, 20, h)
				if k < n:
					v.draw_rect(r, Kit.C_AMBER)
				else:
					v.draw_rect(r, Color(Kit.C_AMBER, 0.45), false, 1.5)
		"shake", "reduce_flash":
			var on: bool = st[what]
			for k in 2:
				var r := Rect2(right - 152 + 76 * k, cy - 17, 76, 34)
				var lit := (k == 0) == on
				v.draw_rect(r, Kit.C_AMBER if lit else Color(Kit.C_BG, 0.8))
				v.draw_rect(r, Kit.C_AMBER if lit else Kit.C_RULE.lightened(0.2), false, 1.5)
				v.draw_string(Kit.font(700), Vector2(r.position.x, r.position.y + 25), S.ON if k == 0 else S.OFF, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Kit.C_INK if lit else Kit.C_DIM)
		"keys":
			# 開く項目の印(右向きの山形)
			v.draw_polyline(PackedVector2Array([Vector2(right - 12, cy - 11), Vector2(right, cy), Vector2(right - 12, cy + 11)]), Kit.C_DIM, 3.0, true)


func _draw_list() -> void:
	Kit.draw_scale(_list, 440, 840, 116, Color(Kit.C_AMBER, 0.4), 16.0, 5)


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("kill")
	_paint()
	changed.emit()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	_paint()
	changed.emit()


func _show_keys(on: bool) -> void:
	keys_view = on
	held.clear()
	_list.visible = not on
	_keys.visible = on
	_keys.queue_redraw()


# フォーカスが外れた時は、押されている組を空にする(共通 §3 の 5)。
func release_all() -> void:
	held.clear()
	_keys.queue_redraw()


func key(ev: InputEventKey) -> void:
	if keys_view:
		_keys_key(ev)
		return
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif menu.sel == 0 and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_step_volume(-1 if ev.physical_keycode == KEY_LEFT else 1)
	elif menu.sel in [1, 2] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_toggle(["", "shake", "reduce_flash"][menu.sel])
	else:
		menu.key(ev)


func _keys_key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		_show_keys(false)
		return
	var code := OS.get_keycode_string(ev.physical_keycode)
	var lab := OS.get_keycode_string(ev.key_label)
	last_key = S.KEY_DETAIL % [ev.physical_keycode, code, lab, ev.unicode, ev.pressed, ev.echo, ev.ctrl_pressed, ev.alt_pressed, ev.meta_pressed, ev.shift_pressed]
	var vals := [[ev.physical_keycode, code], [lab, ev.unicode], [ev.pressed, ev.echo], [ev.ctrl_pressed, ev.alt_pressed, ev.meta_pressed, ev.shift_pressed]]
	key_rows.clear()
	for k in S.KEY_ROWS.size():
		key_rows.append([S.KEY_ROWS[k][0], S.KEY_ROWS[k][1] % vals[k]])
	var i := Keymap.index_of(ev)
	if i >= 0:
		if ev.pressed:
			held[i] = true
		else:
			held.erase(i)
	_keys.queue_redraw()


# キーの確かめの図: 10 キーを並べ、押されているキーを光らせる。
var keys_drawn := 0  # 図を描いた回数(自動の確かめが読む)


func _draw_keys() -> void:
	keys_drawn += 1
	Kit.draw_scale(_keys, 440, 840, 116, Color(Kit.C_AMBER, 0.4), 16.0, 5)
	for i in B.COLS:
		var r := Rect2(Kit.col_x(i) - 42 + (i - 4.5) * -4.0, 236, 84, 84)  # 端を 48 px ほど空ける
		Kit.draw_keycap(_keys, r, S.KEYS[i], 40, held.has(i))
	_keys.draw_string(Kit.font(500), Vector2(0, 372), S.KEYS_HELD, HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Kit.C_DIM)
	_keys.draw_string(Kit.font(800), Vector2(0, 420), str(held.size()), HORIZONTAL_ALIGNMENT_CENTER, 1280, 44, Kit.C_TEXT)
	# 最後に届いたキー: 左に名前、右に値の 4 行(英語の値が組の途中で折り返さない)
	var box := Rect2(240, 452, 800, 148)
	Kit.draw_plate(_keys, box, Color(Kit.C_PANEL, 0.9), Kit.C_RULE, 0.0)
	_keys.draw_string(Kit.font(700), Vector2(box.position.x + 20, box.position.y + 26), S.KEYS_LAST, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.C_AMBER)
	_keys.draw_line(Vector2(box.position.x + 20, box.position.y + 36), Vector2(box.end.x - 20, box.position.y + 36), Color(Kit.C_RULE, 0.9), 1.0)
	for k in key_rows.size():
		var y := box.position.y + 62 + 25 * k
		_keys.draw_string(Kit.font(500), Vector2(box.position.x + 20, y), key_rows[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.C_DIM)
		_keys.draw_string(Kit.font(700), Vector2(box.position.x + 300, y), key_rows[k][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Kit.C_TEXT)
