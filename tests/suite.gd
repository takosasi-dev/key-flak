# テストの土台。ok / eq / near で確かめ、失敗は errors にたまる。空を組み立てて進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Sch := preload("res://core/schedule.gd")
const Bots := preload("res://core/bots.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


func near(got: float, want: float, msg: String, eps: float = 0.001) -> void:
	if absf(got - want) > eps:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


# 予定の無い空(波が終わらないよう、遠い先に 1 本だけ置く)。ミサイルは add() で足す。
static func blank() -> Sim:
	var sim := Sim.new(1, Sim.MODE_PRACTICE)
	var far := {"t": 1 << 30, "kind": Sch.STRAIGHT, "col": 0, "x": 64.0, "speed": 60.0, "splits": [], "dir": 0, "drops": []}
	var w: Array = []
	for k in B.WAVES:
		w.append({"items": [far], "len": 1800})
	sim.waves = w
	return sim


# (x, y) から列 col へ落ちるミサイルを足し、その辞書を返す。
static func add(sim: Sim, x: float, y: float, col: int, v: float = 60.0, kind: int = Sch.STRAIGHT, splits: Array = []) -> Dictionary:
	sim._add_missile(x, y, col, v, kind, splits)
	return sim.missiles[-1]


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		sim.step()
		ev.append_array(sim.events())
	return ev


static func types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


# bot で 1 回遊び、入力の記録 [[step の番号, 押すなら true, 番号], ...] と結果を返す。max_ticks で打ち切る。
static func play_bot(seed_value: int, kind: int, max_ticks: int = 400000) -> Dictionary:
	var sim := Sim.new(seed_value, Sim.MODE_DAILY)
	var bot := Bots.new(kind)
	var log: Array = []
	var n := 0
	while not sim.is_over() and n < max_ticks:
		for a: Array in bot.act(sim):
			log.append([n, a[0], a[1]])
		sim.step()
		n += 1
	return {"sim": sim, "log": log, "result": sim.result()}


# 記録どおりに入力を入れて最後まで回す。
static func replay(seed_value: int, log: Array, max_ticks: int = 400000) -> Dictionary:
	var sim := Sim.new(seed_value, Sim.MODE_DAILY)
	var k := 0
	var n := 0
	while not sim.is_over() and n < max_ticks:
		while k < log.size() and int(log[k][0]) == n:
			if log[k][1]:
				sim.queue_press(log[k][2])
			else:
				sim.queue_release(log[k][2])
			k += 1
		sim.step()
		n += 1
	return sim.result()
