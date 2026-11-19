# 保存のテスト(仕様書 §9.11・AC-19・E-12・E-15・NFR-9)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


func test_ac19_empty_broken_version() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-12)")
	st = _fresh('{"version": 2, "practice_best": {"score": 5, "wave": 1}}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	return true


func test_practice_best() -> bool:
	var st := _fresh()
	var r1 := st.record(1, 322, {"points": 8000, "wave": 4})
	ok(r1["new_best"] and r1["prev_best"] == null, "初めての最高")
	var r2 := st.record(1, 322, {"points": 7000, "wave": 6})
	ok(not r2["new_best"], "低い点は最高にしない(波ではなく点で比べる)")
	eq(r2["prev_best"], {"score": 8000, "wave": 4}, "前の最高")
	eq(Store.new(P).practice_best(), {"score": 8000, "wave": 4}, "読み直しても残る")
	return true


func test_daily_first_and_best() -> bool:
	var st := _fresh()
	var a := st.record(0, 322, {"points": 18450, "wave": 7})
	ok(a["first_today"], "1 回目")
	st.record(0, 322, {"points": 19900, "wave": 7})
	var d := Store.new(P).daily(322)
	eq(d["first"], {"score": 18450, "wave": 7}, "1 回目は残る")
	eq(d["best"], {"score": 19900, "wave": 7}, "最高")
	var b := st.record(0, 323, {"points": 5000, "wave": 3})
	ok(b["first_today"], "日付が変われば作り直す")
	eq(Store.new(P).daily(322)["first"], null, "前の日の記録は消える")
	return true


func test_e15_old_day_does_not_overwrite() -> bool:
	var st := _fresh()
	st.record(0, 323, {"points": 5000, "wave": 3})
	var r := st.record(0, 322, {"points": 9999, "wave": 9})
	ok(not r["first_today"] and not r["new_best"], "古い日の回は記録しない")
	eq(Store.new(P).daily(323)["best"], {"score": 5000, "wave": 3}, "新しい日のまま")
	return true


func test_settings_and_shape() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("shake", false)
	var again := Store.new(P)
	eq(again.settings(), {"volume": 25, "shake": false, "reduce_flash": false}, "設定が残る")
	st.record(1, 322, {"points": 21300, "wave": 8})
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(P))
	eq(j.data["version"], 1.0, "version 1")
	eq(j.data["practice_best"], {"score": 21300.0, "wave": 8.0}, "§9.11 の形")
	ok(FileAccess.get_file_as_string(P).length() < 2048, "2 KB 以下")
	return true


func test_bad_settings_values() -> bool:
	var st := _fresh('{"version": 1, "settings": {"volume": 33, "shake": "yes"}, "practice_best": {"score": "x"}}')
	eq(st.settings(), Store.default_settings(), "おかしな値は既定値")
	eq(st.practice_best(), null, "おかしな記録は無し")
	ok(not st.load_failed, "形は読めた")
	return true


func test_web_key() -> bool:
	eq(Store.WEB_KEY, "key-flak/save", "localStorage のキー名(INV-8)")
	return true
