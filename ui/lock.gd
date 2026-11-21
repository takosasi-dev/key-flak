# 選んだボタンの照準の角(v0.3.0)。ボタンの子に置き、外側 MARGIN から LOCK_MS で縁まで寄る(照準が合う動き)。
# Kit.still(点滅を弱める 入)なら最初から寄った形。見た目だけで、マウスも通す。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const MARGIN := 7.0
const FAR := 16.0

var start_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func restart() -> void:
	start_ms = Time.get_ticks_msec()
	queue_redraw()


func k() -> float:
	return 1.0 if Kit.still else Kit.ease_out(float(Time.get_ticks_msec() - start_ms) / B.LOCK_MS)


func _process(_delta: float) -> void:
	if k() < 1.0:
		queue_redraw()


func _draw() -> void:
	var p := get_parent() as Control
	if p == null:
		return
	var m := MARGIN + FAR * (1.0 - k())
	var r := Rect2(Vector2(-m, -m), p.size + Vector2(2 * m, 2 * m))
	var disabled := p is Button and (p as Button).disabled
	Kit.draw_brackets(self, r, 14.0, Color(Kit.C_AMBER, 0.5 if disabled else 1.0), 3.0)
