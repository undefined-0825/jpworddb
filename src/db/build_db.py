"""四字熟語・ことわざ・出典マスターを SQLite に登録する。

仕様: docs/spec/spec_db.md

投入順序:
    1. source_master  （出典マスター）
    2. yojijukugo     （四字熟語）
    3. kotowaza       （ことわざ）

Usage:
    python src/db/build_db.py
    python src/db/build_db.py --db data/jpword.db --yojijukugo data/yojijukugo.txt --kotowaza data/kotowaza.txt
"""

from __future__ import annotations

import argparse
import logging
import sqlite3
import sys
from pathlib import Path

# extract_sources.py と同じ抽出ロジックをインラインで持つ
import re

RE_NIJUKAGI = re.compile(r"[『](.*?)[』]")
RE_KAGI = re.compile(r"[「](.*?)[」]")

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger(__name__)

# --------------------------------------------------------------------------- #
# DDL
# --------------------------------------------------------------------------- #

DDL_SOURCE_MASTER = """
CREATE TABLE IF NOT EXISTS source_master (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"""

DDL_YOJIJUKUGO = """
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
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    level         INTEGER
);
"""

DDL_KOTOWAZA = """
CREATE TABLE IF NOT EXISTS kotowaza (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    word       TEXT    NOT NULL,
    reading    TEXT    NOT NULL,
    meaning    TEXT    NOT NULL,
    variant    TEXT,
    url        TEXT    NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    level      INTEGER,
    bunsetsu   TEXT
);
"""

DDL_YOJIJUKUGO_MINI = """
CREATE TABLE IF NOT EXISTS yojijukugo_mini (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    word       TEXT    NOT NULL,
    reading    TEXT    NOT NULL,
    meaning    TEXT    NOT NULL,
    source_id  INTEGER REFERENCES source_master(id),
    source_raw TEXT
);
"""

DDL_KOTOWAZA_MINI = """
CREATE TABLE IF NOT EXISTS kotowaza_mini (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    word     TEXT    NOT NULL,
    reading  TEXT    NOT NULL,
    meaning  TEXT    NOT NULL
);
"""

DDL_INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_source_master_name      ON source_master(name);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_word         ON yojijukugo(word);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_reading      ON yojijukugo(reading);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_kanken_level ON yojijukugo(kanken_level);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_source_id    ON yojijukugo(source_id);",
    "CREATE INDEX IF NOT EXISTS idx_kotowaza_word           ON kotowaza(word);",
    "CREATE INDEX IF NOT EXISTS idx_kotowaza_reading        ON kotowaza(reading);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_word      ON yojijukugo_mini(word);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_reading   ON yojijukugo_mini(reading);",
    "CREATE INDEX IF NOT EXISTS idx_yojijukugo_mini_source_id ON yojijukugo_mini(source_id);",
    "CREATE INDEX IF NOT EXISTS idx_kotowaza_mini_word    ON kotowaza_mini(word);",
    "CREATE INDEX IF NOT EXISTS idx_kotowaza_mini_reading ON kotowaza_mini(reading);",
]

# --------------------------------------------------------------------------- #
# 出典抽出ヘルパー（extract_sources.py と同一ロジック）
# --------------------------------------------------------------------------- #

def _extract_source_name(raw: str) -> str:
    """出典文字列から書名を抽出する。"""
    m = RE_NIJUKAGI.search(raw)
    if m:
        return m.group(1).strip()
    m = RE_KAGI.search(raw)
    if m:
        return m.group(1).strip()
    return raw.strip()


def _first_source_name(source_field: str) -> str:
    """カンマ区切り出典フィールドの最初の書名を返す。空の場合は空文字。"""
    if not source_field:
        return ""
    first_chunk = source_field.split(",")[0].strip()
    if not first_chunk:
        return ""
    return _extract_source_name(first_chunk)


# --------------------------------------------------------------------------- #
# DB 初期化
# --------------------------------------------------------------------------- #

def init_db(conn: sqlite3.Connection) -> None:
    """テーブル・インデックスを作成する。"""
    conn.execute("PRAGMA foreign_keys = ON;")
    for ddl in (DDL_SOURCE_MASTER, DDL_YOJIJUKUGO, DDL_KOTOWAZA):
        conn.execute(ddl)
    # 通常版のみのインデックス（mini版を除外）
    normal_indexes = [idx for idx in DDL_INDEXES if "_mini" not in idx]
    for idx in normal_indexes:
        conn.execute(idx)
    conn.commit()
    log.info("テーブル・インデックスの初期化完了")


