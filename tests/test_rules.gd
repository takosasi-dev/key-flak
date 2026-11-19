# sim の決まりのテスト(仕様書 §9.3〜§9.7・AC-3〜AC-8・AC-13〜AC-17・AC-21 の core 側・E-2〜E-10)。
extends "res://tests/suite.gd"

const Burst := preload("res://core/burst.gd")
const Score := preload("res://core/score.gd")


func test_ac3_press_90_ticks() -> bool:
	var sim := blank()
	sim.queue_press(3)
	var ev := run(sim, 1)
	eq(types(ev), ["aim_start"], "押すと照準が出る")
	run(sim, 89)
	sim.queue_release(3)
	ev = run(sim, 1)
	var bursts := of_type(ev, "burst")
	eq(bursts.size(), 1, "爆発が 1 つ")
	near(bursts[0]["y"], 320.0, "y = 620 − 90 × 400 ÷ 120")
	eq(sim.bursts.size(), 1, "爆発が 1 つできる")
	near(sim.bursts[0]["x"], 448.0, "F の列の中心 x")
	eq(sim.ammo[3], 2, "F の弾が 2")
	return true


func test_ac4_auto_burst_at_top() -> bool:
	var sim := blank()
	sim.queue_press(0)
	var ev := run(sim, 161)
	eq(of_type(ev, "burst").size(), 0, "頂上の前は爆発しない")
	ok(Sim.aim_y(sim.aim_h[0]) > B.MARK_TOP, "まだ 80 より下")
	ev = run(sim, 1)
	var b := of_type(ev, "burst")
	eq(b.size(), 1, "y が 80 以下になった step で自動で爆発")
	ok(b.size() == 1 and float(b[0]["y"]) <= B.MARK_TOP, "頂上の高さ")
	eq(sim.aim_h[0], -1, "照準は消える")
	eq(sim.ammo[0], 2, "弾が 1 減る")
	return true


func test_ac5_burst_radius() -> bool:
	var want := {0: 0.0, 9: 26.0, 18: 52.0, 40: 52.0, 60: 26.0, 72: 0.0}
	for a: int in want:
		near(Burst.radius(a, B.BURST_R), want[a], "年齢 %d" % a)
	return true


func test_ac6_chain_points() -> bool:
	var sim := blank()
	var a := add(sim, 478.0, 320.0, 3, 0.0)
	var c := add(sim, 508.0, 320.0, 4, 0.0)
	sim.queue_press(3)
	run(sim, 90)
	sim.queue_release(3)
	var ev := run(sim, 60)
	var kills := of_type(ev, "kill")
	eq(kills.size(), 2, "2 本とも落ちる")
	if kills.size() == 2:
		eq(kills[0]["points"], 25, "1 本目は 25")
		eq(kills[1]["points"], 50, "誘爆で落ちた 2 本目は 50")
		eq(kills[1]["n"], 2, "組の 2 本目")
	ok(not sim.missiles.has(a) and not sim.missiles.has(c), "消える")
	eq(sim.points, 75, "点")
	eq(sim.max_chain, 2, "最大連鎖")
	return true


func test_chain_burst_made_and_grouped() -> bool:
	var sim := blank()
	add(sim, 448.0, 320.0, 3, 0.0)
	sim.queue_press(3)
	run(sim, 90)
	sim.queue_release(3)
	run(sim, 3)
	var chains := sim.bursts.filter(func(b: Dictionary) -> bool: return b["chain"])
	eq(chains.size(), 1, "落ちた所に誘爆ができる")
	if chains.size() == 1:
		eq(chains[0]["r"], B.CHAIN_R, "誘爆の半径")
		eq(chains[0]["group"], sim.bursts[0]["group"], "当てた爆発と同じ組")
	return true


