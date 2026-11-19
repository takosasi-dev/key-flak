# bot で遊ばせるテスト(AC-2・AC-9・NFR-4)。固定の値は Windows で出した物で、CI(Linux)でも同じになることを見る。
extends "res://tests/suite.gd"


func test_ac9_intercept_keeps_towns_in_wave1() -> bool:
	for s in range(1, 11):
		var sim := Sim.new(s, Sim.MODE_DAILY)
		var bot := Bots.new(Bots.INTERCEPT)
		var n := 0
		while sim.wave == 1 and sim.intermission == 0 and not sim.is_over() and n < 10000:
			bot.act(sim)
			sim.step()
			n += 1
		ok(sim.intermission > 0, "種 %d: 波 1 が終わる" % s)
		eq(sim.town_count(), 6, "種 %d: 波 1 の町が 6 つ残る" % s)
	return true


func test_ac2_replay_100_times() -> bool:
	var first := play_bot(2026, Bots.INTERCEPT)
	var want: Dictionary = first["result"]
	ok(first["sim"].is_over(), "終わりまで遊べる")
	var same := 0
	for k in 100:
		var r := replay(2026, first["log"])
		if r["points"] == want["points"] and r["wave"] == want["wave"] and r["kills"] == want["kills"]:
			same += 1
	eq(same, 100, "100 回とも点・届いた波・落とした数が同じ")
	return true


# NFR-4 の照らし。Windows と CI(Linux)で同じ値になる(Web は仕様書 §8.2 で照らす)。
func test_fixed_results() -> bool:
	var a: Dictionary = play_bot(2026, Bots.INTERCEPT)["result"]
	eq([a["points"], a["wave"], a["kills"], a["max_chain"], a["shots"]], FIXED_INTERCEPT, "迎える bot(種 2026)")
	var b: Dictionary = play_bot(2684276895, Bots.NONE)["result"]
	eq([b["points"], b["wave"], b["kills"]], FIXED_NONE, "何もしない bot(2026-11-19 の今日の空)")
	return true


const FIXED_INTERCEPT := [1680, 5, 4, 1, 4]
const FIXED_NONE := [900, 3, 0]


func test_none_bot_loses() -> bool:
	var r: Dictionary = play_bot(3, Bots.NONE)["result"]
	eq(r["reason"], "town", "何もしなければ町が尽きて終わる")
	eq(r["kills"], 0, "落とさない")
	return true
