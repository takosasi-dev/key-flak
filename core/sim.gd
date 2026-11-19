# 1 回のプレイの全状態と step()(仕様書 §9.3〜§9.6)。照準・爆発・ミサイル・爆撃機・着弾・点数・波はここにだけある(INV-1)。
# 入力は発射台の番号(0〜9)の「押す」と「離す」だけ(INV-5)。ui は events() と snapshot() を読んで演出する。
# 解釈: 波の間が終わった step は、波の tick を 0 のまま次の step へ渡す(次の波の tick 0 の予定を出せるように)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Burst := preload("res://core/burst.gd")
const Score := preload("res://core/score.gd")
const Sch := preload("res://core/schedule.gd")

const MODE_DAILY := 0
const MODE_PRACTICE := 1

var mode := MODE_DAILY
var seed_value := 1
var waves: Array = []  # schedule.build(seed)
var tick := 0  # 通しの tick
var wave := 1
var wave_tick := 0
var intermission := 0  # 波の間の残り tick。0 なら戦っている
var next_item := 0  # 今の波の予定の、次に出す番号

var ammo: Array[int] = []
var disabled: Array[bool] = []
var aim_h: Array[int] = []  # 照準の高さの tick。-1 は出ていない
var towns: Array[bool] = []  # 列ごと。町の無い列は false

var missiles: Array = []  # { id, x, y, sx, sy, vx, vy, kind, splits }
var bombers: Array = []  # { id, x, y, vx, k, drops, di, speed }
var bursts: Array = []  # { x, y, age, r, group, chain }
var groups := {}  # 組の番号 → 落とした本数
var _next_id := 0
var _next_group := 0

var points := 0
var kills := 0
var max_chain := 0
var shots := 0  # プレイヤーの爆発の数
var over := false
var reason := ""

var _queue: Array = []  # [押すなら true, 番号]
var _events: Array = []


func _init(p_seed: int, p_mode: int = MODE_DAILY) -> void:
	seed_value = p_seed
	mode = p_mode
	waves = Sch.build(p_seed)
	for c in B.COLS:
		ammo.append(B.AMMO_PER_WAVE)
		disabled.append(false)
		aim_h.append(-1)
		towns.append(c in B.TOWN_COLS)


func queue_press(i: int) -> void:
	if i >= 0 and i < B.COLS:
		_queue.append([true, i])


func queue_release(i: int) -> void:
	if i >= 0 and i < B.COLS:
		_queue.append([false, i])


# 一時停止に入る時に ui が呼ぶ(FR-23)。弾は減らさない。出来事は events() に足す。
func cancel_all_aims() -> void:
	_events = []
	_queue.clear()
	for i in B.COLS:
		_cancel_aim(i)


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


func town_count() -> int:
	return towns.count(true)


func result() -> Dictionary:
	return {"points": points, "wave": wave, "kills": kills, "max_chain": max_chain, "shots": shots, "reason": reason}


static func aim_y(h: int) -> float:
	return B.MARK_Y0 - float(h * B.MARK_SPEED) / B.TICK_HZ


# 地面の x から列(§9.2。0.5 以上は切り上げ)。
static func col_of(x: float) -> int:
	return clampi(int(floor((x - B.COL_X0) / B.COL_W + 0.5)), 0, B.COLS - 1)


func step() -> void:
	_events = []
	# 1
	if over:
		return
	# 2
	var alive: Array = []
	for b: Dictionary in bursts:
		b["age"] += 1
		if b["age"] < B.TOTAL:
			alive.append(b)
	bursts = alive
	# 3
	var q := _queue
	_queue = []
	for item: Array in q:
		if item[0]:
			_press(item[1])
		elif aim_h[item[1]] >= 0:
			_fire(item[1])
	# 4
	for i in B.COLS:
		if aim_h[i] >= 0:
			aim_h[i] += 1
			if aim_y(aim_h[i]) <= B.MARK_TOP:
				_fire(i)
	if intermission == 0:
		_spawn()  # 5
	_move()  # 6
	_hits()  # 7
	_impacts()  # 8
	# 9
	if town_count() == 0:
		over = true
		reason = "town"
		_events.append({"type": "over"})
		return
	tick += 1
	if intermission > 0:
		intermission -= 1
		if intermission == 0:
			wave += 1
			wave_tick = 0
			next_item = 0
			_events.append({"type": "wave_start", "wave": wave})
		return
	if _wave_done():
		_start_intermission()
		return
	wave_tick += 1  # 10


