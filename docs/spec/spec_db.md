# spec_db.md — SQLite データベース設計仕様

## 1. 目的

スクレイピングで取得した四字熟語・ことわざのデータを SQLite に格納し、  
検索・参照・出力の基盤となるデータベースを構築する。

---

## 2. DB 概要

### 2.1 通常版（`data/jpword.db`）

全カラムを含む完全版。

| 項目 | 値 |
|------|-----|
| DBMS | SQLite 3 |
| ファイルパス | `data/jpword.db` |
| 文字コード | UTF-8 |
| テーブル数 | 3（`source_master` / `yojijukugo` / `kotowaza`） |

### 2.2 Mini版（`data/jpword_mini.db`）

サイズ削減版。URL・作成日時・メタ情報は除外。

| 項目 | 値 |
|------|-----|
| DBMS | SQLite 3 |
| ファイルパス | `data/jpword_mini.db` |
| 文字コード | UTF-8 |
| テーブル数 | 3（`source_master` / `yojijukugo_mini` / `kotowaza_mini`） |

---

## 3. 入力データ

| テーブル | 元ファイル | フォーマット仕様 |
|----------|-----------|-----------------|
| `source_master` | `data/yojijukugo.txt`（出典フィールド） | `src/db/extract_sources.py` で抽出 |
| `yojijukugo` | `data/yojijukugo.txt` | `spec_scraping_yojijukugo.md` 参照 |
| `kotowaza` | `data/kotowaza.txt` | `spec_scraping_kotowaza.md` 参照 |

---

## 4. テーブル定義

### 4.1 `source_master`（出典マスター）

