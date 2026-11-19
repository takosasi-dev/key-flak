# 人に見せる結果の文字(仕様書 §9.10・共通 §3 の 12)。3 行。
extends RefCounted

const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")


# mode: 0 = 今日の空、1 = 練習。first_today は今日の空の 1 回目か。date は "2026-11-19"。
static func make(date: String, mode: int, first_today: bool, result: Dictionary) -> String:
	var label: String = S.DAILY_FIRST if mode == 0 and first_today else S.MODE_LABEL[mode]
	var body := S.SHARE_BODY % [int(result["wave"]), Score.comma(int(result["points"])), int(result["max_chain"]), int(result["kills"])]
	return "\n".join([S.SHARE_HEAD % [S.NAME, date, label], body, S.URL])
