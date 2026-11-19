# 爆発の半径の式と当たりの判定(仕様書 §9.4・INV-4)。
# 当たりは「中心どうしの距離の 2 乗 ≤ 半径の 2 乗」の hits() だけで見る。
extends RefCounted

const B := preload("res://core/balance.gd")


# 年齢 a(tick)の半径。r は最大の半径(BURST_R か CHAIN_R)。
static func radius(a: int, r: float) -> float:
	if a < B.GROW:
		return r * a / B.GROW
	if a < B.GROW + B.HOLD:
		return r
	if a >= B.TOTAL:
		return 0.0
	return r * (B.TOTAL - a) / B.SHRINK


static func hits(px: float, py: float, cx: float, cy: float, r: float) -> bool:
	var dx := px - cx
	var dy := py - cy
	return dx * dx + dy * dy <= r * r
