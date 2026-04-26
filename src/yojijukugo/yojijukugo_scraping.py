"""四字熟語辞典オンラインのスクレイピング実装。

仕様: docs/spec/spec_scraping_yojijukugo.md

出力形式 (UTF-8, .txt):
    四字熟語|よみがな|意味|出典|漢検級|場面用途|URL
"""

from __future__ import annotations

import argparse
import logging
import random
import re
import socket
import time
import unicodedata
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Deque, Iterable, Optional
from urllib.parse import urljoin, urlparse, urlunparse

import requests
from bs4 import BeautifulSoup, Tag
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

START_URL = "https://yoji.jitenon.jp/yomi/"
DEFAULT_OUTPUT_PATH = "data/yojijukugo.txt"
USER_AGENT = "jpworddb-yojijukugo-scraper/1.0 (+https://github.com/undefined-0825/jpworddb)"

DETAIL_PATH_RE = re.compile(r"^/yoji[a-z]?/\d+/?$", re.IGNORECASE)
SPACE_RE = re.compile(r"\s+")


@dataclass(slots=True)
class YojijukugoRecord:
    word: str
    reading: str
    meaning: str
    source: str
    kanken_level: str
    usage: str
    url: str

    def to_line(self) -> str:
        return "|".join(
            _sanitize_field(v)
            for v in (
                self.word,
                self.reading,
                self.meaning,
                self.source,
                self.kanken_level,
                self.usage,
                self.url,
            )
        )


