# 波ごとの攻撃の並びを種だけから作る(仕様書 §9.6・INV-3・INV-6)。操作では変わらない。
# 1 つの予定は { t, kind, col, x, speed, splits, dir, drops }。波は { items, len }。波 51 以降は波 50 の予定を使う。
# 解釈: 波 1 の 1・2 本目は rng を引かない。3・4 本目は「出る時刻 → 列」の順で 1 本ずつ引く(他の波と同じ順)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")

enum { STRAIGHT, SLANT, SPLIT, FAST, BOMBER }


static func col_x(col: int) -> float:
	return B.COL_X0 + B.COL_W * col


static func count(w: int) -> int:
	return mini(B.N_BASE + B.N_STEP * (w - 1), B.N_MAX)


static func length(w: int) -> int:
	return mini(B.L_BASE + B.L_STEP * w, B.L_MAX)


static func speed(w: int) -> float:
	return minf(B.SPEED_BASE + B.SPEED_STEP * (w - 1), B.SPEED_MAX)


@warning_ignore("integer_division")
static func bombers(w: int) -> int:
	return 0 if w < 5 else mini(1 + (w - 5) / 4, B.BOMBER_MAX)


# 重みつきで列を選ぶ(町の列は 2、無い列は 1)。
static func pick_col(rng: Rng) -> int:
	var r := rng.next_int(B.WEIGHT_TOTAL)
	var sum := 0
	for c in B.COLS:
		sum += 2 if c in B.TOWN_COLS else 1
		if r < sum:
			return c
	return B.COLS - 1


# 波 1〜50 の予定。
static func build(seed_value: int) -> Array:
	var rng := Rng.new(seed_value)
	var waves: Array = []
	for w in range(1, B.WAVES + 1):
		waves.append(_wave(rng, w))
	return waves


# 波 w(1 から)の予定。51 以降は 50 の物。
static func wave_of(waves: Array, w: int) -> Dictionary:
	return waves[mini(w, waves.size()) - 1]


static func _missile(t: int, kind: int, col: int, x: float, v: float) -> Dictionary:
	return {"t": t, "kind": kind, "col": col, "x": x, "speed": v, "splits": [], "dir": 0, "drops": []}


static func _wave(rng: Rng, w: int) -> Dictionary:
	var n := count(w)
	var len_w := length(w)
	var v := speed(w)
	var list: Array = []
	# 1. 時刻・列・出る x
	for i in n:
		if w == 1:
			if i == 0:
				list.append(_missile(B.TEACH_T1, STRAIGHT, B.TEACH_COL1, col_x(B.TEACH_COL1), B.TEACH_SPEED))
			elif i == 1:
				list.append(_missile(B.TEACH_T2, STRAIGHT, B.TEACH_COL2, col_x(B.TEACH_COL2), B.TEACH_SPEED))
			else:
				var t1 := B.TEACH_T_REST + rng.next_int(len_w - B.TEACH_T_REST)
				var c1 := pick_col(rng)
				list.append(_missile(t1, STRAIGHT, c1, col_x(c1), B.SPEED_BASE))
			continue
		var t := rng.next_int(len_w)
		var c := pick_col(rng)
		var x := clampf(col_x(c) - B.SLANT_SPREAD + rng.next_int(2 * B.SLANT_SPREAD + 1), col_x(0), col_x(B.COLS - 1))
		list.append(_missile(t, SLANT, c, x, v))
	# 2. 種類
	if w == 3:
		for i in _pick_distinct(rng, n, B.SPLIT_COUNT_W3):
			list[i]["kind"] = SPLIT
	elif w == 4:
		for i in _pick_distinct(rng, n, B.FAST_COUNT_W4):
			list[i]["kind"] = FAST
	elif w >= 6:
		for m: Dictionary in list:
			var r := rng.next_int(100)
			m["kind"] = SPLIT if r < B.MIX_SPLIT else (FAST if r < B.MIX_FAST else SLANT)
	for m: Dictionary in list:
		if m["kind"] == FAST:
			m["speed"] = v * B.FAST_RATE_NUM / B.FAST_RATE_DEN
	# 3. 分かれる先
	for m: Dictionary in list:
		if m["kind"] == SPLIT:
			for k in B.SPLIT_INTO:
				m["splits"].append(pick_col(rng))
	# 4. 爆撃機
	for k in bombers(w):
		var bt := rng.next_int(len_w)
		var dir := rng.next_int(2)
		var drops: Array = []
		for d in B.BOMBER_DROPS:
			drops.append(pick_col(rng))
		var bm := _missile(bt, BOMBER, -1, 0.0, v)
		bm["dir"] = dir
		bm["drops"] = drops
		list.append(bm)
	# 出る時刻の小さい順。同じ時刻は引いた順(番号を添えて並べる)
	for i in list.size():
		list[i]["order"] = i
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] or (a["t"] == b["t"] and a["order"] < b["order"]))
	return {"items": list, "len": len_w}


# 0〜n−1 から違う番号を k 個(同じ番号なら引き直す)。
static func _pick_distinct(rng: Rng, n: int, k: int) -> Array:
	var out: Array = []
	while out.size() < k:
		var i := rng.next_int(n)
		if not (i in out):
			out.append(i)
	return out
