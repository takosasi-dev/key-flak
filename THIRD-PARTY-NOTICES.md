# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。効果音は `tools/gen_sfx.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## Big Shoulders Stencil(題字と数字、v0.3.0 から)

- ファイル: `assets/fonts/BigShouldersStencil-Subset.ttf`(原本の太さを 800・字の大きさの軸を 72 に固定し、ASCII の 95 字に絞った物。数字の 0 だけ、上下の割れ目に四角を足して閉じてある。`tools/subset_font.py` で作る。原本に Reserved Font Name は無い)
- 原本: https://github.com/google/fonts/tree/main/ofl/bigshouldersstencil の `BigShouldersStencil[opsz,wght].ttf`(コミット `c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1`)
- 原本の SHA-256: `758ec880296a8bdaf736a31fc57e90fa16673d8c357efc3c36bdb6582d625f0a`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_BigShouldersStencil.txt`](assets/fonts/OFL_BigShouldersStencil.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2019 The Big Shoulders Project Authors (https://github.com/xotypeco/big_shoulders)

## 効果音

- ファイル: `assets/sfx/*.wav`(11 個)
- 出どころ: `tools/gen_sfx.py` で合成した自作の音。第三者の素材は使っていない。ライセンスはリポジトリと同じ MIT。