func test_ac7_empty() -> bool:
	var sim := blank()
	for k in 3:
		sim.queue_press(5)
		run(sim, 2)
		sim.queue_release(5)
		run(sim, 1)
	eq(sim.ammo[5], 0, "3 発で弾 0")
	sim.queue_press(5)
	var ev := run(sim, 1)
	eq(types(ev), ["empty"], "弾 0 で押すと empty")
	eq(sim.aim_h[5], -1, "照準は出ない")
	return true


func test_ac8_impact_town_and_repair() -> bool:
	var sim := blank()
	add(sim, 192.0, 639.8, 1, 60.0)
	var ev := run(sim, 1)
	var imp := of_type(ev, "impact")
	eq(imp.size(), 1, "着弾")
	if imp.size() == 1:
		eq(imp[0]["col"], 1, "S の列")
		eq(imp[0]["lost"], true, "町を失う")
	eq(sim.town_count(), 5, "町が 1 つ減る")
	sim.queue_press(1)
	eq(types(run(sim, 1)), ["disabled"], "S は止まっている")
	sim.queue_press(1)
	eq(types(run(sim, 1)), ["disabled"], "波の間ずっと止まる")
	sim.waves[0] = {"items": [], "len": 1800}
	ev = run(sim, 1)
	eq(types(ev), ["wave_clear"], "波が終わる")
	eq(sim.disabled[1], false, "波の終わりに直る")
	ev = run(sim, B.INTERMISSION_TICKS)
	eq(of_type(ev, "wave_start").size(), 1, "次の波")
	eq(sim.wave, 2, "波 2")
	sim.queue_press(1)
	eq(types(run(sim, 1)), ["aim_start"], "次の波で S が使える")
	eq(sim.towns[1], false, "町は戻らない")
	return true


func test_impact_no_town_col() -> bool:
	var sim := blank()
	add(sim, 448.0, 639.8, 3, 60.0)
	var imp := of_type(run(sim, 1), "impact")
	eq(imp.size(), 1, "着弾")
	if imp.size() == 1:
		eq(imp[0]["lost"], false, "F の列に町は無い")
	eq(sim.town_count(), 6, "町は減らない")
	eq(sim.disabled[3], true, "発射台は止まる")
	return true


func test_col_of_rounding() -> bool:
	eq(Sim.col_of(64.0), 0, "列 0")
	eq(Sim.col_of(128.0), 1, "ちょうど半分は切り上げ")
	eq(Sim.col_of(127.9), 0, "半分より下")
	eq(Sim.col_of(-50.0), 0, "左の外")
	eq(Sim.col_of(1300.0), 9, "右の外")
	return true


func test_ac13_split_at_300() -> bool:
	var sim := blank()
	var m := add(sim, 448.0, 299.8, 3, 60.0, Sch.SPLIT, [0, 5, 9])
	run(sim, 1)
	ok(not sim.missiles.has(m), "y 300 で消える")
	eq(sim.missiles.size(), 3, "3 本になる")
	eq(sim.missiles.map(func(x: Dictionary) -> int: return x["col"]), [0, 5, 9], "予定の先の順")
	ok(sim.missiles.all(func(x: Dictionary) -> bool: return x["kind"] == Sch.SLANT), "3 本とも斜め")
	var ids: Array = sim.missiles.map(func(x: Dictionary) -> int: return x["id"])
	ok(ids[0] < ids[1] and ids[1] < ids[2], "新しい番号を先の順に振る")
	# 上で落とすと出ない
	var sim2 := blank()
	add(sim2, 448.0, 200.0, 3, 0.0, Sch.SPLIT, [0, 5, 9])
	sim2.queue_press(3)
	run(sim2, 127)  # y = 620 − 127 × 10 / 3 ≒ 196.7
	sim2.queue_release(3)
	var ev := run(sim2, 40)
	eq(of_type(ev, "kill").size(), 1, "分かれる前に落ちる")
	eq(sim2.missiles.size(), 0, "3 本は出ない")
	return true


