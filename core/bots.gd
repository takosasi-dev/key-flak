# テスト用の bot(仕様書 §9.12)。sim を読んで、次の step の前に入れる「押す」「離す」を決める。
# 迎える bot: 真っすぐ落ちるミサイルの列を押し、照準の y が狙うミサイルの先頭から 8 px 以内になった step で離す。斜めは見ない。
extends RefCounted

const B := preload("res://core/balance.gd")
const Sch := preload("res://core/schedule.gd")

const NONE := 0
const INTERCEPT := 1

var kind := INTERCEPT
var _target := {}  # 発射台 → 狙っているミサイルの番号
var _shot := {}  # もう狙ったミサイルの番号


func _init(p_kind: int = INTERCEPT) -> void:
	kind = p_kind


# sim に入力を入れ、入れた物を [押すなら true, 番号] の配列で返す(記録に使う)。
func act(sim: RefCounted) -> Array:
	var out: Array = []
	if kind == NONE or sim.is_over():
		return out
	for i in B.COLS:
		var h: int = sim.aim_h[i]
		if h < 0:
			_target.erase(i)
			if sim.disabled[i] or sim.ammo[i] <= 0 or sim.intermission > 0:
				continue
			var m := _pick(sim, i)
			if not m.is_empty():
				_target[i] = m["id"]
				_shot[m["id"]] = true
				out.append([true, i])
			continue
		var t := _find(sim, _target.get(i, -1))
		if t.is_empty():
			t = _pick(sim, i)  # 狙いが先に落ちた: 同じ列の次を狙う。無ければ頂上まで昇らせる
			if t.is_empty():
				continue
			_target[i] = t["id"]
			_shot[t["id"]] = true
		if sim.aim_y(h) - float(t["y"]) <= B.BOT_RELEASE_PX:
			out.append([false, i])
	for a: Array in out:
		if a[0]:
			sim.queue_press(a[1])
		else:
			sim.queue_release(a[1])
	return out


# 列 i の、まだ狙っていない真っすぐのミサイルのうち、一番低い物。
func _pick(sim: RefCounted, i: int) -> Dictionary:
	var best := {}
	for m: Dictionary in sim.missiles:
		if m["kind"] == Sch.STRAIGHT and m["col"] == i and not _shot.has(m["id"]):
			if best.is_empty() or float(m["y"]) > float(best["y"]):
				best = m
	return best


static func _find(sim: RefCounted, id: int) -> Dictionary:
	for m: Dictionary in sim.missiles:
		if m["id"] == id:
			return m
	return {}