def init_db_mini(conn: sqlite3.Connection) -> None:
    """Mini版テーブル・インデックスを作成する。source_master は source_db から共有。"""
    conn.execute("PRAGMA foreign_keys = ON;")
    for ddl in (DDL_SOURCE_MASTER, DDL_YOJIJUKUGO_MINI, DDL_KOTOWAZA_MINI):
        conn.execute(ddl)
    # mini版インデックスのみ作成（インデックスリストから mini版を抽出）
    mini_indexes = [idx for idx in DDL_INDEXES if "_mini" in idx]
    mini_indexes.insert(0, DDL_INDEXES[0])  # source_master インデックスも追加
    for idx in mini_indexes:
        conn.execute(idx)
    conn.commit()
    log.info("Mini版テーブル・インデックスの初期化完了")


# --------------------------------------------------------------------------- #
# source_master 投入
# --------------------------------------------------------------------------- #

def load_source_master(conn: sqlite3.Connection, yojijukugo_path: Path) -> dict[str, int]:
    """yojijukugo.txt の出典フィールドから書名を抽出して source_master に登録する。
    書名 → id のマップを返す。
    """
    names: set[str] = set()
    for line in yojijukugo_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) < 7:
            continue
        source_field = parts[3].strip()
        if not source_field:
            continue
        for chunk in source_field.split(","):
            chunk = chunk.strip()
            if not chunk:
                continue
            name = _extract_source_name(chunk)
            if name:
                names.add(name)

    inserted = 0
    for name in sorted(names):
        cur = conn.execute(
            "INSERT OR IGNORE INTO source_master (name) VALUES (?);", (name,)
        )
        if cur.rowcount:
            inserted += 1
    conn.commit()

    log.info("source_master: %d 件挿入（重複スキップ含む総書名 %d 件）", inserted, len(names))

    # 登録済み書名 → id マップを返す
    rows = conn.execute("SELECT name, id FROM source_master;").fetchall()
    return {row[0]: row[1] for row in rows}


# --------------------------------------------------------------------------- #
# yojijukugo 投入
# --------------------------------------------------------------------------- #

def load_yojijukugo(
    conn: sqlite3.Connection,
    path: Path,
    source_map: dict[str, int],
) -> None:
    """yojijukugo.txt を読み込んで yojijukugo テーブルに投入する。"""
    inserted = skipped = ignored = 0

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line:
            continue

        parts = line.split("|")
        if len(parts) < 7:
            log.warning("yojijukugo L%d: フィールド数不足（%d）スキップ", lineno, len(parts))
            skipped += 1
            continue

        word, reading, meaning_raw, source_field, kanken_level, usage, url = (
            parts[0].strip(),
            parts[1].strip(),
            parts[2].strip(),
            parts[3].strip(),
            parts[4].strip(),
            parts[5].strip(),
            parts[6].strip(),
        )

        # 必須フィールド検証
        if not all((word, reading, meaning_raw, url)):
            log.warning("yojijukugo L%d: 必須フィールドが空 word=%r url=%r スキップ", lineno, word, url)
            skipped += 1
            continue

        # 意味フィールドの \n（2文字）を実際の改行へ変換
        meaning = meaning_raw.replace("\\n", "\n")

        # source_id を解決
        source_id: int | None = None
        if source_field:
            first_name = _first_source_name(source_field)
            source_id = source_map.get(first_name)

        cur = conn.execute(
            """
            INSERT OR IGNORE INTO yojijukugo
                (word, reading, meaning, source_id, source_raw, kanken_level, usage, url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (word, reading, meaning, source_id, source_field, kanken_level, usage, url),
        )
        if cur.rowcount:
            inserted += 1
        else:
            ignored += 1

    conn.commit()
    log.info(
        "yojijukugo: %d 件挿入 / %d 件重複スキップ / %d 件バリデーションスキップ",
        inserted, ignored, skipped,
    )


# --------------------------------------------------------------------------- #
# kotowaza 投入
# --------------------------------------------------------------------------- #

def load_kotowaza(conn: sqlite3.Connection, path: Path) -> None:
    """kotowaza.txt を読み込んで kotowaza テーブルに投入する。"""
    inserted = skipped = ignored = 0

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line:
            continue

        parts = line.split("|")
        if len(parts) < 5:
            log.warning("kotowaza L%d: フィールド数不足（%d）スキップ", lineno, len(parts))
            skipped += 1
            continue

        word, reading, meaning_raw, variant, url = (
            parts[0].strip(),
            parts[1].strip(),
            parts[2].strip(),
            parts[3].strip(),
            parts[4].strip(),
        )
        bunsetsu = parts[5].strip() if len(parts) >= 6 else ""

        # 必須フィールド検証
        if not all((word, reading, meaning_raw, url)):
            log.warning("kotowaza L%d: 必須フィールドが空 word=%r url=%r スキップ", lineno, word, url)
            skipped += 1
            continue

        meaning = meaning_raw.replace("\\n", "\n")

        cur = conn.execute(
            """
            INSERT OR IGNORE INTO kotowaza
                (word, reading, meaning, variant, url, bunsetsu)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            (word, reading, meaning, variant, url, bunsetsu),
        )
        if cur.rowcount:
            inserted += 1
        else:
            ignored += 1

    conn.commit()
    log.info(
        "kotowaza: %d 件挿入 / %d 件重複スキップ / %d 件バリデーションスキップ",
        inserted, ignored, skipped,
    )


