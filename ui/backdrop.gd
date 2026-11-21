# 全部の画面の後ろ(v0.3.0、画面設計書 §10): 夜の地を、窓の見えている範囲(view)全体に塗る。
# radar の時(S0・タイトル・設定)は、地平の真ん中を中心にしたレーダーの目盛り(距離の輪・方位の線)と、ゆっくり回る掃く線、
# 掃く線が通った所で光って消える点を描く。animate が偽なら(点滅を弱める 入)掃く線は止め、点も光らせない。重い物は使わない(_draw だけ)。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const CENTER := Vector2(640, 640)  # 地平の真ん中(発射台の並びの中央)
const RINGS := [150.0, 300.0, 450.0, 600.0]
# 光る点(角度・距離)。決まった場所(乱数を使わない)
const BLIPS := [[-2.55, 380.0], [-2.1, 520.0], [-1.72, 260.0], [-1.25, 470.0], [-0.82, 330.0], [-0.45, 560.0], [-2.9, 210.0], [-0.2, 280.0]]

var view := Rect2(0, 0, 1280, 720)  # 舞台の座標で見えている範囲(main が入れる)
var radar := false
var animate := false
var sweep := true  # 偽なら目盛りだけ(結果の画面)
var now_ms := 0  # テストが時刻を決める時だけ使う


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if radar and animate and sweep:
		queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


# 掃く線の角度(上半分を左から右へ回る。-PI → 0 を 1 周の間に進み、続けて下半分を回る)。時刻だけで決まる。
static func sweep_angle(now: int) -> float:
	return -PI + TAU * fmod(float(now), B.SWEEP_PERIOD_MS) / B.SWEEP_PERIOD_MS


# 掃く線が通ってからの時間(ms)。点の明るさに使う。
static func since_sweep(now: int, angle: float) -> float:
	var a := sweep_angle(now)
	var d := fposmod(a - angle, TAU)
	return d / TAU * B.SWEEP_PERIOD_MS


func _draw() -> void:
	draw_rect(view, Kit.C_BG)
	if not radar:
		return
	var ring := Color(Kit.C_AMBER, 0.07)
	for r: float in RINGS:
		draw_arc(CENTER, r, PI, TAU, 96, ring, 1.5, true)
	for k in range(1, 12):
		var a := PI + PI * k / 12.0
		var d := Vector2(cos(a), sin(a))
		draw_line(CENTER + d * 60.0, CENTER + d * 640.0, Color(Kit.C_AMBER, 0.035 if k % 3 else 0.06), 1.0, true)
	# 外の輪に方位の刻み
	for k in range(0, 73):
		var a := PI + PI * k / 72.0
		var d := Vector2(cos(a), sin(a))
		draw_line(CENTER + d * 600.0, CENTER + d * (612.0 if k % 6 else 624.0), Color(Kit.C_AMBER, 0.14), 1.5, true)
	if not sweep:
		return
	var now := _now() if animate else int(B.SWEEP_PERIOD_MS * 0.3)
	var sa := sweep_angle(now)
	if sa < 0.0:
		# 掃く線と、後ろに残る燐光(扇を細かく分けて薄くしていく)
		var steps := 14
		for k in steps:
			var a0 := sa - 0.05 * k
			var a1 := sa - 0.05 * (k + 1)
			if a1 < -PI:
				break
			var al := 0.11 * (1.0 - float(k) / steps)
			draw_colored_polygon(PackedVector2Array([CENTER, CENTER + Vector2(cos(a0), sin(a0)) * 620.0, CENTER + Vector2(cos(a1), sin(a1)) * 620.0]), Color(Kit.C_AMBER, al))
		draw_line(CENTER, CENTER + Vector2(cos(sa), sin(sa)) * 620.0, Color(Kit.C_AMBER, 0.45), 2.0, true)
	if animate:
		for bl: Array in BLIPS:
			var t: float = since_sweep(now, bl[0]) / B.BLIP_MS
			if t >= 1.0:
				continue
			var p: Vector2 = CENTER + Vector2(cos(bl[0]), sin(bl[0])) * float(bl[1])
			draw_circle(p, 9.0, Color(Kit.C_AMBER, 0.12 * (1.0 - t)))
			draw_circle(p, 3.0, Color(Kit.C_AMBER, 0.7 * (1.0 - t)))
