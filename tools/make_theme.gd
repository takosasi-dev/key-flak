# ui/theme.tres を作る(v0.3.0 の見た目「夜の対空監視所」。project の gui/theme/custom で全部の Control に付く)。色を変えたら回し直してコミットする。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは normal / hover / focus / pressed / disabled と、キーボードで選んだ時の型の変種 SelButton。入力欄・メニュー・スクロールバー・つまみ・チェックも作る。
# 作りは KeySwat の tools/make_theme.gd。絵は生の画素の ImageTexture(圧縮の形は Web だけでエラーになった)。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var t := build()
	var err := ResourceSaver.save(t, OUT)
	print("theme: %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# 四角い小さな絵(チェックとつまみ用)。inner が透明でなければ内側を塗る。
static func _icon(size: int, edge: Color, inner: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var on_edge := x < 2 or y < 2 or x >= size - 2 or y >= size - 2
			if on_edge:
				img.set_pixel(x, y, edge)
			elif inner.a > 0.0 and x >= 5 and y >= 5 and x < size - 5 and y < size - 5:
				img.set_pixel(x, y, inner)
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 22
	var amb := Kit.C_AMBER
	var panel := Kit.C_PANEL

	# ボタン: 硝子の板。選ぶと琥珀の縁(と、menu が描く照準の角)
	t.set_font("font", "Button", Kit.font(700))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", Kit.box(panel, Kit.C_RULE.lightened(0.12), 2))
	t.set_stylebox("hover", "Button", Kit.box(panel.lerp(amb, 0.08), Color(amb, 0.55), 2))
	t.set_stylebox("focus", "Button", Kit.box(Color(0, 0, 0, 0), amb, 3))
	t.set_stylebox("pressed", "Button", Kit.box(amb, amb, 2))
	t.set_stylebox("disabled", "Button", Kit.box(Kit.C_BG, Color(Kit.C_RULE, 0.7), 2))
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", Kit.C_TEXT)
	t.set_color("font_pressed_color", "Button", Kit.C_INK)
	t.set_color("font_hover_pressed_color", "Button", Kit.C_INK)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.55))
	t.set_constant("outline_size", "Button", 0)
	t.set_type_variation("SelButton", "Button")
	var sel := Kit.box(panel.lerp(amb, 0.07), amb, 2)
	t.set_stylebox("normal", "SelButton", sel)
	t.set_stylebox("hover", "SelButton", sel)
	t.set_color("font_color", "SelButton", Kit.C_TEXT)
	t.set_color("font_hover_color", "SelButton", Kit.C_TEXT)
	t.set_stylebox("disabled", "SelButton", Kit.box(panel.lerp(amb, 0.03), Color(amb, 0.5), 2))  # 選んであるがまだ押せない(結果の最初の 300 ms)
	t.set_color("font_disabled_color", "SelButton", Color(Kit.C_TEXT, 0.6))

	# 字
	t.set_color("font_color", "Label", Kit.C_TEXT)

	# 板
	t.set_stylebox("panel", "Panel", Kit.box(panel, Kit.C_RULE, 2))
	t.set_stylebox("panel", "PanelContainer", Kit.box(panel, Kit.C_RULE, 2))

	# 入力欄(結果の共有する文字の枠)
	for type: String in ["TextEdit", "LineEdit"]:
		var n := Kit.box(Color("0E1524"), Kit.C_RULE, 2)
		n.content_margin_left = 16
		n.content_margin_right = 16
		n.content_margin_top = 8
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = amb
		t.set_stylebox("normal", type, n)
		t.set_stylebox("read_only", type, n)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, Kit.font(500))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_readonly_color", type, Kit.C_TEXT)
		t.set_color("font_selected_color", type, Kit.C_TEXT)
		t.set_color("selection_color", type, Color(amb, 0.35))
		t.set_color("caret_color", type, amb)
		t.set_color("font_placeholder_color", type, Kit.C_DIM)

	# 右クリックのメニュー・ツールチップ(今は出さないが、出た時に既定の見た目に戻らないように)
	var pop := Kit.box(panel, amb, 2)
	pop.content_margin_left = 6
	pop.content_margin_right = 6
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", Kit.box(Color(amb, 0.22), Color(0, 0, 0, 0), 0))
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_disabled_color", "PopupMenu", Kit.C_DIM)
	t.set_color("font_separator_color", "PopupMenu", Kit.C_DIM)
	var line := StyleBoxLine.new()
	line.color = Kit.C_RULE
	line.thickness = 2
	t.set_stylebox("separator", "PopupMenu", line)
	t.set_stylebox("panel", "TooltipPanel", Kit.box(panel, amb, 2))
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# スクロールバー
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("0E1524")
		var grab := StyleBoxFlat.new()
		grab.bg_color = Kit.C_RULE.lightened(0.2)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = Color(amb, 0.7)
		var grab_on := grab.duplicate() as StyleBoxFlat
		grab_on.bg_color = amb
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_on)

	# つまみ(今は画面で使っていないが、後から足した時に既定の見た目に戻らないように)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Kit.C_RULE
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rail_on := rail.duplicate() as StyleBoxFlat
	rail_on.bg_color = amb
	var grab_n := _icon(18, Kit.C_TEXT, Kit.C_TEXT)
	var grab_h := _icon(18, amb, amb)
	var grab_d := _icon(18, Kit.C_DIM, Kit.C_DIM)
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, rail)
		t.set_stylebox("grabber_area", type, rail_on)
		t.set_stylebox("grabber_area_highlight", type, rail_on)
		t.set_icon("grabber", type, grab_n)
		t.set_icon("grabber_highlight", type, grab_h)
		t.set_icon("grabber_disabled", type, grab_d)

	# チェック
	var off := _icon(20, Kit.C_DIM)
	var on := _icon(20, amb, amb)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_font("font", type, Kit.font(700))
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_hover_color", type, Kit.C_TEXT)
		t.set_color("font_pressed_color", type, Kit.C_TEXT)
		t.set_color("font_focus_color", type, Kit.C_TEXT)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, Kit.box(Color(0, 0, 0, 0), amb, 2))
	return t