func _press(i: int) -> void:
	if intermission > 0:
		return  # 波の間の「押す」は何もしない
	if disabled[i]:
		_events.append({"type": "disabled", "i": i})
	elif ammo[i] <= 0:
		_events.append({"type": "empty", "i": i})
	elif aim_h[i] < 0:
		aim_h[i] = 0
		_events.append({"type": "aim_start", "i": i})


func _fire(i: int) -> void:
	var y := aim_y(aim_h[i])
	aim_h[i] = -1
	ammo[i] -= 1
	shots += 1
	_next_group += 1
	groups[_next_group] = 0
	bursts.append({"x": Sch.col_x(i), "y": y, "age": 0, "r": B.BURST_R, "group": _next_group, "chain": false})
	_events.append({"type": "burst", "i": i, "y": y})


func _cancel_aim(i: int) -> void:
	if aim_h[i] >= 0:
		aim_h[i] = -1
		_events.append({"type": "aim_cancel", "i": i})


func _spawn() -> void:
	var items: Array = Sch.wave_of(waves, wave)["items"]
	while next_item < items.size() and int(items[next_item]["t"]) <= wave_tick:
		var it: Dictionary = items[next_item]
		if it["kind"] == Sch.BOMBER:
			var right: bool = it["dir"] == 0
			bombers.append({"id": _id(), "x": -B.BOMBER_X_OUT if right else B.SCREEN_W + B.BOMBER_X_OUT, "y": B.BOMBER_Y,
				"vx": (B.BOMBER_SPEED if right else -B.BOMBER_SPEED) / B.TICK_HZ, "k": 0, "drops": it["drops"], "di": 0, "speed": it["speed"]})
		else:
			if missiles.size() >= B.MISSILE_CAP:
				return  # E-9: 空くまで待つ(後ろの予定も順に待つ)
			_add_missile(it["x"], B.SKY_TOP, it["col"], it["speed"], it["kind"], it["splits"])
		next_item += 1


func _id() -> int:
	_next_id += 1
	return _next_id


# (x, y) から列 col の (中心 x, 640) へ一直線。向きは平方根と割り算だけで長さ 1 に直す(共通 §3 の 15)。
func _add_missile(x: float, y: float, col: int, v: float, kind: int, splits: Array) -> void:
	var dx := Sch.col_x(col) - x
	var dy := B.GROUND_Y - y
	var d := sqrt(dx * dx + dy * dy)
	var per := v / B.TICK_HZ
	missiles.append({"id": _id(), "x": x, "y": y, "sx": x, "sy": y, "vx": dx / d * per, "vy": dy / d * per,
		"kind": kind, "splits": splits, "col": col})


func _move() -> void:
	var born: Array = []
	var kept: Array = []
	for m: Dictionary in missiles:
		m["x"] += m["vx"]
		m["y"] += m["vy"]
		if m["kind"] == Sch.SPLIT and m["y"] >= B.SPLIT_Y:
			born.append(m)
		else:
			kept.append(m)
	missiles = kept
	for m: Dictionary in born:
		for c: int in m["splits"]:
			_add_missile(m["x"], m["y"], c, Sch.speed(mini(wave, B.WAVES)), Sch.SLANT, [])
	var gone: Array = []
	for bm: Dictionary in bombers:
		bm["x"] += bm["vx"]
		bm["k"] += 1
		var x: float = bm["x"]
		if x >= Sch.col_x(0) and x <= Sch.col_x(B.COLS - 1) and bm["k"] % B.BOMBER_DROP_TICKS == 0 and bm["di"] < bm["drops"].size():
			_add_missile(x, bm["y"], bm["drops"][bm["di"]], bm["speed"], Sch.SLANT, [])
			bm["di"] += 1
		if x > B.SCREEN_W + B.BOMBER_X_OUT or x < -B.BOMBER_X_OUT:
			gone.append(bm)
	for bm: Dictionary in gone:
		bombers.erase(bm)


