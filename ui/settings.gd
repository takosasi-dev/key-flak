# S4 設定(共通 §6・画面設計書 §5)。音量(5 段)・画面の揺れ・点滅を弱める・キーの確かめ。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# キーの確かめ: 中の段の 10 キーを並べ、押されているキーを光らせる(E-17)。最後に届いたキーの中身も文字で出す(共通 §3 の 22)。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ(キーの確かめの中では Esc で設定へ)。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Menu := preload("res://ui/menu.gd")

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
var _detail: Label


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	_list = Control.new()
	_list.size = size
	add_child(_list)
	_list.add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 700), 0, 60, 1280, 60))
	_vol = Kit.place(Kit.button("volume", "", 26), 390, 150, 500, 72)
	_shake = Kit.place(Kit.button("shake", "", 26), 390, 238, 500, 72)
	_flash = Kit.place(Kit.button("reduce_flash", "", 26), 390, 326, 500, 72)
	var keys := Kit.place(Kit.button("keys", S.B_KEYS, 26), 390, 414, 500, 72)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 26), 520, 520, 240, 72)
	for b: Button in [_vol, _shake, _flash, keys, ret]:
		_list.add_child(b)
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	keys.pressed.connect(func() -> void: _show_keys(true))
	ret.pressed.connect(func() -> void: back.emit())
	menu = Menu.new([_vol, _shake, _flash, keys, ret] as Array[Button], 0)
	_keys = Control.new()
	_keys.size = size
	_keys.visible = false
	add_child(_keys)
	_keys.add_child(Kit.place(Kit.label(S.B_KEYS, 40, Kit.C_TEXT, 700), 0, 60, 1280, 60))
	_keys.add_child(Kit.place(Kit.label(S.KEYS_HELP, 20, Kit.C_DIM), 0, 130, 1280, 32))
	_detail = Kit.label("", 18, Kit.C_DIM)
	_keys.add_child(Kit.place(_detail, 0, 470, 1280, 32))
	_paint()


func _paint() -> void:
	var st: Dictionary = store.settings()
	_vol.text = "%s  %d" % [S.SET_VOLUME, int(st["volume"])]
	_shake.text = "%s  %s" % [S.SET_SHAKE, S.ON if st["shake"] else S.OFF]
	_flash.text = "%s  %s" % [S.SET_FLASH, S.ON if st["reduce_flash"] else S.OFF]


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("kill")
	_paint()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	_paint()


func _show_keys(on: bool) -> void:
	keys_view = on
	held.clear()
	_list.visible = not on
	_keys.visible = on
	queue_redraw()


# フォーカスが外れた時は、押されている組を空にする(共通 §3 の 5)。
func release_all() -> void:
	held.clear()
	queue_redraw()


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
	last_key = "physical_keycode %d (%s) / key_label %s / unicode %d / pressed %s / echo %s / ctrl %s alt %s meta %s shift %s" % [
		ev.physical_keycode, OS.get_keycode_string(ev.physical_keycode), OS.get_keycode_string(ev.key_label), ev.unicode,
		ev.pressed, ev.echo, ev.ctrl_pressed, ev.alt_pressed, ev.meta_pressed, ev.shift_pressed]
	_detail.text = last_key
	var i := Keymap.index_of(ev)
	if i >= 0:
		if ev.pressed:
			held[i] = true
		else:
			held.erase(i)
	queue_redraw()


# キーの確かめの図: 10 キーを並べ、押されているキーを光らせる。
func _draw() -> void:
	if not keys_view:
		return
	var f := Kit.font(700)
	for i in B.COLS:
		var r := Rect2(Kit.col_x(i) - 52, 240, 104, 104)
		var on := held.has(i)
		draw_rect(r, Color(Kit.C_AIM, 0.85) if on else Color(1, 1, 1, 0.05))
		draw_rect(r, Kit.C_AIM if on else Color(Kit.C_TEXT, 0.4), false, 3.0)
		draw_string(f, Vector2(r.position.x, r.position.y + 68), S.KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Kit.C_BG if on else Kit.C_TEXT)
	draw_string(f, Vector2(0, 410), str(held.size()), HORIZONTAL_ALIGNMENT_CENTER, 1280, 32, Kit.C_TEXT)
