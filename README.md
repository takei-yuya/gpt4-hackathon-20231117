# GPT4新機能ハッカソン24耐

## 全体的に

とりあえず `docker compose build` `docker compose up -d` したあと、 `docker compose exec app /bin/bash` で作業します

## oekaki_shiritori

お絵描きしりとり。
`.env` にいい感じに環境変数をセットする。
私の場合、Microsoft for StatupsプログラムでAzure OpenAI Serviceをメインに使っていたので、そちらの設定を使っているが、
VISION APIがまだAzureに来ていない + GPT-4モデルとDALL-eとが同時に使えるリージョンがなかったのではしごしてる。
本家OpenAIのエンドポイントなら全部使えるはずなので、コード先頭のクライアント作成まわりをいい感じに直してください。

実行は `oekaki_shiritori.rb` を実行。

```
ラウンド1/5: 単語を表す画像のURLを入力してください
https://... # 画像のURLを1行で入力してEnter
何文字の単語ですか？
3 # 画像の単語数を入力してEnter
画像を認識しています...
次の単語を考えています...
画像を生成しています...
https://... # AIが考えた次の単語の画像のURLが返ってくる
●●●  # 単語文字数のヒント。この場合3文字の単語
```

といった感じで、画像のURLを送ったら、画像のURLが返ってくるので、しりとりになるよう続けていきます。
5ラウンドでしりとりは終わりで、AIがなんという単語と認識したのか？や、AIが書いた絵がなんだったか？などが出力されます。
当日、発表する時の「溜め」のために、認識結果や、単語を表示するまえに、標準入力からの行入力待ちを挟んでいます。
Enterを連打してください。 (か、 244行目、250行目、253行目あたりの `readline` を消してください

## theseus

https://ja.wikipedia.org/wiki/テセウスの船 を元にした一発ネタです。
詳しくはあとで公開する note をご参照ください。

「[いらすとや](https://www.irasutoya.com/)」さんの「[豪華客船・フェリーのイラスト](https://www.irasutoya.com/2013/05/blog-post_3676.html)」を例にした実行例を `ship.gif` においています。
