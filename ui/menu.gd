# キーボードでボタンを選ぶ(共通 §3 の 18)。↑↓ で選び、Enter か Space で押す(キーを押した瞬間に効く)。マウスでも押せる。
# 押した時の動きはボタンの pressed に繋いでおく。選んだボタンは型の変種 SelButton(theme.tres)になり、照準の角(ui/lock.gd)が寄る。
# 選びを動かすと select、押すと confirm の小さな音(v0.3.0)。
extends RefCounted

const Kit := preload("res://ui/kit.gd")
const Lock := preload("res://ui/lock.gd")

var buttons: Array[Button] = []
var sel := 0
var lock: Lock


func _init(list: Array[Button], first: int = 0) -> void:
	buttons = list
	sel = clampi(first, 0, maxi(buttons.size() - 1, 0))
	lock = Lock.new()
	for b in buttons:
		b.mouse_entered.connect(func() -> void: select(buttons.find(b)))
		b.pressed.connect(func() -> void: Sfx.play("confirm"))
	_paint()


func select(i: int) -> void:
	if i < 0 or i >= buttons.size() or (i == sel and lock.get_parent() != null):
		return
	sel = i
	_paint()


func _paint() -> void:
	for k in buttons.size():
		Kit.set_selected(buttons[k], k == sel)
	if buttons.is_empty():
		return
	if lock.get_parent() != null:
		lock.get_parent().remove_child(lock)
	buttons[sel].add_child(lock)
	lock.restart()


# キーを受ける。使ったら真。
func key(ev: InputEventKey) -> bool:
	if not ev.pressed or ev.echo or buttons.is_empty():
		return false
	match ev.physical_keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var b := buttons[sel]
			if not b.disabled:
				b.pressed.emit()
		_:
			return false
	return true


func _move(d: int) -> void:
	select((sel + d + buttons.size()) % buttons.size())
	Sfx.play("select")
