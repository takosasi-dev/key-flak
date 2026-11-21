// 起動までの秒数(ページを開いてから S0 の状態が出るまで)と、キーを押してから遊びの画面を描くまでの時間を測る。
// 毎回、使い捨てのプロフィールで Chrome を立ち上げ直す。最後の 1 回で、タイトルの Enter → 遊び と、結果の R(もう1回)→ 遊び を測る。
//     node tests/web/boot.mjs 3
//     KF_URL=https://…/key-flak/ node tests/web/boot.mjs 3
import { open, serve, sleep } from './lib.mjs';

const N = Number(process.argv[2] || 3);
const site = serve();
const times = [];

// 押す直前の時刻をページの中で取り、kfState の画面が play になったフレームまでを測る(kfState は描いた後に更新される)
async function keyToPlay(page, key) {
	await page.evaluate(`window.__kfT = null; (function loop() { let s = {}; try { s = JSON.parse(window.kfState || '{}'); } catch {}
		if (s.screen === 'play') { window.__kfT = performance.now() - window.__kfT0; return; } requestAnimationFrame(loop); })(); window.__kfT0 = performance.now(); 0`);
	await page.key(key);
	await page.waitState((s) => s.screen === 'play', 5000);
	await sleep(100);
	return Math.round(await page.evaluate('window.__kfT'));
}

try {
	for (let i = 0; i < N; i++) {
		const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
		try {
			const s = await page.waitState((st) => st.screen === 'gate', 60000);
			times.push(s ? Date.now() - page.t0 : NaN);
			console.log(`${i + 1} 回目: S0 まで ${times.at(-1)} ms・エラー ${page.errors().length} 件・版 ${s?.version}`);
			if (i === N - 1) {
				await page.key('x');
				await page.waitState((st) => st.screen === 'title');
				await sleep(800);
				console.log(`タイトルの Enter → 遊びを描くまで ${await keyToPlay(page, 'Enter')} ms`);
				await page.waitState((st) => st.screen === 'result', 400000);
				await sleep(800);
				console.log(`結果の R(もう1回)→ 遊びを描くまで ${await keyToPlay(page, 'r')} ms`);
				console.log(`コンソールのエラー ${page.errors().length} 件`);
			}
		} finally {
			await page.close();
		}
	}
} finally {
	site.stop();
}
console.log(`S0 まで(ms): ${times.join(' / ')}`);
