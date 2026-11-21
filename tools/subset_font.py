"""同梱する字体を、画面に出す文字だけに絞る(RootCall の tools/subset_font.py の作り)。

- Noto Sans JP(画面の字。SlingArc と同じ): core/strings.gd の文字列リテラルの全文字と、ASCII の印字できる文字、画面で使う記号。太さの軸は残す
- Big Shoulders Stencil(v0.3.0、題字・数字用): ASCII だけ。太さ 800・字の大きさの軸 72 に固定した 1 つの太さにして軽くする。
  0 だけは上下の割れ目に橋を足して閉じる(割れた 0 は小さいと「()」に見える。bridge_zero)
原本は google/fonts の固定コミットから取り、sha256 を照らす。tools/font_src/ に置き、git には入れない。文言を足したら回し直す。

    pip install fonttools
    python tools/subset_font.py
"""

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[1]
GF = "https://raw.githubusercontent.com/google/fonts/"
# (原本の名前, URL, sha256, 書き出す名前, 日本語の文言も入れるか, 固定する軸)
FONTS = [
    ("NotoSansJP.ttf", GF + "295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf",
     "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f", "NotoSansJP-Subset.ttf", True, None),
    ("BigShouldersStencil.ttf", GF + "c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1/ofl/bigshouldersstencil/BigShouldersStencil%5Bopsz,wght%5D.ttf",
     "758ec880296a8bdaf736a31fc57e90fa16673d8c357efc3c36bdb6582d625f0a", "BigShouldersStencil-Subset.ttf", False, {"wght": 800, "opsz": 72}),
]
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
EXTRA = "−×"  # ui が数字に添える記号


def strings_chars() -> set[str]:
    text = (ROOT / "core" / "strings.gd").read_text(encoding="utf-8")
    return set("".join(re.findall(r'"((?:[^"\\\n]|\\.)*)"', text)))


def bridge_zero(font: TTFont) -> None:
    """型紙の 0(左右 2 つの輪郭)の上下の割れ目に、同じ向き(時計回り)の四角を重ねて閉じる。
    割れ目の位置は左の輪郭の右端と右の輪郭の左端、高さは内側の縁から外側の縁まで(固定した 800/72 の形から読む)。"""
    glyf = font["glyf"]
    g = glyf["zero"]
    coords, ends, _flags = g.getCoordinates(glyf)
    if g.numberOfContours != 2:
        sys.exit(f"0 の輪郭が {g.numberOfContours} 個(2 個のはず)。原本が変わった")
    left = coords[: ends[0] + 1]
    right = coords[ends[0] + 1 :]
    gx0 = max(x for x, _ in left) - 6
    gx1 = min(x for x, _ in right) + 6
    ys = sorted({y for x, y in left if x >= gx0})  # 割れ目に面した縁の高さ(下の外・下の内・上の内・上の外)
    lo_out, lo_in, hi_in, hi_out = ys[0], ys[1], ys[-2], ys[-1]
    pen = TTGlyphPen(font.getGlyphSet())
    font.getGlyphSet()["zero"].draw(pen)
    for y0, y1 in ((lo_out, lo_in), (hi_in, hi_out)):
        pen.moveTo((gx0, y0))
        pen.lineTo((gx0, y1))
        pen.lineTo((gx1, y1))
        pen.lineTo((gx1, y0))
        pen.closePath()
    glyf["zero"] = pen.glyph()
    glyf["zero"].recalcBounds(glyf)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    all_chars = set(ASCII) | set(EXTRA) | strings_chars()
    for src_name, url, sha, out_name, japanese, pin in FONTS:
        chars = all_chars if japanese else set(ASCII)
        src = ROOT / "tools" / "font_src" / src_name
        out = ROOT / "assets" / "fonts" / out_name
        if not src.exists():
            src.parent.mkdir(parents=True, exist_ok=True)
            print(f"取得: {url}")
            urllib.request.urlretrieve(url, src)
        digest = hashlib.sha256(src.read_bytes()).hexdigest()
        if digest != sha:
            sys.exit(f"{src} の sha256 が違う: {digest}(消して取り直す)")
        font = TTFont(src)
        if pin:
            font = instancer.instantiateVariableFont(font, pin)
        options = subset.Options()
        options.layout_features = ["*"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=[ord(c) for c in chars])
        subsetter.subset(font)
        if not japanese:
            bridge_zero(font)
        out.parent.mkdir(parents=True, exist_ok=True)
        font.save(out)
        missing = sorted(c for c in chars if ord(c) not in font.getBestCmap())
        print(f"{out.name}: {src.stat().st_size:,} -> {out.stat().st_size:,} バイト、{len(chars)} 文字")
        if missing:
            print(f"  原本に無い文字: {''.join(missing)}")


if __name__ == "__main__":
    main()