class YojijukugoScraper:
    def __init__(
        self,
        start_url: str = START_URL,
        min_sleep_sec: float = 0.5,
        max_sleep_sec: float = 1.0,
        timeout_sec: int = 15,
        max_listing_pages: int = 500,
    ) -> None:
        if min_sleep_sec < 0 or max_sleep_sec < 0 or min_sleep_sec > max_sleep_sec:
            raise ValueError("invalid sleep range")

        self.start_url = start_url
        self.min_sleep_sec = min_sleep_sec
        self.max_sleep_sec = max_sleep_sec
        self.timeout_sec = timeout_sec
        self.max_listing_pages = max_listing_pages

        self._session = self._build_session()

    def _build_session(self) -> requests.Session:
        session = requests.Session()
        retry = Retry(
            total=3,
            connect=3,
            read=3,
            status=3,
            backoff_factor=0.8,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=frozenset({"GET", "HEAD"}),
            raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        session.headers.update({"User-Agent": USER_AGENT})
        return session

    def scrape(self) -> Iterable[YojijukugoRecord]:
        """五十音ページを起点に詳細ページを巡回し、レコードを逐次生成する。"""
        start = _normalize_url(self.start_url)
        start_host = urlparse(start).netloc

        listing_queue: Deque[str] = deque([start])
        visited_listing_pages: set[str] = set()
        seen_detail_urls: set[str] = set()

        listing_pages_count = 0

        while listing_queue and listing_pages_count < self.max_listing_pages:
            listing_url = listing_queue.popleft()
            if listing_url in visited_listing_pages:
                continue
            visited_listing_pages.add(listing_url)
            listing_pages_count += 1

            html = self._fetch_html(listing_url)
            if not html:
                logging.error("一覧ページ取得失敗: %s", listing_url)
                continue

            soup = BeautifulSoup(html, "lxml")
            for next_url in self._extract_links(soup, listing_url):
                parsed = urlparse(next_url)
                if parsed.netloc != start_host:
                    continue

                path = parsed.path
                if DETAIL_PATH_RE.match(path):
                    if next_url in seen_detail_urls:
                        continue
                    seen_detail_urls.add(next_url)

                    record = self._parse_detail_page(next_url)
                    if record is not None:
                        yield record
                    self._throttle()
                elif self._is_listing_page_candidate(path):
                    if next_url not in visited_listing_pages:
                        listing_queue.append(next_url)

    def _fetch_html(self, url: str) -> Optional[str]:
        try:
            res = self._session.get(url, timeout=self.timeout_sec)
            if res.status_code >= 400:
                logging.error("HTTPエラー(%s): %s", res.status_code, url)
                return None
            res.encoding = res.apparent_encoding or res.encoding
            return res.text
        except requests.RequestException as exc:
            logging.error("通信エラー: %s (%s)", url, exc)
            return None

    def _extract_links(self, soup: BeautifulSoup, base_url: str) -> Iterable[str]:
        for a in soup.select("a[href]"):
            href = (a.get("href") or "").strip()
            if not href or href.startswith("#"):
                continue
            if href.lower().startswith(("javascript:", "mailto:")):
                continue

            abs_url = _normalize_url(urljoin(base_url, href))
            if abs_url:
                yield abs_url

    def _is_listing_page_candidate(self, path: str) -> bool:
        """五十音一覧から辿る可能性がある一覧ページ候補を判定。"""
        if not path:
            return False
        if DETAIL_PATH_RE.match(path):
            return False

        # 新サイトでは五十音索引配下のリンクを辿る
        return path == "/yomi" or path.startswith("/yomi/")

    def _parse_detail_page(self, url: str) -> Optional[YojijukugoRecord]:
        html = self._fetch_html(url)
        if not html:
            return None

        soup = BeautifulSoup(html, "lxml")

        try:
            word = self._extract_word(soup)
            if not word:
                logging.error("四字熟語抽出失敗: %s", url)
                return None

            reading = self._extract_field(soup, labels=("読み", "よみ", "読み方"))
            meaning = self._extract_field(soup, labels=("意味", "解説"), preserve_breaks=True)
            source = self._extract_field(soup, labels=("出典",))
            kanken_level = self._extract_field(soup, labels=("漢検級",))
            usage = self._extract_field(soup, labels=("場面用途", "場面・用途"))

            reading = _normalize_reading(reading)
            meaning = _normalize_meaning(meaning)
            source = _normalize_text(source)
            kanken_level = _normalize_kanken_level(kanken_level)
            usage = _normalize_usage(usage)

            return YojijukugoRecord(
                word=word,
                reading=reading,
                meaning=meaning,
                source=source,
                kanken_level=kanken_level,
                usage=usage,
                url=url,
            )
        except Exception as exc:  # noqa: BLE001
            logging.exception("パース失敗: %s (%s)", url, exc)
            return None

    def _extract_word(self, soup: BeautifulSoup) -> str:
        h1 = soup.find("h1")
        if isinstance(h1, Tag):
            text = _normalize_text(h1.get_text(" ", strip=True))
            if text:
                return text

        if soup.title:
            title = _normalize_text(soup.title.get_text(" ", strip=True))
            # 例: 異口同音（いくどうおん） - 四字熟語辞典オンライン
            title = re.split(r"\s[-｜|]\s", title, maxsplit=1)[0]
            title = title.strip(" 　")
            if title:
                return title

        return ""

    def _extract_field(self, soup: BeautifulSoup, labels: tuple[str, ...], preserve_breaks: bool = False) -> str:
        # 1) ラベルベース（最優先）
        by_label = self._extract_by_label_search(soup, labels, preserve_breaks=preserve_breaks)
        if by_label:
            return by_label

        # 2) table構造 fallback
        by_table = self._extract_from_table(soup, labels, preserve_breaks=preserve_breaks)
        if by_table:
            return by_table

        # 3) dt/dd構造 fallback
        by_dl = self._extract_from_dl(soup, labels, preserve_breaks=preserve_breaks)
        if by_dl:
            return by_dl

        return ""

    def _extract_by_label_search(self, soup: BeautifulSoup, labels: tuple[str, ...], preserve_breaks: bool = False) -> str:
        for node in soup.find_all(string=True):
            if not isinstance(node, str):
                continue
            label_text = _normalize_label(node)
            if not label_text:
                continue

            if any(label_text == lbl for lbl in labels):
                parent = node.parent
                if not isinstance(parent, Tag):
                    continue

                # td/thやdt/ddの横要素
                sibling_value = self._extract_neighbor_text(parent, preserve_breaks=preserve_breaks)
                if sibling_value:
                    return sibling_value

                # 同一要素に「読み: xxxx」形式で書かれている場合
                joined = _extract_text_from_tag(parent, preserve_breaks=False)
                val = _extract_value_after_label(joined, labels)
                if val:
                    return val

        return ""

    def _extract_neighbor_text(self, label_tag: Tag, preserve_breaks: bool = False) -> str:
        # table row: <th>読み</th><td>いくどうおん</td>
        if label_tag.name in {"th", "td"}:
            row = label_tag.parent if isinstance(label_tag.parent, Tag) else None
            if row and row.name == "tr":
                cells = [c for c in row.find_all(["th", "td"], recursive=False)]
                if len(cells) >= 2:
                    for i, cell in enumerate(cells[:-1]):
                        if cell is label_tag:
                            text = _extract_text_from_tag(cells[i + 1], preserve_breaks=preserve_breaks)
                            if text:
                                return text

        # definition list: <dt>読み</dt><dd>いくどうおん</dd>
        if label_tag.name == "dt":
            dd = label_tag.find_next_sibling("dd")
            if isinstance(dd, Tag):
                text = _extract_text_from_tag(dd, preserve_breaks=preserve_breaks)
                if text:
                    return text

        # generic next sibling text
        for sib in label_tag.next_siblings:
            if isinstance(sib, str):
                text = _normalize_text(sib)
                if text:
                    return text
            elif isinstance(sib, Tag):
                text = _extract_text_from_tag(sib, preserve_breaks=preserve_breaks)
                if text:
                    return text

        return ""

    def _extract_from_table(self, soup: BeautifulSoup, labels: tuple[str, ...], preserve_breaks: bool = False) -> str:
        for row in soup.find_all("tr"):
            cells = row.find_all(["th", "td"], recursive=False)
            if len(cells) < 2:
                continue
            key = _normalize_label(cells[0].get_text(" ", strip=True))
            if any(lbl in key for lbl in labels):
                value = _extract_text_from_tag(cells[1], preserve_breaks=preserve_breaks)
                if value:
                    return value
        return ""

    def _extract_from_dl(self, soup: BeautifulSoup, labels: tuple[str, ...], preserve_breaks: bool = False) -> str:
        for dt in soup.find_all("dt"):
            key = _normalize_label(dt.get_text(" ", strip=True))
            if any(lbl in key for lbl in labels):
                dd = dt.find_next_sibling("dd")
                if isinstance(dd, Tag):
                    value = _extract_text_from_tag(dd, preserve_breaks=preserve_breaks)
                    if value:
                        return value
        return ""

    def _throttle(self) -> None:
        if self.max_sleep_sec <= 0:
            return
        sleep_sec = random.uniform(self.min_sleep_sec, self.max_sleep_sec)
        time.sleep(sleep_sec)


def _normalize_url(url: str) -> str:
    parsed = urlparse(url)
    # query/fragment は重複判定を不安定にするので除去
    normalized = parsed._replace(query="", fragment="")
    return urlunparse(normalized)


def _normalize_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\u3000", " ")
    text = text.replace("\r", " ").replace("\n", " ")
    text = SPACE_RE.sub(" ", text)
    return text.strip()


def _normalize_multiline_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("\u3000", " ")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for line in text.split("\n"):
        line = SPACE_RE.sub(" ", line).strip()
        if line:
            lines.append(line)
    return "\\n".join(lines)


def _extract_text_from_tag(tag: Tag, preserve_breaks: bool = False) -> str:
    if preserve_breaks:
        return _normalize_multiline_text(tag.get_text("\n", strip=True))
    return _normalize_text(tag.get_text(" ", strip=True))


def _normalize_label(text: str) -> str:
    text = _normalize_text(text)
    # 「読み：」「[読み]」などの記号揺れを吸収
    text = re.sub(r"[\[\]【】()（）:：\-－]\s*", "", text)
    return text


def _extract_value_after_label(text: str, labels: tuple[str, ...]) -> str:
    for label in labels:
        pattern = rf"{re.escape(label)}\s*[：:]\s*(.+)$"
        m = re.search(pattern, text)
        if m:
            return _normalize_text(m.group(1))
    return ""


def _katakana_to_hiragana(text: str) -> str:
    out_chars: list[str] = []
    for ch in text:
        code = ord(ch)
        if 0x30A1 <= code <= 0x30F6:
            out_chars.append(chr(code - 0x60))
        else:
            out_chars.append(ch)
    return "".join(out_chars)


def _normalize_reading(text: str) -> str:
    text = _normalize_text(text)
    text = _katakana_to_hiragana(text)
    return text


def _normalize_meaning(text: str) -> str:
    text = _normalize_multiline_text(text)
    return text


def _normalize_kanken_level(text: str) -> str:
    text = _normalize_text(text)
    text = re.sub(r"\s+", "", text)  # 「2 級」→「2級」
    return text


def _normalize_usage(text: str) -> str:
    text = _normalize_text(text)
    text = re.sub(r"\s*/\s*", "/", text)
    return text

def _sanitize_field(value: str) -> str:
    # 区切り文字衝突回避
    return value.replace("|", "｜")


def save_records_to_txt(
    records: Iterable[YojijukugoRecord],
    output_path: Path,
    max_records: int = 0,
) -> tuple[int, int]:
    """レコードをTXTに保存する。max_records > 0 の場合、その件数で打ち切る。"""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    total = 0
    written = 0
    seen_words: set[str] = set()

    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        for rec in records:
            total += 1

            # 重複排除キー: 四字熟語（最初の1件のみ採用）
            if rec.word in seen_words:
                continue
            seen_words.add(rec.word)

            f.write(rec.to_line())
            f.write("\n")
            written += 1

            if written % 50 == 0:
                logging.info("出力件数: %d", written)

            if max_records > 0 and written >= max_records:
                logging.info("--max-records=%d に達したため打ち切り", max_records)
                break

    return total, written


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="四字熟語辞典オンラインをスクレイピングしてTXT出力します")
    parser.add_argument("--output", default=DEFAULT_OUTPUT_PATH, help="出力先TXTパス (default: data/yojijukugo.txt)")
    parser.add_argument("--start-url", default=START_URL, help="開始URL")
    parser.add_argument("--min-sleep", type=float, default=0.5, help="リクエスト間sleep最小秒")
    parser.add_argument("--max-sleep", type=float, default=1.0, help="リクエスト間sleep最大秒")
    parser.add_argument("--timeout", type=int, default=15, help="HTTPタイムアウト秒")
    parser.add_argument("--max-listing-pages", type=int, default=500, help="巡回する一覧ページの最大数")
    parser.add_argument("--max-records", type=int, default=0, help="出力件数の上限（0=無制限）")
    parser.add_argument("--log-level", default="INFO", choices=("DEBUG", "INFO", "WARNING", "ERROR"), help="ログレベル")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    # DNS解決を含む全ソケット操作にグローバルタイムアウトを設定
    socket.setdefaulttimeout(30)

    scraper = YojijukugoScraper(
        start_url=args.start_url,
        min_sleep_sec=args.min_sleep,
        max_sleep_sec=args.max_sleep,
        timeout_sec=args.timeout,
        max_listing_pages=args.max_listing_pages,
    )

    output_path = Path(args.output)
    logging.info("開始: start_url=%s output=%s", args.start_url, output_path)

    total, written = save_records_to_txt(scraper.scrape(), output_path, max_records=args.max_records)

    logging.info("完了: 取得=%d, 出力(重複排除後)=%d, ファイル=%s", total, written, output_path)

    if written == 0:
        logging.warning("出力件数が0件です。HTML構造の変化やアクセス制限を確認してください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
