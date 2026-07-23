#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Импорт закладок из Bookmarks.json (Chromium/Edge) в SQLite базу edge.db.

Берётся содержимое ТОЛЬКО папки "Панель избранного" (root: bookmark_bar),
включая все вложенные подпапки. Остальные корневые разделы файла
(«Другое избранное», «Избранное на мобильных устройствах»,
«Рабочие пространства» и т.д.) игнорируются.

Таблица favorites — ИЕРАРХИЧЕСКАЯ: и папки, и закладки хранятся как
записи одной таблицы, связь "папка -> содержимое" задаётся колонкой
parent_id (self-reference на favorites.id). Сама папка "Панель избранного"
в таблицу не добавляется — записями становится только её содержимое,
поэтому элементы верхнего уровня имеют parent_id = NULL.

Порядок закладок/папок внутри каждой папки сохраняется в колонке ord
(0, 1, 2, ... в порядке из Bookmarks.json) — это нужно, чтобы потом
строить домашнюю страницу с плитками в том же порядке, что и в браузере.

Для будущих плиток на домашней странице добавлена колонка tile_image —
пустая, скрипт её не трогает; заполнять её планируется отдельно.
При повторных запусках скрипт НИКОГДА не перезаписывает tile_image.

Таблица создаётся, если её ещё нет. При повторном запуске существующие
записи (по guid) обновляются, новые добавляются, а закладки/папки,
которых больше нет в файле, помечаются is_deleted = 1 (не удаляются
физически).

Использование:
    python3 import_favorites.py [--bookmarks Bookmarks.json] [--db edge.db]

По умолчанию:
    --bookmarks = Bookmarks.json  (в текущей папке)
    --db        = edge.db         (в текущей папке; создаётся, если нет)
