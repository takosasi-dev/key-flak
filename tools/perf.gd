# 負荷の測定(撤退基準 R-4・NFR-1)。ミサイル 60・爆発 40・爆撃機 3・照準 10 を保ったプレイ画面を 3600 フレーム(60 fps で 60 秒)動かし、
# 1 フレームの「sim を進める + snapshot + _draw」にかかった時間(CPU 側だけ。ヘッドレスはラスタライズしない)の 50%・95% 値を出す。
# 実行: python tools/gd.py run res://tools/perf.gd [ミサイルの数(既定 60)]
extends SceneTree

const B := preload("res://core/balance.gd")

var play: Control  # ui/play.gd は Sfx(自動読み込み)を使うので、読み込みは動き出してから
var rng := RandomNumberGenerator.new()
var frames := 0
var want_missiles := 60
var seen := {"missiles": 0, "bursts": 0, "bombers": 0, "aims": 0}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		want_missiles = int(args[0])
	rng.seed = 7
	_setup.call_deferred()


func _setup() -> void:
	play = load("res://ui/play.gd").new()
	root.add_child(play)
	play.set_process(false)  # 進めるのはこの測定の _process から(1 フレーム 1/60 秒)
	play.start(1, 12345)


func _process(_delta: float) -> bool:
	if play == null or play.sim == null:
		return false
	_fill()
	play._process(1.0 / 60.0)
	var s: RefCounted = play.sim
	seen["missiles"] += s.missiles.size()
	seen["bursts"] += s.bursts.size()
	seen["bombers"] += s.bombers.size()
	seen["aims"] += s.aim_h.filter(func(h: int) -> bool: return h >= 0).size()
	frames += 1
	if frames % 600 == 0:
		print("フレーム %d(描いた回数 %d)" % [frames, play.draws])
	if frames >= 3600 + 2:
		_report()
		return true
	return false


# 減った分を足して、量を保つ(落ちたミサイルの誘爆も含めて測る)。
func _fill() -> void:
	var s: RefCounted = play.sim
	for i in B.COLS:
		s.towns[i] = i in B.TOWN_COLS
		s.disabled[i] = false
		s.ammo[i] = B.AMMO_PER_WAVE
		if s.aim_h[i] < 0 or s.aim_h[i] > 140:
			s.aim_h[i] = 20 + rng.randi_range(0, 60)
	s.missiles = s.missiles.filter(func(m: Dictionary) -> bool: return m["y"] < 560.0)
	while s.missiles.size() < want_missiles:
		var kinds := [0, 1, 2, 3]
		s._add_missile(rng.randf_range(64, 1216), rng.randf_range(80, 420), rng.randi_range(0, 9), 40.0, kinds[rng.randi_range(0, 3)], [1, 2, 3])
	while s.bombers.size() < 3:
		s.bombers.append({"id": s._id(), "x": rng.randf_range(100, 1100), "y": B.BOMBER_Y, "vx": 0.75, "k": 1, "drops": [], "di": 0, "speed": 60.0})
	while s.bursts.size() < B.BURST_CAP:
		s._next_group += 1
		s.groups[s._next_group] = 0
		s.bursts.append({"x": rng.randf_range(64, 1216), "y": rng.randf_range(100, 600), "age": rng.randi_range(18, 47), "r": B.BURST_R,
			"group": s._next_group, "chain": rng.randi_range(0, 1) == 1})
	s.intermission = 0


func _report() -> void:
	var list: Array = play.cost_us.slice(2)
	list.sort()
	var n := list.size()
	print("描いた回数 %d / フレーム %d" % [play.draws, frames])
	if n == 0:
		print("_draw が呼ばれていない(ヘッドレスでは描画の時間を測れない)")
		quit(1)
		return
	var p := func(q: float) -> float: return list[mini(int(ceil(n * q)) - 1, n - 1)] / 1000.0
	print("平均の量: ミサイル %.1f / 爆発 %.1f / 爆撃機 %.1f / 照準 %.1f" % [seen["missiles"] / float(frames), seen["bursts"] / float(frames),
		seen["bombers"] / float(frames), seen["aims"] / float(frames)])
	print("1 フレームの CPU 時間(ms): 50%% %.2f / 95%% %.2f / 最大 %.2f(%d フレーム)" % [p.call(0.5), p.call(0.95), list[-1] / 1000.0, n])
	print("NFR-1(95%% が 16.7 ms 以内): %s" % ("満たす" if p.call(0.95) <= 16.7 else "満たさない"))
	quit(0)
