"""効果音 11 個(v0.3.0 でメニューの決定を足した)(仕様書 §9.9)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ。
雑音は決まった式の擬似乱数で作る(何度回しても同じバイト列)。16bit PCM・モノラル・22050 Hz。合計 400 KB 以下(NFR-7)。
作りは RootCall の tools/gen_sfx.py。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def _pad(buf, n):
    while len(buf) < n:
        buf.append(0.0)


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False, attack=0.001):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    _pad(buf, start + n)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (attack * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def noise(buf, at, dur, gain=1.0, decay=0.0, smooth=0.0):
    """雑音を buf に足す(線形合同法。smooth が大きいほど低い音)。"""
    start = int(at * RATE)
    n = int(dur * RATE)
    _pad(buf, start + n)
    x = 12345
    prev = 0.0
    for i in range(n):
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        v = x / 0x3FFFFFFF - 1.0
        prev = prev * smooth + v * (1.0 - smooth)
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE))
        buf[start + i] += e * prev


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    tone(b, 0, 1.4, 110, 260, square=True, attack=0.02)  # 充填: 押している間、低く昇る(頂上までの 1.35 秒)
    write("aim", b, 0.22)
    b = []
    noise(b, 0, 0.35, decay=9, smooth=0.6)
    tone(b, 0, 0.2, 180, 70, gain=0.8, decay=14)  # 破裂
    write("burst", b, 0.6)
    b = []
    tone(b, 0, 0.14, 880, 1040, decay=18)  # 撃墜: 高い音(連鎖で半音ずつ上げる)
    write("kill", b, 0.45)
    b = []
    tone(b, 0, 0.04, 2600, 2000, decay=60)  # 弾切れ: 空のカチッ
    write("empty", b, 0.35)
    b = []
    tone(b, 0, 0.16, 120, 100, square=True, decay=12)  # 止まった発射台: 鈍い音
    write("disabled", b, 0.45)
    b = []
    noise(b, 0, 0.7, decay=5, smooth=0.9)
    tone(b, 0, 0.5, 70, 40, gain=0.9, decay=6)  # 着弾: 重い爆音
    write("impact", b, 0.8)
    b = []
    for k, f in enumerate([523, 659, 784]):
        tone(b, k * 0.1, 0.3, f, decay=7)  # 波をしのいだ: 明るい音
    write("wave_clear", b, 0.55)
    b = []
    tone(b, 0, 0.12, 740, square=True, decay=6)
    tone(b, 0.16, 0.12, 740, square=True, decay=6)  # 波の始め: 短い警報
    write("wave_start", b, 0.45)
    b = []
    for k, f in enumerate([392, 330, 262, 196]):
        tone(b, k * 0.16, 0.4, f, decay=5)  # 終わり: 下がる 4 音
    write("over", b, 0.6)
    b = []
    tone(b, 0, 0.04, 1200, 1400, decay=30)  # メニューの選択
    write("select", b, 0.35)
    b = []
    tone(b, 0, 0.05, 900, decay=25)
    tone(b, 0.05, 0.09, 1350, decay=22)  # メニューの決定(v0.3.0): 2 音で上がる
    write("confirm", b, 0.35)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