# --------------------------------------------------------------------------- #
# yojijukugo_mini 投入
# --------------------------------------------------------------------------- #

def load_yojijukugo_mini(
    conn: sqlite3.Connection,
    path: Path,
    source_map: dict[str, int],
) -> None:
    """yojijukugo.txt を読み込んで yojijukugo_mini テーブルに投入する。
    mini版は kanken_level / usage / url / created_at を除外。
    """
    inserted = skipped = 0

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line:
            continue

        parts = line.split("|")
        if len(parts) < 7:
            skipped += 1
            continue

        word, reading, meaning_raw, source_field = (
            parts[0].strip(),
            parts[1].strip(),
            parts[2].strip(),
            parts[3].strip(),
        )

        # 必須フィールド検証
        if not all((word, reading, meaning_raw)):
            skipped += 1
            continue

        meaning = meaning_raw.replace("\\n", "\n")

        # source_id を解決
        source_id: int | None = None
        if source_field:
            first_name = _first_source_name(source_field)
            source_id = source_map.get(first_name)

        cur = conn.execute(
            """
            INSERT INTO yojijukugo_mini
                (word, reading, meaning, source_id, source_raw)
            VALUES (?, ?, ?, ?, ?);
            """,
            (word, reading, meaning, source_id, source_field),
        )
        if cur.rowcount:
            inserted += 1

    conn.commit()
    log.info("yojijukugo_mini: %d 件挿入 / %d 件バリデーションスキップ", inserted, skipped)


# --------------------------------------------------------------------------- #
# kotowaza_mini 投入
# --------------------------------------------------------------------------- #

def load_kotowaza_mini(conn: sqlite3.Connection, path: Path) -> None:
    """kotowaza.txt を読み込んで kotowaza_mini テーブルに投入する。
    mini版は variant / url / created_at を除外。
    """
    inserted = skipped = 0

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = line.strip()
        if not line:
            continue

        parts = line.split("|")
        if len(parts) < 5:
            skipped += 1
            continue

        word, reading, meaning_raw = (
            parts[0].strip(),
            parts[1].strip(),
            parts[2].strip(),
        )

        # 必須フィールド検証
        if not all((word, reading, meaning_raw)):
            skipped += 1
            continue

        meaning = meaning_raw.replace("\\n", "\n")

        cur = conn.execute(
            """
            INSERT INTO kotowaza_mini
                (word, reading, meaning)
            VALUES (?, ?, ?);
            """,
            (word, reading, meaning),
        )
        if cur.rowcount:
            inserted += 1

    conn.commit()
    log.info("kotowaza_mini: %d 件挿入 / %d 件バリデーションスキップ", inserted, skipped)


# --------------------------------------------------------------------------- #
# エントリポイント
# --------------------------------------------------------------------------- #

def main() -> None:
    parser = argparse.ArgumentParser(description="四字熟語・ことわざDBを構築する")
    parser.add_argument("--db", default="data/jpword.db", help="SQLite DBファイルパス")
    parser.add_argument("--db-mini", default="data/jpword_mini.db", help="Mini版DBファイルパス")
    parser.add_argument("--skip-mini", action="store_true", help="Mini版DBの作成をスキップ")
    parser.add_argument("--yojijukugo", default="data/yojijukugo.txt", help="四字熟語ファイルパス")
    parser.add_argument("--kotowaza", default="data/kotowaza.txt", help="ことわざファイルパス")
    args = parser.parse_args()

    db_path = Path(args.db)
    db_mini_path = Path(args.db_mini) if not args.skip_mini else None
    yoji_path = Path(args.yojijukugo)
    koto_path = Path(args.kotowaza)

    for p in (yoji_path, koto_path):
        if not p.exists():
            log.error("ファイルが見つかりません: %s", p)
            sys.exit(1)

    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_mini_path:
        db_mini_path.parent.mkdir(parents=True, exist_ok=True)

    # 通常版DB作成
    with sqlite3.connect(db_path) as conn:
        init_db(conn)
        source_map = load_source_master(conn, yoji_path)
        load_yojijukugo(conn, yoji_path, source_map)
        load_kotowaza(conn, koto_path)

    log.info("完了: %s", db_path)

    # Mini版DB作成
    if db_mini_path:
        with sqlite3.connect(db_mini_path) as conn:
            init_db_mini(conn)
            source_map = load_source_master(conn, yoji_path)
            load_yojijukugo_mini(conn, yoji_path, source_map)
            load_kotowaza_mini(conn, koto_path)
        log.info("完了: %s", db_mini_path)


if __name__ == "__main__":
    main()
