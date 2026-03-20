# VoiceNote-FPGA

VoiceNoteのFPGA(PL) 開発用リポジトリです。\
詳細仕様は [FPGA設計書.md](doc/FPGA設計書.md) を参照してください。

> [!WARNING]
> あくまで個人開発なので全てがうまく動作する保証はないです。\
> 検証をまじめにやっていないためパラメータを変えたら動かない可能性もあります。

## フォルダ構成

```text
.
├── README.md                             # このリポジトリの入口ドキュメント
├── design/                               # Vivadoプロジェクト関連
│   ├── VoiceNote.tcl                     # プロジェクト再生成用Tcl
│   └── VoiceNote/                        # 生成済みVivadoプロジェクト
│       └── VoiceNote.xdc                 # 制約ファイル
├── doc/                                  # 設計ドキュメント
│   ├── FPGA設計書.md                      # FPGA仕様書（メイン）
│   ├── design_1.pdf                      # BD/設計資料PDF
│   └── img/                              # 設計書で参照する図
├── src/                                  # 実装ソース一式
│   ├── myip/                             # 自作RTL IP
│   │   ├── agc_1_0/                      # AGC IP
│   │   ├── arec_1_0/                     # AREC IP
│   │   └── i2s_clock_mux_1_0/            # I2Sクロック切替IP
│   └── hls/
│       └── audio_clean_up/               # HLS生成IP（ACU）
└── verification/                         # 検証環境一式
    ├── common/                           # recording/playback共通資産
    │   ├── csv_pkg.sv                    # CSV I/O共通SVパッケージ
    │   └── dpi_c/                        # DPI-C実装
    ├── recording/                        # 録音系(AREC)検証
    │   ├── arec/
    │   │   ├── tb/                       # テストベンチ本体
    │   │   │   └── scenarios/            # シナリオ定義
    │   │   ├── input/                    # 入力CSV
    │   │   ├── output/                   # 実行結果CSV（使用していない）
    │   │   └── golden/                   # 期待値CSV（使用していない）
    │   ├── acu/                          # ACU関連検証（使用していない）
    │   ├── scripts/                      # 実行補助Tcl
    │   └── utility/                      # レジスタ操作などの補助SV
    └── playback/                         # 再生系(AGC)検証
        └── (recordingと同構成)            # agc/, scripts/, tools/, utility/ を配置
```

## プロジェクト作成

`design/VoiceNote.tcl` からVivadoプロジェクトを生成できます。

※このtcl動かしたことがないのでもしかすると作れないかも、、、その場合はパス周りを疑えばいいかも。

### 1. バッチ実行で作成する場合

```bash
cd design
vivado -mode batch -source VoiceNote.tcl
```

生成後のプロジェクト:

- `design/VoiceNote/VoiceNote.xpr`

### 2. Vivado Tcl Console から作成する場合

```tcl
cd design
source VoiceNote.tcl
```

## テスト実行

本リポジトリには主に以下の2系統のシミュレーションがあります。

- `recording` 系: AREC
- `playback` 系: AGC

どちらもVivadoでプロジェクトを開いた状態で、Tcl Consoleから実行します。\
csvファイルが色々入っていますが、使っているのは `input` のみです。他は残骸です。

### Recording (AREC)

```tcl
source verification/recording/scripts/set_arec_env.tcl
arec_run_id 1
```

### Playback (AGC)

```tcl
source verification/playback/scripts/set_playback_env.tcl
playback_run_id 1
```

## Push / PR ルール

GitHub Actionsを利用しているため、`main` へは直接pushせず、作業ブランチ経由でPull Requestを作成してください。

### 基本ルール

1. `main` から作業ブランチを作成する
2. 作業ブランチに commit / push する
3. Pull Request を作成する
4. GitHub Actions が成功してからレビュー・マージする
5. `main` への直接 push は行わない

### 推奨手順

```bash
# main を最新化
git checkout main
git pull origin main

# 作業ブランチ作成
git checkout -b dev-tmp

# 変更をコミット
git add .
git commit -m "chore: add push and PR workflow"

# リモートへ push
git push -u origin dev-tmp
```
