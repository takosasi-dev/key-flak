// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を見比べる用)。Chrome 1 回の起動で、画面ごとに窓の大きさだけ替えて撮る。
//     node tests/web/look.mjs before     → build/web_shots/before/<画面>_<幅>x<高さ>.png
//     node tests/web/look.mjs after [--docs]   --docs で README のタイトルと結果(ふつうの 1 回目)を docs/ に写す
// スマホ(390×844)は「記録だけ」(落ちない・字が読める、を見る)。最後に S0 までの時間とコンソールのエラーの件数を出す。
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, ROOT, serve, sleep } from './lib.mjs';
import { KEYS, playUntil } from './play.mjs';

const PHASE = process.argv[2] || 'after';
const DIR = path.join(OUT, PHASE);
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]];
const BASE = { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false };
const site = serve();
const page = await open(site.url + '?debug=1', BASE);

async function shootAll(name, settle = 250) {
	for (const [w, h] of SIZES) {
		await page.resize({ width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(settle);
		const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(data, 'base64'));
	}
	await page.resize(BASE);
	await sleep(150);
}

try {
	const s0 = await page.waitState((s) => s.screen === 'gate', 60000);
	console.log(`S0 まで ${s0 ? Date.now() - page.t0 : '出ない'} ms・版 ${s0?.version}`);
	await sleep(600);
	await shootAll('s0');
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await page.shot(`${PHASE}/s1_wipe_mid_1280x720`); // 切り替わりの途中(掃く線)
	await sleep(900);
	await shootAll('s1_title_first', 400);
	// 設定 → キーの確かめ
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(600);
	await shootAll('s4_settings');
	for (let k = 0; k < 3; k++) await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.keys_view);
	for (const k of ['a', 'f', 'j', ';']) await page.keyDown(k);
	await sleep(300);
	await shootAll('s4_keys');
	for (const k of ['a', 'f', 'j', ';']) await page.keyUp(k);
	await page.key('Escape');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	await sleep(500);
	// 今日の空(1 回目): 始め → 守りながら波 2 の途中 → 一時停止 → 何もせずに終わる
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play' && s.play);
	await sleep(700);
	await shootAll('s2_start', 150);
	let shotPlay = false;
	await playUntil(page, (s) => s.screen === 'play' && s.play.wave >= 2 && s.play.missiles.length >= 3 && !s.play.intermission, {
		timeoutMs: 120000,
		onState: async (s, bot) => {
			if (!shotPlay && s.play && s.play.wave === 1 && bot.aims.size >= 1 && s.play.kills >= 1) {
				const a = await page.waitState((t) => t.play && t.play.launchers.some((l) => l[2] > 0 && l[2] < 420), 1500);
				if (a) { shotPlay = true; await shootAll('s2_play', 60); }
			}
		},
	});
	if (!shotPlay) await shootAll('s2_play', 60);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await sleep(500);
	await shootAll('s5_pause');
	await page.key('Escape');
	await page.waitState((s) => !s.paused, 3000);
	// 落ちる先の印が見える場面(着弾 1 秒前)
	// 落ちる先の印が見える場面(着弾 1 秒前)。印が出た瞬間に 1280×720 を 1 枚、続けてほかの大きさ
	const mark = await page.waitState((s) => s.play && ((s.play.marks ?? 0) > 0 || s.play.missiles.some((m) => m[1] > 560)), 60000);
	if (mark) {
		await page.shot(`${PHASE}/s2_mark_now`);
		await shootAll('s2_mark', 40);
	}
	await page.waitState((s) => s.screen === 'result', 300000);
	await sleep(1500);
	await shootAll('s3_result', 300);
	// 2 回目: 守って最高を超える
	await page.key('r');
	await page.waitState((s) => s.screen === 'play', 3000);
	await playUntil(page, (s) => s.screen === 'result', { timeoutMs: 420000, guard: (s) => s.play.wave <= 3 });
	await sleep(1500);
	await shootAll('s3_result_best', 300);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(900);
	await shootAll('s1_title_record', 400);
	// 点滅を弱める 入: 設定で入れて、練習で落ちる先の印を撮る(脈打たない・隠れない)
	if (PHASE !== 'before') {
		await page.key('ArrowDown');
		await page.key('ArrowDown');
		await page.key('Enter');
		await page.waitState((s) => s.screen === 'settings');
		await page.key('ArrowDown');
		await page.key('ArrowDown');
		await page.key('Enter');
		await sleep(200);
		await page.key('Escape');
		await page.waitState((s) => s.screen === 'title' && s.still, 3000);
		await sleep(300);
		await page.shot(`${PHASE}/s1_title_still_1280x720`);
		await page.key('ArrowDown');
		await page.key('Enter');
		await page.waitState((s) => s.screen === 'play' && s.play);
		const m2 = await page.waitState((s) => s.play && s.play.marks > 0, 60000);
		console.log(`点滅を弱める 入で印 ${m2 ? m2.play.marks : '出ない'}`);
		await page.shot(`${PHASE}/s2_mark_still_1280x720`);
	}
	if (process.argv.includes('--docs')) {
		for (const [from, to] of [['s1_title_record', 'title'], ['s3_result', 'result']]) copyFileSync(path.join(DIR, `${from}_1280x720.png`), path.join(ROOT, 'docs', `${to}.png`));
	}
	const errs = page.errors();
	console.log(`コンソールのエラー ${errs.length} 件`);
	for (const e of errs) console.log('  ' + e.text);
	// 読み込み中の画面(index.wasm を止めて、Godot が立ち上がる前の画面のまま撮る)
	await page.cdp.send('Network.setBlockedURLs', { urls: ['*index.wasm*'] });
	await page.cdp.send('Page.navigate', { url: page.url0.split('?')[0] });
	await sleep(2500);
	await shootAll('loading', 200);
	await page.cdp.send('Network.setBlockedURLs', { urls: [] });
} finally {
	await page.close();
	site.stop();
}
