# 点数(仕様書 §9.7)と、点の 3 桁区切り。整数だけで数える。
extends RefCounted

const B := preload("res://core/balance.gd")


# 組の n 本目を落とした時の点。爆撃機は 100 × n。
static func kill_points(n: int, bomber: bool) -> int:
	return (B.BOMBER_POINTS if bomber else B.KILL_POINTS) * n


static func wave_bonus(towns: int, ammo: int) -> int:
	return towns * B.BONUS_TOWN + ammo * B.BONUS_AMMO


# 18450 → "18,450"
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
