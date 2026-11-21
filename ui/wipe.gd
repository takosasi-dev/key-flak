# 画面の切り替わり(v0.3.0、画面設計書 §10): 琥珀の掃く線が見えている範囲を左から右へ走り、線より右はまだ夜の地で隠す。
# 線の左には燐光の残りが薄く残る。WIPE_MS で終わる。見た目だけで入力は飲まない(新しい画面は最初から押せる。マウスも通す)。
# 点滅を弱める 入なら main が走らせない。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var view := Rect2(0, 0, 1280, 720)
var start_ms := -100000
var now_ms := 0  # テストが時刻を決める時だけ使う


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run() -> void:
	start_ms = _now()
	queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


# 走り終わるまでの割合(0→1)。走っていなければ 1。
func progress() -> float:
	return clampf(float(_now() - start_ms) / B.WIPE_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _now() - start_ms <= B.WIPE_MS + 50:
		queue_redraw()


func _draw() -> void:
	var k := progress()
	if k >= 1.0:
		return
	var x := view.position.x + view.size.x * Kit.ease_out(k)
	draw_rect(Rect2(x, view.position.y, view.end.x - x, view.size.y), Color(Kit.C_BG, 0.96))
	for i in 6:
		var w := 26.0 * (i + 1)
		draw_rect(Rect2(x - w, view.position.y, w, view.size.y), Color(Kit.C_AMBER, 0.018))
	draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), Kit.C_AMBER, 3.0)
	# 線の上の目盛り(掃く線が物差しに見えるように)
	var y := view.position.y + 8.0
	var n := 0
	while y < view.end.y:
		draw_line(Vector2(x, y), Vector2(x - (12.0 if n % 4 == 0 else 6.0), y), Color(Kit.C_AMBER, 0.6), 1.5)
		y += 24.0
		n += 1
