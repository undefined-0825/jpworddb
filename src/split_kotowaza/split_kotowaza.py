"""ことわざを文節候補ごとに分割し、DBへ登録するツール。

Usage:
    python src/split_kotowaza/split_kotowaza.py
    python src/split_kotowaza/split_kotowaza.py --db data/jpword.db --force
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path

try:
    from sudachipy import dictionary, tokenizer as sudachi_tokenizer
except Exception as exc:  # noqa: BLE001
    raise SystemExit(
        "SudachiPy が必要です。`pip install sudachipy sudachidict_core` を実行してください。"
    ) from exc


_PUNCT_RE = re.compile(r"^[、。・…ー〜\-]+$")


def _heuristic_fallback(text: str) -> list[str]:
    """Sudachiで1要素しか作れない場合の簡易分割。"""
    if len(text) <= 3:
        return [text]

    boundaries = set("はがをにへとでもやかの")
    chunks: list[str] = []
    buf = ""
    for i, ch in enumerate(text):
        buf += ch
        if ch in boundaries and i < len(text) - 1 and len(buf) >= 2:
            chunks.append(buf)
            buf = ""
    if buf:
        chunks.append(buf)
    return chunks if len(chunks) >= 2 else [text]


def split_bunsetsu(text: str, tok: sudachi_tokenizer.Tokenizer) -> list[str]:
    mode = sudachi_tokenizer.Tokenizer.SplitMode.C
    raw = [m.surface() for m in tok.tokenize(text, mode)]
    chunks: list[str] = []
    for r in raw:
        if not r:
            continue
        if chunks and _PUNCT_RE.fullmatch(r):
            chunks[-1] += r
            continue
        chunks.append(r)

    if len(chunks) <= 1:
        chunks = _heuristic_fallback(text)
    return chunks


def ensure_column(conn: sqlite3.Connection) -> None:
    cols = conn.execute("PRAGMA table_info(kotowaza)").fetchall()
    has_bunsetsu = any(c[1] == "bunsetsu" for c in cols)
    if not has_bunsetsu:
        conn.execute("ALTER TABLE kotowaza ADD COLUMN bunsetsu TEXT")
        conn.commit()


def update_bunsetsu(db_path: Path, force: bool = False, limit: int = 0) -> tuple[int, int]:
    conn = sqlite3.connect(db_path)
    try:
        ensure_column(conn)
        tok = dictionary.Dictionary().create()

        sql = (
            "SELECT id, word FROM kotowaza"
            if force
            else "SELECT id, word FROM kotowaza WHERE COALESCE(TRIM(bunsetsu), '') = ''"
        )
        rows = conn.execute(sql).fetchall()
        if limit > 0:
            rows = rows[:limit]

        updated = 0
        for row_id, word in rows:
            parts = split_bunsetsu(str(word), tok)
            payload = json.dumps(parts, ensure_ascii=False)
            conn.execute("UPDATE kotowaza SET bunsetsu = ? WHERE id = ?", (payload, row_id))
            updated += 1

        conn.commit()
        total = conn.execute("SELECT COUNT(*) FROM kotowaza").fetchone()[0]
        return updated, total
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="ことわざを文節候補に分割してDB登録")
    parser.add_argument("--db", default="data/jpword.db", help="対象DBファイル")
    parser.add_argument("--force", action="store_true", help="既存bunsetsuを上書き")
    parser.add_argument("--limit", type=int, default=0, help="更新件数上限（0で全件）")
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"DBが見つかりません: {db_path}")

    updated, total = update_bunsetsu(db_path, force=args.force, limit=args.limit)
    print(f"updated={updated} / total={total}")


if __name__ == "__main__":
    main()
