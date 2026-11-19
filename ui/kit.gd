# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)と、地面・発射台・町の絵。画面設計書 §8 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。作りは RootCall の ui/kit.gd。
extends RefCounted

const B := preload("res://core/balance.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

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
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_SEL := Color("6BB8FF")
const C_GOOD := Color("7EE787")
const C_WARN := Color("FFB84D")
const C_EMPTY := Color("FF4D4D")

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


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


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。キーボードでの選択は ui/menu.gd が見た目を変える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.55)
	var fill := Color(C_SEL, 0.16) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.12), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


static func col_x(i: int) -> float:
	return B.COL_X0 + B.COL_W * i


# 空の 2 色の帯(上から下へ)。
static func draw_sky(ci: CanvasItem, alpha: float = 1.0) -> void:
	var top := Color(C_BG, alpha)
	var bottom := Color(C_BG2, alpha)
	ci.draw_polygon(PackedVector2Array([Vector2(0, B.SKY_TOP), Vector2(B.SCREEN_W, B.SKY_TOP), Vector2(B.SCREEN_W, B.GROUND_Y), Vector2(0, B.GROUND_Y)]),
		PackedColorArray([top, top, bottom, bottom]))


# 地面の帯と線。
static func draw_ground(ci: CanvasItem, alpha: float = 1.0) -> void:
	ci.draw_rect(Rect2(0, B.GROUND_Y, B.SCREEN_W, 8), Color(C_GROUND, alpha))
	ci.draw_line(Vector2(0, B.GROUND_Y), Vector2(B.SCREEN_W, B.GROUND_Y), Color(C_TOWN, 0.5 * alpha), 2.0)


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