# 手順 7。ミサイル・爆撃機を番号の小さい順に見る。年齢 0 の爆発は何も落とさない。
func _hits() -> void:
	var targets: Array = missiles + bombers
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for t: Dictionary in targets:
		var is_bomber := not t.has("kind")
		for b: Dictionary in bursts:
			if b["age"] == 0:
				continue
			var r := Burst.radius(b["age"], b["r"]) + (B.BOMBER_R if is_bomber else 0.0)
			if Burst.hits(t["x"], t["y"], b["x"], b["y"], r):
				_kill(t, b, is_bomber)
				break


func _kill(t: Dictionary, by: Dictionary, is_bomber: bool) -> void:
	if is_bomber:
		bombers.erase(t)
	else:
		missiles.erase(t)
	var g: int = by["group"]
	groups[g] += 1
	var n: int = groups[g]
	var p := Score.kill_points(n, is_bomber)
	points += p
	kills += 1
	max_chain = maxi(max_chain, n)
	if bursts.size() < B.BURST_CAP:
		bursts.append({"x": t["x"], "y": t["y"], "age": 0, "r": B.CHAIN_R, "group": g, "chain": true})
	_events.append({"type": "kill", "x": t["x"], "y": t["y"], "n": n, "points": p, "bomber": is_bomber})


func _impacts() -> void:
	var kept: Array = []
	for m: Dictionary in missiles:
		if m["y"] < B.GROUND_Y:
			kept.append(m)
			continue
		var c := col_of(m["x"])
		var lost := towns[c]
		towns[c] = false
		disabled[c] = true
		_cancel_aim(c)  # E-6
		_events.append({"type": "impact", "col": c, "lost": lost})
	missiles = kept


func _wave_done() -> bool:
	var items: Array = Sch.wave_of(waves, wave)["items"]
	return next_item >= items.size() and missiles.is_empty() and bombers.is_empty() and bursts.is_empty()


func _start_intermission() -> void:
	for i in B.COLS:
		_cancel_aim(i)
	var left := 0
	for a in ammo:
		left += a
	var bonus := Score.wave_bonus(town_count(), left)
	points += bonus
	for i in B.COLS:
		disabled[i] = false
		ammo[i] = B.AMMO_PER_WAVE
	intermission = B.INTERMISSION_TICKS
	_events.append({"type": "wave_clear", "wave": wave, "bonus": bonus, "towns": town_count(), "ammo": left})


# 今の組で一番長い連鎖(生きている爆発の組の中で)。
func chain_now() -> int:
	var best := 0
	for b: Dictionary in bursts:
		best = maxi(best, int(groups[b["group"]]))
	return best


func snapshot() -> Dictionary:
	var marks: Array = []
	for m: Dictionary in missiles:
		if m["vy"] > 0.0 and (B.GROUND_Y - m["y"]) / m["vy"] <= B.MARK_LEAD_TICKS:
			var c: int = m["col"]
			if not (c in marks):
				marks.append(c)
	var launchers: Array = []
	for i in B.COLS:
		launchers.append({"ammo": ammo[i], "disabled": disabled[i], "aim_y": aim_y(aim_h[i]) if aim_h[i] >= 0 else -1.0})
	var bs: Array = []
	for b: Dictionary in bursts:
		bs.append({"x": b["x"], "y": b["y"], "r": Burst.radius(b["age"], b["r"]), "chain": b["chain"]})
	return {"launchers": launchers, "towns": towns.duplicate(), "missiles": missiles, "bombers": bombers, "bursts": bs,
		"impact_marks": marks, "wave": wave, "points": points, "chain": chain_now(), "intermission": intermission > 0,
		"tick": tick, "over": over}
