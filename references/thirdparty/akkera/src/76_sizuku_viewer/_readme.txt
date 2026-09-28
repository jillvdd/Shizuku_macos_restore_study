
　「雫　viewer」勝手にGBA移植
　　インストール手順書


■ ご案内

　　ダウンロードして頂いてありがとうございます。
　　「雫」GBAの移植の足がかりにviewerを作ってみました。




■ 実行データの作成

　　viewerを起動する為にはWindows98/95版の「雫」のゲームデータが必要です。
　　下記のファイルを用意してください。このファイル以外は
　　テストしていないので、たぶん動かないと思います（汗。

　　名前　　　：　MAX_DATA.PAK
　　容量　　　：　5,757,223 バイト
　　更新日時　：　1996年6月28日 0:00:00



　１．「MAX_DATA.PAK」を「gbfs_data\data」フォルダにコピーをします。


　２．下記のプログラムをダウンロードをしてきて「gbfs_data\data」フォルダに
　　　コピーをします。

　　　※１　leafpak.exe  http://hoshina.denpa.org/leafpak.html
　　　　　　LFGBMP.EXE   http://www.vector.co.jp/soft/dos/art/se049761.html

　　　※１　環境によっては「cygwin1.dll」が必要です。一度テストしてみることをお勧めします


　３．画像の縮小には「ImageMagick」を利用しています。下記のサイトより
　　　インストールをして、convert.exeのパスが通るようにしてください。

　　　「ImageMagick 6.3.4 Q16」
　　　　http://www.imagemagick.org/


　４．「gbfs_data」フォルダの中にある「_make_gbfs.bat」を実行します。
　　　「test.gbfs」が作成されます。


　５．「make_view.bat」を実行してください。成功すると
　　　「kviewer.gba」が作成されます。


　※画像ファイルはABC順に並んでいるので、始めのファイルはH・・・（！）から始まります。
　　起動をする前は座席の後ろや、周りを気にしてから実行してください（爆。
　　～～～～～～
　　↑↑↑↑↑↑




■　謝辞

　「雫　viewer」製作にあたって、間接的ではありますが
　ゲームデータの分割、加工をさせて頂いています。

　TF 様
　　Leafpak (～.PAK 用ファイルカッター)
　　http://hoshina.denpa.org/leafpak.html

　darappi 様
　　Leaf マルチ画像コンバータ
　　http://www.vector.co.jp/soft/dos/art/se049761.html




■　著作権について

　・「雫」は株式会社アクアプラスの著作物です。
　・データの二次配布を禁止します（ゲームデータの結合前のデータも含みます）。
　・利用は個人で使用する範囲に留めてください。

　　二次創作・素材使用については下記の内容に沿って製作をしています。
　　　http://www.aquaplus.co.jp/copyrgt.html


