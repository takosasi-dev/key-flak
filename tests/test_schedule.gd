# 攻撃の並びのテスト(仕様書 §9.6・AC-10〜AC-12・INV-3・FR-19)。
extends "res://tests/suite.gd"


func test_ac11_teach_first_two() -> bool:
	for s: int in [1, 7, 322, 2684276895]:
		var w1: Array = Sch.build(s)[0]["items"]
		eq(w1.size(), 4, "波 1 は 4 本")
		eq([w1[0]["t"], w1[0]["col"], w1[0]["kind"], w1[0]["speed"]], [120, 3, Sch.STRAIGHT, B.TEACH_SPEED], "1 本目: F・tick 120・真っすぐ")
		eq([w1[1]["t"], w1[1]["col"], w1[1]["kind"], w1[1]["speed"]], [600, 6, Sch.STRAIGHT, B.TEACH_SPEED], "2 本目: J・tick 600・真っすぐ")
		for k in [2, 3]:
			ok(int(w1[k]["t"]) >= 1200 and int(w1[k]["t"]) < Sch.length(1), "3・4 本目は 1200 から")
			eq(w1[k]["speed"], B.SPEED_BASE, "3・4 本目は SPEED_BASE")
		ok(w1.all(func(m: Dictionary) -> bool: return m["kind"] == Sch.STRAIGHT and is_equal_approx(m["x"], Sch.col_x(m["col"]))), "真っすぐは落ちる列の真上から")
	# sim の上でも tick 120・600 に出る
	var sim := Sim.new(5, Sim.MODE_DAILY)
	var spawned: Array = []
	for k in 700:
		var before := sim.missiles.size()
		sim.step()
		if sim.missiles.size() > before:
			spawned.append([sim.wave_tick - 1, sim.missiles[-1]["col"], sim.missiles[-1]["sx"]])
	eq(spawned, [[120, 3, 448.0], [600, 6, 832.0]], "sim で F と J の真上に出る")
	return true


func test_ac12_kinds_by_wave() -> bool:
	for s: int in [1, 2, 3, 99, 2684276895]:
		var ws := Sch.build(s)
		var kinds := func(w: int) -> Array:
			return ws[w - 1]["items"].map(func(m: Dictionary) -> int: return m["kind"])
		ok(kinds.call(1).all(func(k: int) -> bool: return k == Sch.STRAIGHT), "波 1 は真っすぐだけ")
		ok(kinds.call(2).all(func(k: int) -> bool: return k == Sch.SLANT), "波 2 は斜めだけ")
		eq(kinds.call(3).count(Sch.SPLIT), 2, "波 3 は分かれる 2 本")
		eq(kinds.call(3).count(Sch.SLANT), Sch.count(3) - 2, "残りは斜め")
		eq(kinds.call(4).count(Sch.FAST), 3, "波 4 は速い 3 本")
		eq(kinds.call(4).count(Sch.SPLIT), 0, "波 4 に分かれるは無い")
		eq(kinds.call(5).count(Sch.BOMBER), 1, "波 5 は爆撃機 1 機")
		eq(kinds.call(5).count(Sch.SLANT), Sch.count(5), "波 5 のミサイルは斜め")
		for w in range(1, 5):
			eq(kinds.call(w).count(Sch.BOMBER), 0, "波 %d に爆撃機は無い" % w)
	return true


func test_counts_lengths_speeds() -> bool:
	eq([Sch.count(1), Sch.count(2), Sch.count(14), Sch.count(50)], [4, 6, 30, 30], "本数 N(w)")
	eq([Sch.length(1), Sch.length(15), Sch.length(50)], [1920, 3600, 3600], "波の長さ L(w)")
	eq([Sch.speed(1), Sch.speed(11), Sch.speed(30)], [60.0, 160.0, 160.0], "速さ v(w)")
	eq([Sch.bombers(4), Sch.bombers(5), Sch.bombers(9), Sch.bombers(13), Sch.bombers(50)], [0, 1, 2, 3, 3], "爆撃機の数")
	var ws := Sch.build(11)
	eq(ws.size(), 50, "波 1〜50")
	for w in range(1, 51):
		var items: Array = ws[w - 1]["items"]
		var ms := items.filter(func(m: Dictionary) -> bool: return m["kind"] != Sch.BOMBER)
		eq(ms.size(), Sch.count(w), "波 %d の本数" % w)
		ok(items.all(func(m: Dictionary) -> bool: return int(m["t"]) >= 0 and int(m["t"]) < Sch.length(w)), "出る時刻は波の長さの中")
		for k in range(1, items.size()):
			ok(int(items[k - 1]["t"]) <= int(items[k]["t"]), "時刻の順")
	eq(Sch.wave_of(ws, 51), ws[49], "波 51 以降は波 50")
	return true


func test_slant_start_x_range() -> bool:
	var ws := Sch.build(4242)
	for w in range(2, 51):
		for m: Dictionary in ws[w - 1]["items"]:
			if m["kind"] == Sch.BOMBER:
				eq(m["drops"].size(), B.BOMBER_DROPS, "投下の先は 10")
				continue
			var x: float = m["x"]
			ok(x >= 64.0 and x <= 1216.0 and absf(x - Sch.col_x(m["col"])) <= B.SLANT_SPREAD, "出る x は 64〜1216、横の差は 384 まで")
			if m["kind"] == Sch.FAST:
				near(m["speed"], Sch.speed(w) * 1.8, "速いは 1.8 倍")
			eq(m["splits"].size(), 3 if m["kind"] == Sch.SPLIT else 0, "分かれる先は 3")
	return true


func test_weighted_col() -> bool:
	# 0〜15 を順に入れた時の列(町の列は 2、無い列は 1)
	var Rng := preload("res://core/rng.gd")
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var rng := Rng.new(12345)
	for k in 16000:
		counts[Sch.pick_col(rng)] += 1
	for c in B.COLS:
		var want := 2000 if c in B.TOWN_COLS else 1000
		ok(absi(counts[c] - want) < 200, "列 %d の重み(%d)" % [c, counts[c]])
	return true


func test_ac10_same_seed_same_sky() -> bool:
	var a := play_bot(77, Bots.INTERCEPT)
	var b := play_bot(77, Bots.NONE)
	ok(a["log"].size() > 0 and b["log"].is_empty(), "操作が違う 2 つの記録")
	var sa: Sim = a["sim"]
	var sb: Sim = b["sim"]
	for w in range(1, 11):
		eq(_plan(sa.waves[w - 1]), _plan(sb.waves[w - 1]), "波 %d の並び" % w)
		eq(_plan(sa.waves[w - 1]), _plan(Sch.build(77)[w - 1]), "種だけで決まる(波 %d)" % w)
	return true


static func _plan(wave: Dictionary) -> Array:
	return wave["items"].map(func(m: Dictionary) -> Array: return [m["t"], m["x"], m["col"], m["kind"], m["splits"], m["dir"], m["drops"]])


func test_different_seeds_differ() -> bool:
	ok(_plan(Sch.build(1)[1]) != _plan(Sch.build(2)[1]), "種が違えば並びも違う")
	return true
