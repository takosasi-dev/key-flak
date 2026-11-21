# S3 結果(画面設計書 §4・§10)。点を 600 ms で数え上げ(表示用の字体で大きく)、3 つの数を札に、最高との差・共有する文字を出す。
# 新しい記録の時は、数え上げの後に炸裂の印(「新しい記録」)を押す。点滅を弱める 入なら数え上げず、印も最初から押してある。
# もう1回は最初から選んであり(照準の角)、300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-14)。
# 作りは RootCall の ui/result.gd。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const SCORE_PX := 132
const SCORE_BASE := 196.0  # 点の字の下の線

var menu: Menu
var share := ""
var new_best := false
var still := false
var _points := 0
var _shown_at := 0
var _shown := -1
var _retry: Button
var _copied: Label
var _score: Control
var _stats: Array = []  # [名前, 数]


# rec は save_store.record() の戻り値。mode: 0 = 今日の空、1 = 練習。p_still は点滅を弱める 入。
func build(mode: int, result: Dictionary, rec: Dictionary, share_text: String, p_still: bool = false) -> void:
	size = Vector2(1280, 720)
	share = share_text
	still = p_still
	_points = int(result["points"])
	_shown_at = Time.get_ticks_msec()
	new_best = rec["prev_best"] != null and bool(rec["new_best"])  # 比べる最高が無い初めての回には印を押さない
	add_child(Kit.place(Kit.label(S.REASON_TOWN, 28, Kit.C_AMBER, 700), 0, 18, 1280, 44))
	_score = Control.new()
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score.draw.connect(_draw_score)
	add_child(Kit.place(_score, 0, 60, 1280, 160))
	if rec["prev_best"] != null:
		var best := int(rec["prev_best"]["score"])
		var text: String = S.RES_NEW_BEST % Score.comma(_points - best) if rec["new_best"] else S.RES_TO_BEST % Score.comma(best - _points)
		if mode == 0:
			text += S.RES_TODAY_BEST % Score.comma(maxi(best, _points))
		add_child(Kit.place(Kit.label(text, 22, Kit.C_GOOD if rec["new_best"] else Kit.C_DIM, 700), 0, 212, 1280, 34))
	_stats = [[S.RES_WAVE_L, int(result["wave"])], [S.RES_KILLS_L, int(result["kills"])], [S.RES_CHAIN_L, int(result["max_chain"])]]
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 352, 300, 64)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = false  # 右クリックで Godot の英語のメニューを出さない(Ctrl+C は効く)
	box.focus_mode = Control.FOCUS_CLICK
	add_child(Kit.place(box, 290, 436, 700, 118))  # 3 行が縦のスクロールバー無しで収まる高さ
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 22), 430, 570, 200, 54)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 22), 650, 570, 200, 54)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 18, Kit.C_DIM, 500)
	add_child(Kit.place(_copied, 0, 630, 1280, 26))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN), 0, 654, 1280, 30))
	add_child(Kit.place(KeyHint.new([[["Enter", "R"], S.B_RETRY]], HORIZONTAL_ALIGNMENT_RIGHT), 760, 686, 496, 30))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, copy, title] as Array[Button], 0)  # もう1回は最初から選んである(押せない間も照準の角を出す)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


# 見せる点(0 から COUNT_MS で数え上がる)。時刻だけで決まる。
@warning_ignore("integer_division")
static func shown_points(points: int, since_ms: int, p_still: bool) -> int:
	if p_still or since_ms >= B.COUNT_MS:
		return points
	return points * maxi(since_ms, 0) / B.COUNT_MS


# 新しい記録の印の押し具合(-1: まだ、0→1: 押している、1: 押した)。数え上げの後に押す。
static func stamp_k(since_ms: int, p_still: bool) -> float:
	if p_still:
		return 1.0
	if since_ms < B.COUNT_MS:
		return -1.0
	return clampf(float(since_ms - B.COUNT_MS) / B.STAMP_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() - _shown_at
	var v := shown_points(_points, t, still)
	if v != _shown or (new_best and t < B.COUNT_MS + B.STAMP_MS + 100):
		_shown = v
		_score.queue_redraw()
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false
		menu.lock.queue_redraw()


func _draw() -> void:
	# 理由の両側の線
	var tw := Kit.font(700).get_string_size(S.REASON_TOWN, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	Kit.draw_scale(self, 640 - tw / 2 - 170, 640 - tw / 2 - 24, 40, Color(Kit.C_AMBER, 0.45), 16.0, 4)
	Kit.draw_scale(self, 640 + tw / 2 + 24, 640 + tw / 2 + 170, 40, Color(Kit.C_AMBER, 0.45), 16.0, 4)
	# 3 つの数の札
	for i in _stats.size():
		var r := Rect2(290 + 240 * i, 262, 220, 74)
		Kit.draw_plate(self, r, Color(Kit.C_PANEL, 0.92), Kit.C_RULE, 0.0)
		draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(Kit.C_AMBER, 0.6), 2.0)
		draw_string(Kit.font(500), Vector2(r.position.x, r.position.y + 24), _stats[i][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Kit.C_DIM)
		draw_string(Kit.font(800), Vector2(r.position.x, r.end.y - 12), Score.comma(_stats[i][1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Kit.C_TEXT)


# 大きな点と「点」、新しい記録の印。_score(0, 60 から)の中に描く。
func _draw_score() -> void:
	var f := Kit.num_font()
	var num := Score.comma(maxi(_shown, 0))
	var nw := f.get_string_size(Score.comma(_points), HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_PX).x  # 最後の点の幅で置く(数え上げの間に横へ揺れない)
	var uw := Kit.font(700).get_string_size(S.UNIT_POINTS, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var x0 := 640.0 - (nw + 10.0 + uw) / 2.0
	var base := SCORE_BASE - 60.0
	var nx := x0 + nw - f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_PX).x  # 右を揃えて数え上げる
	_score.draw_string(f, Vector2(nx + 5, base + 5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_PX, Color(Kit.C_AMBER_DIM.darkened(0.4), 0.8))
	_score.draw_string(f, Vector2(nx, base), num, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_PX, Kit.C_TEXT)
	_score.draw_string(Kit.font(700), Vector2(x0 + nw + 10.0, base), S.UNIT_POINTS, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Kit.C_DIM)
	if not new_best:
		return
	var k := stamp_k(Time.get_ticks_msec() - _shown_at, still)
	if k < 0.0:
		return
	# 炸裂の印: 点の右上に、少し傾けた札「新しい記録」と放射の線。押す時に大きい所から縮む
	var at := Vector2(minf(x0 + nw + uw + 120.0, 1150.0), base - 56.0)
	var sc := 1.0 + 0.6 * (1.0 - Kit.ease_out(k))
	_score.draw_set_transform(at, -0.12, Vector2(sc, sc))
	Kit.draw_flak(_score, Vector2.ZERO, 78.0, Color(Kit.C_CHAIN, 0.75 * k + 0.25), 16, 0.1)
	var r := Rect2(-74, -20, 148, 40)
	_score.draw_rect(r, Kit.C_INK)
	_score.draw_rect(r, Kit.C_CHAIN, false, 2.5)
	_score.draw_string(Kit.font(800), Vector2(r.position.x, 8), S.NEW_BEST, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Kit.C_CHAIN)
	_score.draw_set_transform(Vector2.ZERO)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		retry.emit()
		return
	menu.key(ev)
