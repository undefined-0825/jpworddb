"""四字熟語テキストから出典書名を抽出し、マスターテーブル候補として出力する。

抽出ルール:
    1. フィールドはカンマで複数出典に分割する
    2. 各出典の『 』内の書名を採用（例: 『論語』「子路」→ 論語）
    3. 『 』がない場合は最初の「 」内を採用（例: 「晏子春秋」「諫・下」→ 晏子春秋）
    4. どちらもない場合はスキップ
    5. 重複排除・ソートして出力

Usage:
    python src/db/extract_sources.py [--input data/yojijukugo.txt] [--output data/sources.txt]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# 『書名』 を捕捉
RE_NIJUKAGI = re.compile(r"[『](.*?)[』]")
# 「書名」 を捕捉（『』がない場合の fallback）
RE_KAGI = re.compile(r"[「](.*?)[」]")


def extract_source_name(raw: str) -> str:
    """1つの出典文字列から書名を抽出する。

    優先順位:
        1. 『書名』 → 書名を返す
        2. 「書名」 → 最初の「」の中身を返す（『』なし）
        3. どちらもない → raw をそのまま返す
    """
    m = RE_NIJUKAGI.search(raw)
    if m:
        return m.group(1).strip()
    m = RE_KAGI.search(raw)
    if m:
        return m.group(1).strip()
    return raw.strip()


def extract_all_sources(filepath: Path) -> list[str]:
    """yojijukugo.txt から書名一覧（重複排除・ソート済み）を返す。"""
    seen: set[str] = set()
    skipped = 0

    for lineno, line in enumerate(
        filepath.read_text(encoding="utf-8").splitlines(), start=1
    ):
        line = line.strip()
        if not line:
            continue

        parts = line.split("|")
        if len(parts) < 7:
            skipped += 1
            continue

        source_field = parts[3].strip()
        if not source_field:
            continue

        # カンマ区切りで複数出典を分割
        for chunk in source_field.split(","):
            chunk = chunk.strip()
            if not chunk:
                continue
            name = extract_source_name(chunk)
            if name:  # 空文字のみスキップ
                seen.add(name)

    if skipped:
        print(f"[warn] フィールド数不足でスキップしたレコード: {skipped} 件", file=sys.stderr)

    return sorted(seen)


def main() -> None:
    parser = argparse.ArgumentParser(description="四字熟語の出典書名を抽出する")
    parser.add_argument(
        "--input",
        default="data/yojijukugo.txt",
        help="yojijukugo.txt のパス（デフォルト: data/yojijukugo.txt）",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="出力ファイルパス（省略時は標準出力）",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[error] ファイルが見つかりません: {input_path}", file=sys.stderr)
        sys.exit(1)

    sources = extract_all_sources(input_path)

    output_lines = [f"{i + 1}\t{name}" for i, name in enumerate(sources)]
    result = "\n".join(output_lines) + "\n"

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(result, encoding="utf-8")
        print(f"[info] {len(sources)} 件の書名を {out_path} に出力しました。")
    else:
        print(f"[info] 抽出件数: {len(sources)} 件\n", file=sys.stderr)
        print(result, end="")


if __name__ == "__main__":
    main()
