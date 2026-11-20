# 調整値(仕様書 §9.8・INV-7)。時間は tick(1/120 秒)の整数、速さは px/秒で持つ。
# 演出の時間(ms)・設定の段もここに置く。ほかのファイルに数値の調整値を書かない。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8

# 画面と空(§9.1)
const GROUND_Y := 640.0
const SKY_TOP := 64.0
const SCREEN_W := 1280.0
const COLS := 10
const COL_X0 := 64.0
const COL_W := 128.0
const TOWN_COLS := [1, 2, 4, 5, 7, 8]  # S D G H K L(D-6)

# 照準(§9.4)
const MARK_Y0 := 620.0
const MARK_TOP := 80.0
const MARK_SPEED := 400  # px/秒

# 爆発(§9.4)
const BURST_R := 52.0
const CHAIN_R := 36.0
const GROW := 18
const HOLD := 30
const SHRINK := 24
const TOTAL := GROW + HOLD + SHRINK

const AMMO_PER_WAVE := 3

# ミサイル(§9.5・§9.6)。速さは px/秒
const TEACH_SPEED := 50.0
const SPEED_BASE := 60.0
const SPEED_STEP := 10.0
const SPEED_MAX := 160.0
const FAST_RATE_NUM := 9
const FAST_RATE_DEN := 5
const SPLIT_Y := 300.0
const SLANT_SPREAD := 384

# 爆撃機(§9.5)
const BOMBER_Y := 140.0
const BOMBER_SPEED := 90.0
const BOMBER_R := 20.0
const BOMBER_DROP_TICKS := 180
const BOMBER_X_OUT := 40.0
const BOMBER_DROPS := 10
const BOMBER_MAX := 3

const MARK_LEAD_TICKS := 120
const INTERMISSION_TICKS := 360
const MISSILE_CAP := 60
const BURST_CAP := 40

# 攻撃の並び(§9.6)
const WAVES := 50
const N_BASE := 4
const N_STEP := 2
const N_MAX := 30
const L_BASE := 1800
const L_STEP := 120
const L_MAX := 3600
const TEACH_T1 := 120
const TEACH_T2 := 600
const TEACH_T_REST := 1200
const TEACH_COL1 := 3  # F
const TEACH_COL2 := 6  # J
const SPLIT_COUNT_W3 := 2
const FAST_COUNT_W4 := 3
const MIX_SPLIT := 15  # 波 6 以降: r < 15 で分かれる
const MIX_FAST := 35  # r < 35 で速い
const SPLIT_INTO := 3
const WEIGHT_TOTAL := 16  # 町の列 2 × 6 + 無い列 1 × 4

# 点数(§9.7)
const KILL_POINTS := 25
const BOMBER_POINTS := 100
const BONUS_TOWN := 100
const BONUS_AMMO := 5

# 日替わりの種(共通 §3 の 13)
const DAY_SEED_MUL := 2654435761
const DAY_SALT := 0x464C
const EPOCH_YEAR := 2026

# テスト用の bot(§9.12)
const BOT_RELEASE_PX := 8.0

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75

# 演出(§9.9・画面設計書 §8)。ms と px
const SHAKE_KILL_PX := 5.0
const SHAKE_KILL_MS := 120
const SHAKE_IMPACT_PX := 6.0
const SHAKE_IMPACT_MS := 150
const POPUP_MS := 600
const POPUP_BIG := 1.6
const FLASH_MS := 200  # empty・disabled の印
const IMPACT_FLASH_MS := 300
const CRUMBLE_MS := 400
const WAVE_BANNER_MS := 1000
const CLEAR_COUNT_MS := 1500
const COUNT_MS := 600
const OVER_MS := 600
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const REDUCED_FLASH_ALPHA := 0.2
const KILL_PITCH_MAX := 12  # 半音
const AIM_LINE_W := 96.0
const LAUNCHER_W := 48.0
const TOWN_W := 96.0

# 磨きで足した演出(v0.2.0。仕様書 §14)。ms と px。ゲームの決まりには効かない
const IMPACT_FLASH_A := 0.7  # 着弾の列の閃光の不透明度(点滅を弱める時は REDUCED_FLASH_ALPHA まで)
const IMPACT_COL_W := 120.0  # 着弾の閃光の幅
const IMPACT_COL_H := 150.0  # 着弾の閃光の高さ
const DUST_MS := 600  # 着弾の土煙の輪が広がる時間
const DUST_R := 70.0
const SMOKE_PERIOD_MS := 1600  # やられた町から昇る煙の 1 周
const MARK_ICON_Y := 590.0  # 落ちる先の印(下向きの三角)の下の先。発射台と町(高さ 30)より上に出す
const MARK_PULSE_MS := 320
const AIM_RING_A := 0.24  # 照準の高さに出す、爆発の大きさ(BURST_R)の輪
const AIM_FLOW_GAP := 22.0  # 照準の線を昇る光の点の間隔
const AIM_FLOW_SPEED := 0.3  # 昇る光の点の速さ(px/ms)
const BURST_FLASH_MS := 120  # 爆発が生まれた時の白い芯
const BURST_FLASH_A := 0.85
const KILL_FLASH_MS := 140  # 落とした所の白い光
const SPARK_MS := 360  # 落とした所から飛ぶ火花
const SPARKS := 8
const SPARKS_BIG := 14
const SPARK_LEN := 60.0
const SPARK_LEN_BIG := 92.0
const GHOST_MS := 450  # 落としたミサイルの線が消えていく時間
const HEAD_HALO := 9.0  # ミサイルの先頭の光の輪
const TRAIL_BRIGHT := 72.0  # ミサイルの線の、先頭から明るく描く長さ
const BUMP_MS := 220  # 落とした時に上の点が跳ねる
const BUMP_SCALE := 1.15
const BUMP_SCALE_BIG := 1.4
const POPUP_RISE := 34.0  # 浮かぶ点が昇る高さ
const WAVE_NEW_MS := 2600  # 新しい種類が出る波の始めに、一言を出す時間
const OVER_DIM := 0.5  # 終わりの 600 ms で空を暗くする
const FX_CAP := 24  # 同時に描く火花・白い光・浮かぶ点の上限(それぞれ)
