// ブラウザの中で守る bot(本物のキーを押さえて離す)。window.kfState のミサイルの位置と速さから、
// 照準が昇りきる時刻にミサイルが列の上に来る組を探して押し、照準の高さ(aim_y)が狙いに届いたら離す。
// 状態の窓口は読むだけで、判定は core のまま(当たりの計算はしない。狙いの目安だけ)。
import { sleep } from './lib.mjs';

export const KEYS = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';'];
const MARK_Y0 = 620;
const PER_TICK = 400 / 120; // 照準が 1 tick に昇る px(balance.gd の MARK_SPEED)
const NEAR_X = 30; // 列の中心からこれ以内なら狙える(爆発の半径 52 より小さく取る)
const LEAD = 6; // 状態を読んでから押すまでの遅れの見込み(tick)
const colX = (c) => 64 + 128 * c;

// 1 台ぶんの bot。aims は今押さえている列 → { id, y }
export function makeBot() {
	return { aims: new Map(), done: new Set(), presses: 0 };
}

// 押す・離すを決めて送る。p は kfState.play
export async function defend(page, bot, p) {
	const ls = p.launchers;
	// 離す: 照準が狙いの高さに届いた・狙いが消えた
	for (const [c, a] of [...bot.aims]) {
		const ay = ls[c][2];
		const alive = p.missiles.some((m) => m[6] === a.id);
		if (ay < 0 || ay <= a.y + 2 || !alive) {
			await page.keyUp(KEYS[c]);
			bot.aims.delete(c);
		}
	}
	// 押す: まだ狙っていないミサイルについて、昇りきる時刻と列の上に来る時刻が合う所を探す
	for (const m of p.missiles) {
		const [x, y, vx, vy, , , id] = m;
		if (bot.done.has(id)) continue;
		for (let t = 0; t < 400; t++) {
			const px = x + vx * t, py = y + vy * t;
			if (py > 600) break;
			const c = Math.max(0, Math.min(9, Math.round((px - 64) / 128)));
			if (Math.abs(px - colX(c)) > NEAR_X) continue;
			const h = (MARK_Y0 - py) / PER_TICK;
			if (h < t - LEAD || h > t + LEAD) continue;
			if (bot.aims.has(c) || ls[c][0] <= 0 || ls[c][1] || ls[c][2] >= 0) continue;
			await page.keyDown(KEYS[c]);
			bot.aims.set(c, { id, y: py });
			bot.done.add(id);
			bot.presses++;
			break;
		}
	}
}

// 押さえている物を全部離す
export async function releaseAll(page, bot) {
	for (const c of bot.aims.keys()) await page.keyUp(KEYS[c]);
	bot.aims.clear();
}

// pred(state) が真になるまで遊ぶ。guard(state) が偽の間は守らない(負けるため)。onState は毎回呼ぶ
export async function playUntil(page, pred, { timeoutMs = 120000, guard = () => true, onState = async () => {} } = {}) {
	const bot = makeBot();
	const end = Date.now() + timeoutMs;
	while (Date.now() < end) {
		const s = await page.state();
		if (pred(s)) { await releaseAll(page, bot); return s; }
		await onState(s, bot);
		if (s.screen === 'play' && s.play && !s.paused) {
			if (guard(s)) await defend(page, bot, s.play);
			else await releaseAll(page, bot);
		}
		await sleep(15);
	}
	await releaseAll(page, bot);
	return null;
}
