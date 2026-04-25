# spec_scraping_yojijukugo_v1.md

## 1. 目的
四字熟語辞典オンライン（http://yojijukugo.jitenon.jp/）から以下を取得し、TXT形式で出力する。

- 四字熟語
- 読み（ひらがな）
- 意味
- ページURL

---

## 2. 対象範囲
### 2.1 取得対象
- 五十音別一覧ページ
- 各四字熟語の詳細ページ

### 2.2 除外
- 広告
- 外部リンク
- 重複ページ

---

## 3. 入力
なし（固定URLから開始）

開始URL：
http://yojijukugo.jitenon.jp/cat/gojuon.html

---

## 4. 出力
### 4.1 ファイル形式
- UTF-8
- 拡張子: .txt

### 4.2 出力フォーマット（1行1レコード）
