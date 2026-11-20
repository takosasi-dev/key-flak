// Web 版の流れをまとめて確かめる(Chrome 1 回の起動で済ませる)。
//   起動の時間・キーボードだけで S0 → S1 → S2 → S3 → もう1回(AC-20)・本物のキーを押さえて離すと爆発・3 キー同時・
//   タブが裏で一時停止(E-11)・保存が key-flak/save に入り ParryDuel の保存を消さない・コピー(FR-20)・
//   読み込みの後の通信 0 件(AC-23。3 分以上見る)・コンソールのエラー 0 件
//     node tests/web/check.mjs            手元の build/web を配って確かめる(4〜5 分)
//     node tests/web/check.mjs --quick    起動・タイトル・最初の 1 本まで(公開 URL の確かめに使う)
//     KF_URL=https://…/key-flak/ node tests/web/check.mjs
import { expect, failureCount, open, serve, sleep } from './lib.mjs';
import { playUntil } from './play.mjs';

const quick = process.argv.includes('--quick');
const WATCH_MS = 185000; // AC-23: 読み込みの後、3 分間の通信を見る
const site = serve();
const page = await open(site.url + '?debug=1');
try {
	expect(page.booted, `Godot が起動した(${page.bootMs} ms)`);
	const s0 = await page.waitState((s) => s.screen === 'gate', 60000);
	expect(!!s0, `S0 が出る(ページを開いてから ${Date.now() - page.t0} ms)`);
	console.log(`    版: ${s0?.version}`);
	const loadedAt = Date.now();
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'キーで S1');
	await page.key('Enter');
	const p0 = await page.waitState((s) => s.screen === 'play' && s.play);
	expect(!!p0 && p0.play.wave === 1, 'Enter で今日の空(S2)');
	// 1 本目(F の真上)を、本物のキーを押さえて離して落とす
	await page.waitState((s) => s.play.missiles.length > 0 && s.play.missiles[0][1] > 180, 20000);
	await page.keyDown('f');
	const up = await page.waitState((s) => s.play.launchers[3][2] > 0 && s.play.launchers[3][2] < 500, 3000);
	expect(!!up, `F を押さえている間は照準が昇る(y ${up?.play?.launchers[3][2]})`);
	await page.waitState((s) => { const m = s.play.missiles[0]; return !m || s.play.launchers[3][2] <= m[1] + 4; }, 5000);
	await page.keyUp('f');
	const hit = await page.waitState((s) => s.play.kills >= 1, 3000);
	expect(!!hit && hit.play.launchers[3][0] === 2, `離すと爆発して 1 本目を落とす(落とした数 ${hit?.play?.kills}・F の弾 ${hit?.play?.launchers[3][0]})`);
	expect(hit?.sfx > 0, `効果音を鳴らした数 ${hit?.sfx}(消音の Chrome なので耳では聞いていない)`);
	if (!quick) {
		// 3 キーを同時に押さえて別々に離す
		await page.keyDown('a');
		await page.keyDown('s');
		await page.keyDown('d');
		const three = await page.waitState((s) => s.play.held.length === 3 && [0, 1, 2].every((i) => s.play.launchers[i][2] > 0), 2000);
		expect(!!three, '3 キーを同時に押さえると照準が 3 本');
		await page.keyUp('s');
		const one = await page.waitState((s) => s.play.launchers[1][2] < 0 && s.play.launchers[0][2] > 0, 2000);
		expect(!!one, 'S だけ離すと S だけ爆発し、A と D は昇り続ける');
		await page.keyUp('a');
		await page.keyUp('d');
		// タブが裏に回ると一時停止。戻っても自動では再開しない
		await page.hide();
		await sleep(800);
		await page.show();
		expect(!!(await page.waitState((s) => s.paused, 5000)), 'タブが裏で一時停止');
		const tk = (await page.state()).play.tick;
		await sleep(1000);
		expect((await page.state()).play.tick === tk, `戻っても止まったまま(tick ${tk})`);
		await page.key('Escape');
		expect(!!(await page.waitState((s) => !s.paused, 3000)), 'Esc で続ける');
		// 何もせずに町を全部失って S3 へ
		const res = await playUntil(page, (s) => s.screen === 'result', { timeoutMs: 240000, guard: () => false });
		expect(!!res, '町が 0 になって S3');
		await sleep(800);
		const saved = await page.saved();
		expect(saved?.version === 1 && saved?.daily?.first != null, `保存が key-flak/save に入る: ${JSON.stringify(saved).slice(0, 120)}`);
		expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない');
		// コピー: ボタンと、枠を選んで Ctrl+C
		await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
		expect(await page.clickButton('copy'), 'コピーのボタンを押せる');
		await sleep(500);
		const c1 = await page.clipboard();
		expect(c1.startsWith('KeyFlak '), `コピーのボタン: ${JSON.stringify(c1).slice(0, 90)}`);
		await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
		await page.click(...(await page.gameCss(500, 450))); // 共有の枠(y 398〜516)
		await sleep(200);
		await page.keyMod('a', 2);
		await page.keyMod('c', 2);
		await sleep(500);
		const c2 = await page.clipboard();
		expect(c2.startsWith('KeyFlak '), `枠を選んで Ctrl+C: ${JSON.stringify(c2).slice(0, 90)}`);
		expect((await page.state()).screen === 'result', 'Ctrl 付きのキーでは画面が変わらない');
		await page.key('Escape');
		await sleep(300);
		await page.key('r');
		const again = await page.waitState((s) => s.screen === 'play', 3000);
		expect(!!again && again.play.tick < 120, 'R でもう1回(同じ今日の空)');
		// 3 分たつまで遊び続けて通信を見る
		const left = WATCH_MS - (Date.now() - loadedAt);
		if (left > 0) await playUntil(page, () => false, { timeoutMs: left });
		const after = page.requests.filter((r) => r.at > loadedAt);
		expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
		console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
	}
	console.log('    1 フレーム・離してから描くまで(ms): ' + JSON.stringify(await page.stats()));
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
process.exit(failureCount() ? 1 : 0);