func test_ac14_impact_marks() -> bool:
	var sim := blank()
	add(sim, 704.0, 640.0 - 0.5 * 121, 5, 60.0)
	add(sim, 448.0, 100.0, 3, 60.0)
	eq(sim.snapshot()["impact_marks"], [], "着弾まで 121 tick は入らない")
	run(sim, 1)
	eq(sim.snapshot()["impact_marks"], [5], "120 tick で入る。遠い方は入らない")
	return true


func test_ac15_over_when_no_towns() -> bool:
	var sim := blank()
	for c in B.COLS:
		sim.towns[c] = c == 2
	add(sim, 320.0, 639.8, 2, 60.0)
	add(sim, 704.0, 300.0, 5, 60.0)
	var ev := run(sim, 1)
	ok(types(ev).has("over"), "町が 0 になった step で終わる")
	ok(sim.is_over(), "終わり")
	eq(sim.result()["reason"], "town", "理由は町")
	eq(sim.missiles.size(), 1, "残りのミサイルは描くだけ(E-10)")
	var t: int = sim.tick
	run(sim, 10)
	eq(sim.tick, t, "終わった後は進まない")
	return true


func test_ac16_wave_bonus() -> bool:
	var sim := blank()
	sim.towns[4] = false
	sim.queue_press(0)
	run(sim, 10)
	sim.queue_release(0)
	sim.disabled[7] = true
	sim.waves[0] = {"items": [], "len": 1800}
	var ev := run(sim, B.TOTAL + 2)
	var wc := of_type(ev, "wave_clear")
	eq(wc.size(), 1, "爆発が消えた step で波が終わる")
	if wc.size() == 1:
		eq(wc[0]["bonus"], Score.wave_bonus(5, 29), "町 × 100 + 弾 × 5")
		eq(wc[0]["bonus"], 645, "5 × 100 + 29 × 5")
	eq(sim.points, 645, "ボーナスが点に入る")
	eq(sim.ammo[0], 3, "弾が 3 に戻る")
	eq(sim.disabled[7], false, "止まっていた発射台が直る")
	return true


func test_ac17_top_and_release_same_step() -> bool:
	var sim := blank()
	sim.queue_press(4)
	run(sim, 161)
	sim.queue_release(4)
	var ev := run(sim, 1)
	eq(of_type(ev, "burst").size(), 1, "爆発は 1 つ")
	eq(sim.ammo[4], 2, "弾は 1 つだけ減る")
	eq(of_type(run(sim, 5), "burst").size(), 0, "後から爆発しない")
	return true


func test_e2_release_without_press() -> bool:
	var sim := blank()
	sim.queue_release(2)
	eq(run(sim, 1), [], "押していない離すは何もしない")
	eq(sim.ammo[2], 3, "弾はそのまま")
	return true


func test_e3_press_twice() -> bool:
	var sim := blank()
	sim.queue_press(2)
	run(sim, 5)
	var h: int = sim.aim_h[2]
	sim.queue_press(2)
	eq(run(sim, 1), [], "照準が出ている時の押すは何もしない")
	eq(sim.aim_h[2], h + 1, "照準はそのまま昇る")
	return true


func test_e6_impact_cancels_aim() -> bool:
	var sim := blank()
	sim.queue_press(1)
	run(sim, 3)
	add(sim, 192.0, 639.8, 1, 60.0)
	var ev := run(sim, 1)
	ok(types(ev).has("aim_cancel"), "照準を取り消す")
	eq(sim.aim_h[1], -1, "照準が消える")
	eq(sim.ammo[1], 3, "弾は減らない")
	return true


func test_e7_hit_before_impact() -> bool:
	var sim := blank()
	add(sim, 448.0, 639.8, 3, 60.0)
	sim.bursts.append({"x": 448.0, "y": 640.0, "age": 10, "r": B.BURST_R, "group": 99, "chain": false})
	sim.groups[99] = 0
	var ev := run(sim, 1)
	eq(of_type(ev, "kill").size(), 1, "当たりが先")
	eq(of_type(ev, "impact").size(), 0, "落ちたミサイルは着弾しない")
	return true


