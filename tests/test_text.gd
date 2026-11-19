# 通し日数・日替わりの種・共有する文字・点の区切りのテスト(AC-18・共通 §3 の 13・§9.10)。
# 種の期待値は Python で別に計算した値を直書きした。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Score := preload("res://core/score.gd")
const Rng := preload("res://core/rng.gd")


func test_ac18_day_index() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01 は 0")
	eq(Day.day_index(2026, 11, 19), 322, "2026-11-19 は 322")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01 は 365")
	eq(Day.day_index(2025, 12, 31), 0, "前は 0(E-16)")
	eq(Day.date_string(2026, 3, 4), "2026-03-04", "日付の文字")
	return true


func test_ac18_day_seed() -> bool:
	eq(Day.day_seed(0), 2654453757, "通し日数 0 の種")
	eq(Day.day_seed(322), 2684276895, "通し日数 322 の種")
	eq(Day.day_seed(365), 860897626, "通し日数 365 の種")
	return true


func test_ac18_share_text() -> bool:
	var r := {"points": 18450, "wave": 7, "max_chain": 6, "kills": 84}
	eq(Share.make("2026-11-19", 0, true, r),
		"KeyFlak 2026-11-19(今日の空・1回目)\n波 7 / 18,450点 / 最大連鎖 6 / 落とした数 84\nhttps://takosasi-dev.github.io/key-flak/", "今日の空の 1 回目")
	ok(Share.make("2026-11-19", 0, false, r).begins_with("KeyFlak 2026-11-19(今日の空)\n"), "2 回目以降")
	ok(Share.make("2026-11-19", 1, false, r).begins_with("KeyFlak 2026-11-19(練習)\n"), "練習")
	ok(Share.make("2026-11-19", 1, true, r).begins_with("KeyFlak 2026-11-19(練習)\n"), "練習に 1 回目は付けない")
	return true


func test_comma() -> bool:
	eq([Score.comma(0), Score.comma(250), Score.comma(18450), Score.comma(1234567), Score.comma(-1450)],
		["0", "250", "18,450", "1,234,567", "-1,450"], "3 桁ごとにコンマ")
	return true


func test_kill_points() -> bool:
	var sum := 0
	for n in range(1, 5):
		sum += Score.kill_points(n, false)
	eq(sum, 250, "4 本の連鎖は 25 + 50 + 75 + 100")
	eq(Score.kill_points(2, true), 200, "爆撃機は 100 × n")
	return true


func test_rng_xorshift32() -> bool:
	var r := Rng.new(1)
	eq([r.next(), r.next(), r.next()], [270369, 67634689, 2647435461], "xorshift32 の最初の 3 つ(種 1)")
	eq(Rng.new(0).state, 1, "種 0 は 1")
	return true
