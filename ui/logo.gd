# 題字(v0.3.0、画面設計書 §10)。「KeyFlak」を表示用の字体(Big Shoulders Stencil)で琥珀に描き、下に高さの物差し、
# 「k」の右上の空に照準の輪と十字、その中に炸裂の印。入りの動き(LOGO_MS): 掃く線が左から字を出す → 照準が寄る → 炸裂。
# still が真(点滅を弱める 入)なら最初から出来上がった形。Control と _draw だけで描く。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const TEXT := "KeyFlak"
const SCALE_BELOW := 0.26  # 物差しの高さ(字の下の線から px の何倍下か)。y の下がりは 0.21

var px := 128
var still := false
var start_ms := -100000
var now_ms := 0  # テストが時刻を決める時だけ使う


func _init(p_px: int = 128, p_still: bool = false) -> void:
	px = p_px
	still = p_still
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	start_ms = _now()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func _k() -> float:
	return 1.0 if still else clampf(float(_now() - start_ms) / B.LOGO_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _k() < 1.0 or _now() - start_ms < B.LOGO_MS + 100:
		queue_redraw()


# 字 i の濃さ(0→1)。掃く線が字を通ると出る(全体の 0〜55%)。
func reveal(i: int) -> float:
	var sweep := _k() / 0.55
	return clampf((sweep * TEXT.length() - i) * 1.5, 0.0, 1.0)


# 照準が寄る(55〜85%)。0: 遠い、1: 合った。
func lock() -> float:
	return Kit.ease_out((_k() - 0.55) / 0.3)


# 炸裂(85% から)。まだなら -1、出来上がりは 1。
func burst() -> float:
	var k := _k()
	return -1.0 if k < 0.85 else clampf((k - 0.85) / 0.15, 0.0, 1.0)


func text_width() -> float:
	return Kit.num_font().get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _draw() -> void:
	var f := Kit.num_font()
	var w := text_width()
	var x0 := (size.x - w) / 2.0
	var base := size.y * 0.5 + px * 0.34
	var x := x0
	var k_end := 0.0
	for i in TEXT.length():
		var ch := TEXT[i]
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var a := reveal(i)
		if a > 0.0:
			draw_string(f, Vector2(x + 4, base + 4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Kit.C_AMBER_DIM.darkened(0.55), a))
			draw_string(f, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Kit.C_AMBER, a))
		x += cw
		k_end = x
	# 高さの物差し(字の下。y の下がりより下に置く)
	var sw := _k() / 0.55
	var sx1 := lerpf(x0, x0 + w, clampf(sw, 0.0, 1.0))
	if sx1 > x0:
		Kit.draw_scale(self, x0, sx1, base + px * SCALE_BELOW, Color(Kit.C_AMBER, 0.55), 16.0, 4)
	if not still and sw > 0.0 and sw < 1.0:
		draw_line(Vector2(sx1, base - px * 0.8), Vector2(sx1, base + 32.0), Kit.C_AMBER, 2.0)
	# 照準と炸裂(k の右上の空)
	var at := Vector2(k_end + px * 0.26, base - px * 0.74)
	var lk := lock()
	if _k() >= 0.55:
		var r := px * 0.2 * (1.0 + 2.0 * (1.0 - lk))
		var col := Color(Kit.C_AMBER, 0.35 + 0.55 * lk)  # 題字と同じ琥珀
		draw_arc(at, r, 0, TAU, 48, col, 2.0, true)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(at + d * (r - 6.0), at + d * (r + 10.0), col, 2.0, true)
	var bt := burst()
	if bt >= 0.0:
		Kit.draw_flak(self, at, px * (0.1 + 0.08 * bt), Color(Kit.C_CHAIN, 1.0 - 0.3 * bt), 10, 0.2)