```sql
CREATE TABLE IF NOT EXISTS source_master (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### カラム説明

| カラム名 | 型 | NULL | 説明 |
|----------|----|------|------|
| `id` | INTEGER | NOT NULL | 主キー（自動採番） |
| `name` | TEXT | NOT NULL | 書名（例：論語・史記）。一意制約あり |
| `created_at` | DATETIME | NOT NULL | レコード作成日時（UTC） |

#### 抽出ルール（`extract_sources.py` 準拠）

| 出典フィールドの形式 | 採用する書名 |
|---------------------|--------------|
| `『論語』「子路」` | `論語`（`『』`内を採用） |
| `「晏子春秋」「諫・下」` | `晏子春秋`（`『』`なし → 最初の`「」`内を採用） |
| `括弧なしの文字列` | そのまま採用 |
| カンマ区切りで複数出典 | それぞれ分割して採用 |

---

### 4.2 `yojijukugo`（四字熟語）

```sql
CREATE TABLE IF NOT EXISTS yojijukugo (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    word          TEXT    NOT NULL,
    reading       TEXT    NOT NULL,
    meaning       TEXT    NOT NULL,
    source_id     INTEGER REFERENCES source_master(id),
    source_raw    TEXT,
    kanken_level  TEXT,
    usage         TEXT,
    url           TEXT    NOT NULL UNIQUE,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### カラム説明

| カラム名 | 型 | NULL | 説明 |
|----------|----|------|------|
| `id` | INTEGER | NOT NULL | 主キー（自動採番） |
| `word` | TEXT | NOT NULL | 四字熟語（例：臥薪嘗胆） |
| `reading` | TEXT | NOT NULL | よみがな（ひらがな）|
| `meaning` | TEXT | NOT NULL | 意味の説明文。改行は `\n` で格納 |
| `source_id` | INTEGER | NULL 可 | `source_master.id` への外部キー。出典不明の場合は `NULL` |
| `source_raw` | TEXT | NULL 可 | 出典の生テキスト（例：`『史記』「越世家」`）。不明の場合は空文字 |
| `kanken_level` | TEXT | NULL 可 | 漢検級（例：`準1級`・`2級`・`4級`）。不明の場合は空文字 |
| `usage` | TEXT | NULL 可 | 場面・用途タグ。複数値は `/` 区切り（例：`機会をうかがう/我慢`） |
| `url` | TEXT | NOT NULL | スクレイピング元URL。一意制約あり |
| `created_at` | DATETIME | NOT NULL | レコード作成日時（UTC） |

---

### 4.3 `yojijukugo_mini`（四字熟語・Mini版）

サイズ最適化版。`yojijukugo` から `kanken_level` / `usage` / `url` / `created_at` を除外。

```sql
CREATE TABLE IF NOT EXISTS yojijukugo_mini (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    word       TEXT    NOT NULL,
    reading    TEXT    NOT NULL,
    meaning    TEXT    NOT NULL,
    source_id  INTEGER REFERENCES source_master(id),
    source_raw TEXT
);
```

#### カラム説明

| カラム名 | 型 | NULL | 説明 |
|----------|----|----|------|
| `id` | INTEGER | NOT NULL | 主キー（自動採番） |
| `word` | TEXT | NOT NULL | 四字熟語（例：臥薪嘗胆） |
| `reading` | TEXT | NOT NULL | よみがな（ひらがな） |
| `meaning` | TEXT | NOT NULL | 意味の説明文。改行は `\n` で格納 |
| `source_id` | INTEGER | NULL 可 | `source_master.id` への外部キー。出典不明の場合は `NULL` |
| `source_raw` | TEXT | NULL 可 | 出典の生テキスト。不明の場合は空文字 |

---

### 4.4 `kotowaza_mini`（ことわざ・Mini版）

サイズ最適化版。`kotowaza` から `variant` / `url` / `created_at` を除外。

```sql
CREATE TABLE IF NOT EXISTS kotowaza_mini (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    word     TEXT    NOT NULL,
    reading  TEXT    NOT NULL,
    meaning  TEXT    NOT NULL
);
```

#### カラム説明

| カラム名 | 型 | NULL | 説明 |
|----------|----|----|------|
| `id` | INTEGER | NOT NULL | 主キー（自動採番） |
| `word` | TEXT | NOT NULL | ことわざ（例：生き馬の目を抜く） |
| `reading` | TEXT | NOT NULL | よみがな（ひらがな） |
| `meaning` | TEXT | NOT NULL | 意味の説明文。改行は `\n` で格納 |

---

### 4.5 `kotowaza`（ことわざ）

```sql
CREATE TABLE IF NOT EXISTS kotowaza (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    word       TEXT    NOT NULL,
    reading    TEXT    NOT NULL,
    meaning    TEXT    NOT NULL,
    variant    TEXT,
    url        TEXT    NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### カラム説明

| カラム名 | 型 | NULL | 説明 |
|----------|----|------|------|
| `id` | INTEGER | NOT NULL | 主キー（自動採番） |
| `word` | TEXT | NOT NULL | ことわざ（例：生き馬の目を抜く） |
| `reading` | TEXT | NOT NULL | よみがな（ひらがな） |
| `meaning` | TEXT | NOT NULL | 意味の説明文。改行は `\n` で格納 |
| `variant` | TEXT | NULL 可 | 異形（別表記・類句）。不明の場合は空文字 |
| `url` | TEXT | NOT NULL | スクレイピング元URL。一意制約あり |
| `created_at` | DATETIME | NOT NULL | レコード作成日時（UTC） |

---

## 5. インデックス定義

### 5.1 通常版インデックス

```sql
-- source_master
CREATE INDEX IF NOT EXISTS idx_source_master_name ON source_master(name);

-- yojijukugo
CREATE INDEX IF NOT EXISTS idx_yojijukugo_word         ON yojijukugo(word);
CREATE INDEX IF NOT EXISTS idx_yojijukugo_reading      ON yojijukugo(reading);
CREATE INDEX IF NOT EXISTS idx_yojijukugo_kanken_level ON yojijukugo(kanken_level);
CREATE INDEX IF NOT EXISTS idx_yojijukugo_source_id    ON yojijukugo(source_id);

-- kotowaza
CREATE INDEX IF NOT EXISTS idx_kotowaza_word    ON kotowaza(word);
CREATE INDEX IF NOT EXISTS idx_kotowaza_reading ON kotowaza(reading);
```

### 5.2 Mini版インデックス

```sql
-- source_master（共通）
CREATE INDEX IF NOT EXISTS idx_source_master_name ON source_master(name);

-- yojijukugo_mini
CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_word      ON yojijukugo_mini(word);
CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_reading   ON yojijukugo_mini(reading);
CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_source_id ON yojijukugo_mini(source_id);

-- kotowaza_mini
CREATE INDEX IF NOT EXISTS idx_kotowaza_mini_word    ON kotowaza_mini(word);
CREATE INDEX IF NOT EXISTS idx_kotowaza_mini_reading ON kotowaza_mini(reading);
```

---

## 6. データ投入仕様

### 6.1 入力ファイルのフォーマット

#### 四字熟語（`yojijukugo.txt`）

```
四字熟語|よみがな|意味|出典|漢検級|場面用途|URL
```

- フィールド区切り：`|`（パイプ）
- 1行1レコード
- 改行コード：`\n`（LF）
- 文字コード：UTF-8

#### ことわざ（`kotowaza.txt`）

```
ことわざ|よみがな|意味|異形|URL
```

- フィールド区切り：`|`（パイプ）
- 1行1レコード
- 改行コード：`\n`（LF）
- 文字コード：UTF-8

### 6.2 投入順序

外部キー制約があるため、以下の順で投入する。

1. `source_master`
2. `yojijukugo`
3. `kotowaza`

### 6.3 投入ルール

| 条件 | 処理 |
|------|------|
| `url` が既存レコードと重複する場合 | `INSERT OR IGNORE` でスキップ（重複排除） |
| `source_master.name` が重複する場合 | `INSERT OR IGNORE` でスキップ |
| 必須カラム（`word` / `reading` / `meaning` / `url`）が空文字の場合 | 投入をスキップしてログ出力 |
| オプションカラムが空文字の場合（`source_id` 以外） | `NULL` ではなく空文字（`''`）のまま格納する |
| `source_id` は出典フィールドが空の場合 | `NULL` を格納する |

### 6.4 `source_id` の解決方法

`yojijukugo.txt` の出典フィールドから `extract_sources.py` と同じロジックで書名を抽出し、  
`source_master` に登録済みの `id` を `source_id` に設定する。  
カンマ区切りで複数出典がある場合は**最初の出典**の `id` を設定し、`source_raw` に生テキストをすべて保持する。

### 6.5 意味フィールドの改行

テキストファイル上では `\n`（バックスラッシュ + n の2文字）として格納されている。  
DB投入時に実際の改行文字（U+000A）へ変換して格納する。

---

## 7. 実行スクリプト仕様（概要）

| 項目 | 値 |
|------|-----|
| スクリプトパス | `src/db/build_db.py` |
| 実行方法 | `python src/db/build_db.py` |
| オプション | `--db`（通常版DBファイルパス、デフォルト: `data/jpword.db`） |
| オプション | `--db-mini`（Mini版DBファイルパス、デフォルト: `data/jpword_mini.db`） |
| オプション | `--yojijukugo`（四字熟語ファイルパス、デフォルト: `data/yojijukugo.txt`） |
| オプション | `--kotowaza`（ことわざファイルパス、デフォルト: `data/kotowaza.txt`） |
| オプション | `--skip-mini`（Mini版DBの作成をスキップ） |

### 7.1 実行例

```bash
# 通常版 + Mini版を両方作成
python src/db/build_db.py

# Mini版をスキップ（通常版のみ）
python src/db/build_db.py --skip-mini
```

---

## 8. 変更履歴

| 日付 | 変更内容 |
|------|----------|
| 2026-04-26 | 初版作成 |
| 2026-04-26 | DBパスを `jpword.db` に変更・`source_master` テーブル追加・`yojijukugo` に `source_id` / `source_raw` カラム追加 |
| 2026-04-27 | Mini版DB仕様追加（`jpword_mini.db`）・`yojijukugo_mini` / `kotowaza_mini` テーブル定義追加 |
