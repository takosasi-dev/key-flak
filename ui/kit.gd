# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・板・目盛り・照準の角・キーの札)と、地面・発射台・町の絵。
# 画面設計書 §8(遊びの場の色)と §10(UI の見た目 v0.3.0「夜の対空監視所」)の色はここに置く。
# 見た目の既定は ui/theme.tres(tools/make_theme.gd が作る。project の gui/theme/custom で全部の Control に付く)。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const B := preload("res://core/balance.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/BigShouldersStencil-Subset.ttf"  # 題字・数字(ASCII だけ。日本語は Noto へ落とす)
const EXT := 2000.0  # 空と地面を左右に延ばす幅(横長の窓の余りで切れて見えないように)

# 遊びの場の色(画面設計書 §8。意味の色なので枠や飾りには使わない)
const C_BG := Color("0B1020")
const C_BG2 := Color("141B2D")
const C_GROUND := Color("2A313C")
const C_MISSILE := Color("FF6B6B")
const C_SPLIT := Color("FFB84D")
const C_FAST := Color("FF4DA6")
const C_BOMBER := Color("C9D1D9")
const C_BURST := Color("FFFFFF")
const C_CHAIN := Color("FFE066")
const C_AIM := Color("6BB8FF")
const C_OFF := Color("4A5260")
const C_TOWN := Color("8B95A5")
const C_RUIN := Color("3A404A")
const C_MARK := Color("FF4D4D")
const C_GOOD := Color("7EE787")
const C_WARN := Color("FFB84D")
const C_EMPTY := Color("FF4D4D")
# 夜の対空監視所の板(v0.3.0、画面設計書 §10)。スコープの硝子・罫・燐光の琥珀・字。琥珀は空の中に置かない(分かれるミサイルの色と混ぜない)
const C_PANEL := Color("121A2B")
const C_RULE := Color("2C3652")
const C_AMBER := Color("FFC062")
const C_AMBER_DIM := Color("8C6A33")
const C_TEXT := Color("ECE6DA")
const C_DIM := Color("9AA3B5")
const C_INK := Color("0B1020")  # 琥珀の上の字
const C_SEL := C_AMBER

static var _fonts := {}
static var _num: Font = null
static var still := false  # 点滅を弱める 入(動きを減らす設定を兼ねる)。main が設定から入れる


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字と数字の字体(Big Shoulders Stencil の 800)。ASCII に無い字(点・波 など)は Noto Sans JP の 700 で描く。
static func num_font() -> Font:
	if _num == null:
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.fallbacks = [font(700)]
		_num = fv
	return _num


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# 数字のラベル(表示用の字体。縁取りでどんな地の上でも読める)。
static func num_label(text: String, size: int, color: Color = C_TEXT, outline: int = 0) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", num_font())
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", C_BG)
	return l


# 平らな箱(StyleBoxFlat)。角は小さく、硝子の板の形。
static func box(bg: Color, border: Color, width: int, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.anti_aliasing = true
	return s


# ボタン。見た目(5 つの状態)は theme.tres。node_name は自動の確認が押す時の目印。
# キーボードの選択は ui/menu.gd が set_selected で型の変種(SelButton)に替え、照準の角を寄せる。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない(選択は menu が持つ)
	b.add_theme_font_size_override("font_size", size)
	return b


static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


static func col_x(i: int) -> float:
	return B.COL_X0 + B.COL_W * i


static func ease_out(k: float) -> float:
	var t := clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)


# 2 色のコントラスト比(WCAG の相対輝度)。
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var ch := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


# --- _draw の中から使う絵 ---

# 硝子の板: 塗り・細い縁・四隅に照準の角(corner が 0 なら角なし)。
static func draw_plate(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, corner: float = 10.0, corner_color: Color = C_AMBER_DIM) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, edge, false, 1.5)
	if corner > 0.0:
		draw_brackets(ci, r, corner, corner_color, 2.0)


# 照準の角(長方形の四隅に L 字)。
static func draw_brackets(ci: CanvasItem, r: Rect2, arm: float, c: Color, w: float = 3.0) -> void:
	for cx: float in [r.position.x, r.end.x]:
		for cy: float in [r.position.y, r.end.y]:
			var sx := 1.0 if cx == r.position.x else -1.0
			var sy := 1.0 if cy == r.position.y else -1.0
			ci.draw_polyline(PackedVector2Array([Vector2(cx, cy + sy * arm), Vector2(cx, cy), Vector2(cx + sx * arm, cy)]), c, w)


# 目盛り: x0〜x1 の横線に step ごとの刻み(major ごとに長い刻み)。up なら刻みを上へ。
static func draw_scale(ci: CanvasItem, x0: float, x1: float, y: float, c: Color, step: float = 16.0, major: int = 4, up: bool = false) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), c, 1.5)
	var d := -1.0 if up else 1.0
	var k := 0
	var x := x0
	while x <= x1 + 0.5:
		ci.draw_line(Vector2(x, y), Vector2(x, y + d * (8.0 if k % major == 0 else 4.0)), c, 1.5)
		x += step
		k += 1