func test_e8_split_inside_burst() -> bool:
	var sim := blank()
	add(sim, 448.0, 299.8, 3, 60.0, Sch.SPLIT, [1, 2, 4])
	sim.bursts.append({"x": 448.0, "y": 300.0, "age": 20, "r": B.BURST_R, "group": 7, "chain": false})
	sim.groups[7] = 0
	var ev := run(sim, 1)
	eq(of_type(ev, "kill").size(), 3, "分かれた 3 本とも当たる")
	eq(of_type(ev, "kill").map(func(e: Dictionary) -> int: return e["n"]), [1, 2, 3], "組の 1〜3 本目")
	return true


func test_age0_burst_hits_nothing() -> bool:
	var sim := blank()
	sim.queue_press(3)
	run(sim, 90)
	add(sim, 448.0, 320.0, 3, 0.0)  # 爆発の中心にちょうど置く
	sim.queue_release(3)
	var ev := run(sim, 1)
	eq(of_type(ev, "kill").size(), 0, "生まれた step の爆発は落とさない")
	ev = run(sim, 1)
	eq(of_type(ev, "kill").size(), 1, "次の step で落とす")
	return true


func test_e9_missile_cap() -> bool:
	var sim := blank()
	var item := {"t": 0, "kind": Sch.STRAIGHT, "col": 0, "x": 64.0, "speed": 60.0, "splits": [], "dir": 0, "drops": []}
	sim.waves[0] = {"items": [item, sim.waves[0]["items"][0]], "len": 1800}
	for k in B.MISSILE_CAP:
		add(sim, 640.0, 200.0, 4, 0.0)
	run(sim, 1)
	eq(sim.missiles.size(), B.MISSILE_CAP, "上限の間は出さない")
	eq(sim.next_item, 0, "待っている")
	sim.missiles.pop_back()
	run(sim, 1)
	eq(sim.missiles.size(), B.MISSILE_CAP, "空いた step で出す")
	eq(sim.next_item, 1, "出した")
	return true


func test_burst_cap_no_chain() -> bool:
	var sim := blank()
	add(sim, 448.0, 320.0, 3, 0.0)
	sim.queue_press(3)
	run(sim, 90)
	for k in B.BURST_CAP - 1:
		sim.bursts.append({"x": 1200.0, "y": 100.0, "age": 30, "r": B.CHAIN_R, "group": 50, "chain": true})
	sim.groups[50] = 0
	sim.queue_release(3)  # プレイヤーの爆発で 40 になる
	var ev := run(sim, 3)
	eq(of_type(ev, "kill").size(), 1, "落ちる")
	eq(sim.points, 25, "点は入る")
	eq(sim.bursts.filter(func(b: Dictionary) -> bool: return b["group"] != 50 and b["chain"]).size(), 0, "誘爆は作らない")
	eq(sim.bursts.filter(func(b: Dictionary) -> bool: return not b["chain"]).size(), 1, "プレイヤーの爆発は作る")
	return true


