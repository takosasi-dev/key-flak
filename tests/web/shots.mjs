// 全部の画面を撮る(build/web_shots/)。--docs を付けると README 用の 3 枚(照準が昇る・落とした瞬間・結果)を docs/ に写す。
//     node tests/web/shots.mjs [--docs]
//     KF_URL=https://…/key-flak/ node tests/web/shots.mjs   公開した物を撮る
// S0 → タイトル → 設定 → キーの確かめ(10 キー同時)→ 今日の空(照準が昇る・当たる瞬間・連鎖・着弾・波の間・新しい種類)→ 一時停止 → 結果 の順。
import { copyFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { OUT, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';
import { KEYS, playUntil } from './play.mjs';

const site = serve();
const page = await open(site.url + '?debug=1');
const docs = process.argv.includes('--docs');
try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	expect(!!(await page.waitState((s) => s.screen === 'gate', 30000)), 'S0 が出る');
	await sleep(300);
	await page.shot('s0');
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(300);
	await page.shot('s1_title');
	// 設定 → キーの確かめ(10 キーを同時に押さえる)
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(200);
	await page.shot('s4_settings');
	for (let k = 0; k < 3; k++) await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.keys_view);
	for (const k of KEYS) await page.keyDown(k);
	const kh = await page.waitState((s) => (s.keys_held || []).length === 10, 3000);
	expect(!!kh, `キーの確かめで 10 キーが同時に光る(${(await page.state()).keys_held?.length})`);
	await sleep(150);
	await page.shot('s4_keys');
	for (const k of KEYS) await page.keyUp(k);
	await page.key('Escape');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	// 今日の空
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'play' && s.play)), '今日の空でプレイへ');
	await sleep(400);
	await page.shot('s2_start');
	// 照準が昇る: 1 本目(F の真上)を押さえたまま撮る
	await page.waitState((s) => s.play.missiles.length > 0, 20000);
	await sleep(600);
	await page.shot('s2_hint');
	await page.waitState((s) => s.play.missiles[0][1] > 200, 20000);
	await page.keyDown('f');
	for (let k = 0; k < 5; k++) { await sleep(110); await page.shot(`s2_aim_${k}`); }
	await page.waitState((s) => { const m = s.play.missiles[0]; return !m || s.play.launchers[3][2] <= m[1] + 4; }, 5000);
	await page.keyUp('f');
	for (let k = 0; k < 8; k++) await page.shot(`s2_hit_${k}`);
	const taken = new Set();
	const once = async (label, delay = 0) => { if (taken.has(label)) return; taken.add(label); if (delay) await sleep(delay); await page.shot(label); };
	let towns = 6;
	let paused = false;
	let lastWave = 1;
	const res = await playUntil(page, (s) => s.screen === 'result', {
		timeoutMs: 420000,
		guard: (s) => s.play.wave <= 5,
		onState: async (s, bot) => {
			if (s.screen !== 'play' || !s.play) return;
			const p = s.play;
			if (p.chain >= 2) await once('s2_chain2', 60);
			if (p.chain >= 3) await once('s2_chain', 60);
			if (p.towns < towns) { await once('s2_impact'); await once('s2_crumble', 250); }
			towns = p.towns;
			if (p.launchers.some((l) => l[1]) && p.missiles.length >= 2) await once('s2_disabled');
			if (p.launchers.some((l) => l[0] === 0)) await once('s2_empty');
			if (p.intermission) { await once('s2_clear_0', 200); await once('s2_clear_1', 900); }
			if (p.wave !== lastWave) { lastWave = p.wave; await once(`s2_wave${p.wave}_banner`, 150); }
			if (p.wave === 2 && p.missiles.length >= 3) await once('s2_wave2');
			if (p.wave === 3 && p.missiles.some((m) => m[5] === 2)) await once('s2_wave3_split');
			if (p.wave === 4 && p.missiles.some((m) => m[5] === 3)) await once('s2_wave4_fast');
			if (p.wave === 5 && p.bombers > 0) await once('s2_wave5_bomber');
			if (bot.aims.size >= 2) await once('s2_two_aims');
			if (p.wave >= 6 && p.missiles.length >= 8) await once('s2_late');
			if (!paused && p.wave === 2 && p.missiles.length >= 2) {
				paused = true;
				for (const c of bot.aims.keys()) await page.keyUp(KEYS[c]);
				bot.aims.clear();
				await page.key('Escape');
				await page.waitState((t) => t.paused, 3000);
				await sleep(200);
				await page.shot('s5_pause');
				await page.key('ArrowDown');
				await page.key('ArrowDown');
				await page.key('Enter');
				await page.waitState((t) => t.screen === 'settings', 3000);
				await sleep(200);
				await page.shot('s4_from_pause');
				await page.key('Escape');
				await page.waitState((t) => t.screen === 'play', 3000);
				await page.key('Escape');
				await page.waitState((t) => !t.paused, 3000);
			}
		},
	});
	expect(!!res, `結果まで行く(撮った: ${[...taken].join(' ')})`);
	await sleep(250);
	await page.shot('s3_result_count');
	await sleep(900);
	await page.shot('s3_result');
	console.log('    結果: ' + JSON.stringify((await page.state())));
	console.log('    1 フレーム・離してから描くまで(ms): ' + JSON.stringify(await page.stats()));
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
	if (docs) {
		mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
		const hit = taken.has('s2_chain') ? 's2_chain' : taken.has('s2_chain2') ? 's2_chain2' : 's2_hit_2';
		for (const [from, to] of [['s2_aim_3', 'aim'], [hit, 'hit'], ['s3_result', 'result']]) copyFileSync(path.join(OUT, `${from}.png`), path.join(ROOT, 'docs', `${to}.png`));
	}
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