"""

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT_FOLDER_NAME = "Панель избранного"

# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

def webkit_to_iso(webkit_ts) -> str | None:
    """
    Конвертирует WebKit/Chromium timestamp (микросекунды с 1601-01-01 UTC)
    в строку ISO 8601. Возвращает None, если значение пустое/нулевое.
    """
    try:
        ts = int(webkit_ts)
    except (TypeError, ValueError):
        return None
    if not ts:
        return None
    epoch_start = datetime(1601, 1, 1, tzinfo=timezone.utc)
    try:
        dt = epoch_start + timedelta(microseconds=ts)
    except OverflowError:
        return None
    return dt.isoformat()


def find_root_folder(bookmarks_data: dict, folder_name: str) -> dict:
    """
    Ищет папку с заданным name среди корневых разделов ("roots"),
    а также, на всякий случай, рекурсивно внутри них (вдруг название
    совпадает не с самим root, а с вложенной папкой).
    """
    roots = bookmarks_data.get("roots", {})

    for root in roots.values():
        if isinstance(root, dict) and root.get("name") == folder_name:
            return root

    def search(node):
        if not isinstance(node, dict):
            return None
        if node.get("type") == "folder" and node.get("name") == folder_name:
            return node
        for child in node.get("children", []) or []:
            found = search(child)
            if found:
                return found
        return None

    for root in roots.values():
        found = search(root)
        if found:
            return found

    raise ValueError(f'Папка "{folder_name}" не найдена в файле закладок.')


def flatten_bookmarks(node: dict, parent_guid=None) -> list:
    """
    Рекурсивно обходит дерево закладок (children узла node) и возвращает
    плоский список записей — и папки, и закладки вперемешку, каждая со
    своим parent_guid (guid родительской папки в дереве, либо None для
    элементов верхнего уровня) и ord (порядковый номер среди "братьев").

    parent_id (числовой, для БД) вычисляется позже, при записи в БД,
    потому что порядок вставки/апдейта в БД нам не важен, а guid уникален.
    """
    items = []
    for index, child in enumerate(node.get("children", []) or []):
        node_type = child.get("type")
        if node_type not in ("url", "folder"):
            continue

        items.append({
            "guid": child.get("guid"),
            "parent_guid": parent_guid,
            "chrome_id": child.get("id"),
            "type": node_type,
            "name": child.get("name", ""),
            "url": child.get("url") if node_type == "url" else None,
            "ord": index,
            "date_added": webkit_to_iso(child.get("date_added")),
            "date_last_used": webkit_to_iso(child.get("date_last_used")),
        })

        if node_type == "folder":
            items.extend(flatten_bookmarks(child, parent_guid=child.get("guid")))

    return items


# ---------------------------------------------------------------------------
# Работа с БД
# ---------------------------------------------------------------------------

def ensure_table(conn: sqlite3.Connection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS favorites (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            guid            TEXT UNIQUE,
            chrome_id       TEXT,
            parent_id       INTEGER REFERENCES favorites(id),
            type            TEXT NOT NULL CHECK (type IN ('folder', 'url')),
            name            TEXT NOT NULL,
            url             TEXT,
            ord             INTEGER NOT NULL DEFAULT 0,
            tile_image      TEXT,
            date_added      TEXT,
            date_last_used  TEXT,
            is_deleted      INTEGER NOT NULL DEFAULT 0,
            created_at      TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_favorites_parent_id ON favorites(parent_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_favorites_url ON favorites(url)")
    conn.commit()


def upsert_favorites(conn: sqlite3.Connection, items: list) -> tuple:
    """
    Вставляет новые и обновляет существующие записи (ключ — guid).
    tile_image НИКОГДА не перезаписывается автоматически — это поле
    для ручного/отдельного заполнения ссылками на плитки.

    parent_id вычисляется через guid -> id, поэтому сначала все узлы
    вставляются/обновляются без parent_id, а затем отдельным проходом
    проставляется parent_id (это надёжно работает независимо от порядка
    обхода дерева и от того, создаётся папка впервые или уже существует).

    Возвращает (кол-во вставленных, кол-во обновлённых, кол-во помеченных удалёнными).
    """
    cur = conn.cursor()
    inserted = 0
    updated = 0

    # Проход 1: вставка/обновление узлов без parent_id
    for item in items:
        guid = item["guid"]
        cur.execute("SELECT id FROM favorites WHERE guid = ?", (guid,))
        existing = cur.fetchone()

        if existing:
            cur.execute("""
                UPDATE favorites
                   SET chrome_id = ?,
                       type = ?,
                       name = ?,
                       url = ?,
                       ord = ?,
                       date_added = ?,
                       date_last_used = ?,
                       is_deleted = 0,
                       updated_at = datetime('now')
                 WHERE guid = ?
            """, (
                item["chrome_id"], item["type"], item["name"], item["url"],
                item["ord"], item["date_added"], item["date_last_used"], guid,
            ))
            updated += 1
        else:
            cur.execute("""
                INSERT INTO favorites
                    (guid, chrome_id, type, name, url, ord, date_added, date_last_used)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                guid, item["chrome_id"], item["type"], item["name"], item["url"],
                item["ord"], item["date_added"], item["date_last_used"],
            ))
            inserted += 1

    # Проход 2: проставляем parent_id по guid родителя
    for item in items:
        if item["parent_guid"] is None:
            cur.execute(
                "UPDATE favorites SET parent_id = NULL WHERE guid = ?",
                (item["guid"],),
            )
        else:
            cur.execute("""
                UPDATE favorites
                   SET parent_id = (SELECT id FROM favorites WHERE guid = ?)
                 WHERE guid = ?
            """, (item["parent_guid"], item["guid"]))

    # Помечаем как удалённые записи, которых больше нет в текущем файле закладок
    marked_deleted = 0
    seen_guids = [item["guid"] for item in items if item["guid"]]
    if seen_guids:
        placeholders = ",".join("?" * len(seen_guids))
        cur.execute(f"""
            UPDATE favorites
               SET is_deleted = 1,
                   updated_at = datetime('now')
             WHERE is_deleted = 0
               AND guid IS NOT NULL
               AND guid NOT IN ({placeholders})
        """, seen_guids)
        marked_deleted = cur.rowcount

    conn.commit()
    return inserted, updated, marked_deleted


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bookmarks", default="Bookmarks.json", help="Путь к файлу Bookmarks.json")
    parser.add_argument("--db", default="edge.db", help="Путь к файлу базы данных SQLite (edge.db)")
    parser.add_argument("--folder", default=ROOT_FOLDER_NAME,
                         help='Название папки для импорта (по умолчанию: "Панель избранного")')
    args = parser.parse_args()

    bookmarks_path = Path(args.bookmarks)
    if not bookmarks_path.exists():
        sys.exit(f"Файл не найден: {bookmarks_path}")

    with open(bookmarks_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    root_folder = find_root_folder(data, args.folder)
    items = flatten_bookmarks(root_folder, parent_guid=None)

    if not items:
        print(f'В папке "{args.folder}" не найдено ни одной закладки/подпапки.')
        return

    conn = sqlite3.connect(args.db)
    try:
        ensure_table(conn)
        inserted, updated, marked_deleted = upsert_favorites(conn, items)
    finally:
        conn.close()

    n_folders = sum(1 for i in items if i["type"] == "folder")
    n_urls = sum(1 for i in items if i["type"] == "url")

    print(f'Папка: "{args.folder}"')
    print(f"Всего элементов в файле: {len(items)} (папок: {n_folders}, закладок: {n_urls})")
    print(f"Добавлено новых:         {inserted}")
    print(f"Обновлено существующих:  {updated}")
    print(f"Помечено удалёнными:     {marked_deleted}")
    print(f"База данных: {Path(args.db).resolve()}")


if __name__ == "__main__":
    main()