func test_bomber_flight_drop_and_kill() -> bool:
	var sim := blank()
	var item := {"t": 0, "kind": Sch.BOMBER, "col": -1, "x": 0.0, "speed": 100.0, "splits": [], "dir": 0, "drops": [1, 2]}
	sim.waves[0] = {"items": [item, sim.waves[0]["items"][0]], "len": 1800}
	run(sim, 1)
	eq(sim.bombers.size(), 1, "爆撃機が出る")
	near(sim.bombers[0]["x"], -B.BOMBER_X_OUT + B.BOMBER_SPEED / 120.0, "左の外から右へ")
	var ev := run(sim, 2000)
	var dropped := sim.missiles.size() + of_type(ev, "impact").size()
	eq(dropped, 2, "予定の 2 本だけ落とす(足りなくなった後は落とさない)")
	eq(sim.bombers.size(), 0, "反対側の外で消える")
	eq(sim.town_count() + of_type(ev, "impact").filter(func(e: Dictionary) -> bool: return e["lost"]).size(), 6, "消えても罰は無い")
	# 当てる
	var sim2 := blank()
	sim2.waves[0] = {"items": [item, sim2.waves[0]["items"][0]], "len": 1800}
	run(sim2, 1)
	sim2.bombers[0]["x"] = 448.0 + B.BURST_R + B.BOMBER_R - 1.0
	sim2.bombers[0]["vx"] = 0.0
	sim2.bursts.append({"x": 448.0, "y": B.BOMBER_Y, "age": 30, "r": B.BURST_R, "group": 3, "chain": false})
	sim2.groups[3] = 0
	var k := of_type(run(sim2, 1), "kill")
	eq(k.size(), 1, "半径 + BOMBER_R の中なら落ちる")
	if k.size() == 1:
		eq(k[0]["bomber"], true, "爆撃機")
		eq(k[0]["points"], 100, "100 × 1")
	return true


func test_bomber_drops_inside_columns_only() -> bool:
	var sim := blank()
	var item := {"t": 0, "kind": Sch.BOMBER, "col": -1, "x": 0.0, "speed": 100.0, "splits": [], "dir": 1, "drops": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]}
	sim.waves[0] = {"items": [item, sim.waves[0]["items"][0]], "len": 1800}
	var xs: Array = []
	for k in 2000:
		var before := sim.missiles.size()
		sim.step()
		if sim.missiles.size() > before:
			xs.append(sim.missiles[-1]["sx"])
	ok(xs.size() > 0, "投下する")
	ok(xs.all(func(x: float) -> bool: return x >= 64.0 and x <= 1216.0), "x が 64〜1216 の間だけ")
	return true


func test_cancel_all_aims() -> bool:
	var sim := blank()
	sim.queue_press(0)
	sim.queue_press(9)
	run(sim, 20)
	sim.cancel_all_aims()
	eq(types(sim.events()), ["aim_cancel", "aim_cancel"], "出ている照準を全部取り消す")
	eq(sim.aim_h.count(-1), B.COLS, "照準が無い")
	eq(sim.ammo[0] + sim.ammo[9], 6, "弾は減らない")
	return true


func test_intermission_press_ignored() -> bool:
	var sim := blank()
	sim.waves[0] = {"items": [], "len": 1800}
	run(sim, 1)
	ok(sim.intermission > 0, "波の間")
	sim.queue_press(3)
	eq(run(sim, 1), [], "波の間の押すは何もしない")
	return true


func test_hits_lowest_id_first_burst_order() -> bool:
	var sim := blank()
	add(sim, 448.0, 320.0, 3, 0.0)
	sim.bursts.append({"x": 448.0, "y": 320.0, "age": 20, "r": B.BURST_R, "group": 1, "chain": false})
	sim.bursts.append({"x": 448.0, "y": 320.0, "age": 20, "r": B.BURST_R, "group": 2, "chain": false})
	sim.groups[1] = 4
	sim.groups[2] = 0
	var k := of_type(run(sim, 1), "kill")
	eq(k.size(), 1, "落ちる")
	if k.size() == 1:
		eq(k[0]["n"], 5, "作った順で最初の爆発の組に入る")
	return true


func test_missile_direction_unit() -> bool:
	var sim := blank()
	var m := add(sim, 64.0, 64.0, 9, 120.0)
	var len := sqrt(float(m["vx"]) * float(m["vx"]) + float(m["vy"]) * float(m["vy"]))
	near(len, 1.0, "1 tick に 速さ ÷ 120 px")
	near(float(m["vx"]) / float(m["vy"]), (1216.0 - 64.0) / (640.0 - 64.0), "落ちる列の中心へ")
	return true