# 縦の目盛り(空の高さの物差し)。
static func draw_vscale(ci: CanvasItem, x: float, y0: float, y1: float, c: Color, right: bool = false, step: float = 32.0, major: int = 4) -> void:
	var d := -1.0 if right else 1.0
	ci.draw_line(Vector2(x, y0), Vector2(x, y1), c, 1.5)
	var k := 0
	var y := y1
	while y >= y0 - 0.5:
		ci.draw_line(Vector2(x, y), Vector2(x + d * (10.0 if k % major == 0 else 5.0), y), c, 1.5)
		y -= step
		k += 1


# キーの札(発射台の下の文字・キーの確かめ・画面の下の案内)。lit: 押している(照準の青)、off: 止まっている。
static func draw_keycap(ci: CanvasItem, r: Rect2, text: String, size: int, lit: bool = false, off: bool = false, alpha: float = 1.0) -> void:
	var fill := Color(C_AIM, 0.85 * alpha) if lit else Color(C_PANEL, 0.92 * alpha)
	var edge := Color(C_AIM, alpha) if lit else Color(C_RULE.lightened(0.25), alpha)
	ci.draw_rect(r, fill)
	ci.draw_rect(r, edge, false, 1.5)
	ci.draw_line(Vector2(r.position.x + 3, r.end.y - 2), Vector2(r.end.x - 3, r.end.y - 2), Color(0, 0, 0, 0.35 * alpha), 2.0)
	var col := C_INK if lit else (C_OFF if off else C_TEXT)
	var f := font(700)  # 小さい札は型紙の字より読みやすい太字のゴシック
	var asc := f.get_ascent(size) - f.get_descent(size)
	ci.draw_string(f, Vector2(r.position.x, r.get_center().y + asc * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(col, alpha))


# 炸裂の印(結果の新しい記録・題字): 長さの揃わない放射の線と、煙の粒。
static func draw_flak(ci: CanvasItem, at: Vector2, r: float, c: Color, rays: int = 12, turn: float = 0.0) -> void:
	var lens := [1.0, 0.62, 0.85, 0.55, 0.95, 0.7]
	for k in rays:
		var a := turn + TAU * k / rays
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(at + d * r * 0.3, at + d * r * float(lens[k % lens.size()]), c, 2.5, true)
	for k in 3:
		var a := turn + 0.9 + TAU * k / 3.0
		ci.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.42, r * 0.09, c)


# 空の 2 色の帯(上から下へ)。左右は窓の余りまで延ばす。
static func draw_sky(ci: CanvasItem, alpha: float = 1.0) -> void:
	var top := Color(C_BG, alpha)
	var bottom := Color(C_BG2, alpha)
	ci.draw_polygon(PackedVector2Array([Vector2(-EXT, B.SKY_TOP), Vector2(B.SCREEN_W + EXT, B.SKY_TOP), Vector2(B.SCREEN_W + EXT, B.GROUND_Y), Vector2(-EXT, B.GROUND_Y)]),
		PackedColorArray([top, top, bottom, bottom]))


# 地面の帯と線。
static func draw_ground(ci: CanvasItem, alpha: float = 1.0) -> void:
	ci.draw_rect(Rect2(-EXT, B.GROUND_Y, B.SCREEN_W + 2 * EXT, 8), Color(C_GROUND, alpha))
	ci.draw_line(Vector2(-EXT, B.GROUND_Y), Vector2(B.SCREEN_W + EXT, B.GROUND_Y), Color(C_TOWN, 0.5 * alpha), 2.0)


# 町(四角の集まり、幅 96)。ruin は 0(無傷)〜1(崩れた)。
static func draw_town(ci: CanvasItem, x: float, ruin: float, alpha: float = 1.0) -> void:
	var hs := [18.0, 26.0, 14.0, 22.0, 30.0, 16.0, 24.0, 12.0]
	var w := B.TOWN_W / hs.size()
	var c := Color(C_TOWN.lerp(C_RUIN, ruin), alpha)
	for k in hs.size():
		var h: float = hs[k] * (1.0 - 0.7 * ruin) - (4.0 * ruin if k % 2 == 1 else 0.0)
		ci.draw_rect(Rect2(x - B.TOWN_W / 2 + k * w + 1, B.GROUND_Y - h, w - 2, h), c)


# 発射台(三角、幅 48)。止まっている時は灰色に ×。
static func draw_launcher(ci: CanvasItem, x: float, off: bool, lit: bool, alpha: float = 1.0) -> void:
	var half := B.LAUNCHER_W / 2
	var pts := PackedVector2Array([Vector2(x - half, B.GROUND_Y), Vector2(x + half, B.GROUND_Y), Vector2(x, B.GROUND_Y - 30)])
	var c := C_OFF if off else (C_AIM.lightened(0.45) if lit else C_AIM)
	ci.draw_colored_polygon(pts, Color(c, alpha))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(C_BG, alpha), 2.0, true)
	if off:
		draw_cross(ci, Vector2(x, B.GROUND_Y - 12), 10.0, Color(C_TEXT, alpha))


static func draw_cross(ci: CanvasItem, at: Vector2, r: float, c: Color) -> void:
	ci.draw_line(at + Vector2(-r, -r), at + Vector2(r, r), c, 3.0, true)
	ci.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), c, 3.0, true)
