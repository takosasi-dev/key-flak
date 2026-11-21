# 文言(INV-7・画面設計書 §6)。画面に出す文字はすべてここに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "KeyFlak"
const VERSION := "v0.3.0"
const URL := "https://takosasi-dev.github.io/key-flak/"

# 発射台のキーの印字(§9.2。左から 0〜9)
const KEYS := ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"]

# S0
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1
const TAGLINE := "押して、離した高さで落とす"
const B_DAILY := "今日の空"
const B_PRACTICE := "練習(毎回ちがう空)"
const B_SETTINGS := "設定"
const REC_FIRST := "1回目 %s点"
const REC_TODAY_BEST := "今日の最高 %s点"
const REC_BEST := "最高 %s点"
const REC_NONE := "まだ遊んでいない"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2
const ESC := "Esc"
const BAR_WAVE := "波 %d"
const BAR_POINTS := "%s点"
const BAR_CHAIN := "連鎖 %d"
const WAVE_CLEAR := "波 %d をしのいだ"
const BONUS_LINE := "町 %d × %d  +  弾 %d × %d  =  +%s"
# 磨きで足した文言(v0.2.0)。新しい種類が出る波の一言(番号は波)と、最初の 1 本の案内
const WAVE_NEW := ["", "", "斜めに落ちてくる。落ちる先の列で迎える", "途中で 3 本に分かれる。分かれる前に落とす", "速いミサイルが混じる。早めに押し始める", "爆撃機が横切りながら落とす。爆撃機も落とせる"]
const FIRST_HINT := "%s を押さえて、線が重なる高さで離す"
const POPUP := "+%d"

# S3
const REASON_TOWN := "町がすべてやられた"
const RES_POINTS := "%s点"
const RES_NEW_BEST := "最高 +%s(新しい記録)"
const RES_TO_BEST := "最高まで −%s"
const RES_TODAY_BEST := "(今日の最高 %s点)"
const RES_WAVE := "届いた波 %d"
const RES_KILLS := "落とした数 %d"
const RES_CHAIN := "最大連鎖 %d"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.10)
const MODE_LABEL := ["今日の空", "練習"]
const DAILY_FIRST := "今日の空・1回目"
const SHARE_HEAD := "%s %s(%s)"
const SHARE_BODY := "波 %d / %s点 / 最大連鎖 %d / 落とした数 %d"

# S4
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const ON := "入"
const OFF := "切"
const B_KEYS := "キーの確かめ"
const B_BACK := "戻る"
const KEYS_HELP := "押されているキーが光る。Esc で戻る"
const KEYS_HELD := "同時に押している数"
const KEYS_LAST := "最後に届いたキー"
const KEY_DETAIL := "physical_keycode %d (%s) / key_label %s / unicode %d / pressed %s / echo %s / ctrl %s alt %s meta %s shift %s"
# キーの確かめの枠に出す名前と値の組(1 組 1 行)
const KEY_ROWS := [["physical_keycode", "%d (%s)"], ["key_label / unicode", "%s / %d"], ["pressed / echo", "%s / %s"], ["ctrl / alt / meta / shift", "%s / %s / %s / %s"]]

# S5
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# UI の作り直しで足した文言(v0.3.0。画面設計書 §6・§10)。画面の下のキーの案内と、数字に添える短い名前
const HINT_SELECT := "選ぶ"
const HINT_OK := "決める"
const HINT_CHANGE := "変える"
const HUD_WAVE := "波"
const HUD_CHAIN := "連鎖"
const UNIT_POINTS := "点"
const RES_WAVE_L := "届いた波"
const RES_KILLS_L := "落とした数"
const RES_CHAIN_L := "最大連鎖"
const NEW_BEST := "新しい記録"
