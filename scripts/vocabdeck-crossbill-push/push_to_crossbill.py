#!/usr/bin/env python3
"""
Pushes VocabDeck's card data straight into Crossbill as Notes (kind="term")
+ one linked Flashcard each. This is the actual VocabDeck -> Crossbill path --
Crossbill's own anki-addon only goes Crossbill -> Anki, not the reverse, so
this bypasses Anki entirely and hits Crossbill's API directly, reading the
same data/vocabdeck/*.sqlite3 export the vocabdeck-anki-export repo reads.

Idempotent-ish: skips a word if a note with that exact title already exists
in the target book, so reruns after adding new VocabDeck words don't
duplicate old ones.
"""
import os
import sqlite3
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent
DB_DIR = ROOT / "data" / "vocabdeck"
BASE_URL = os.environ.get("CROSSBILL_URL", "https://crossbill.truepob.com")
USERNAME = os.environ.get("CROSSBILL_USERNAME")
PASSWORD = os.environ.get("CROSSBILL_PASSWORD")

if not USERNAME or not PASSWORD:
    sys.exit(
        "Set CROSSBILL_USERNAME and CROSSBILL_PASSWORD in the environment "
        "before running this (never hardcode them here)."
    )


def login():
    resp = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        data={"username": USERNAME, "password": PASSWORD, "grant_type": "password"},
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def get_books(session):
    resp = session.get(f"{BASE_URL}/api/v1/books/", params={"limit": 200})
    resp.raise_for_status()
    return {b["title"]: b["id"] for b in resp.json()["items"]}


def get_existing_note_titles(session, book_id):
    resp = session.get(f"{BASE_URL}/api/v1/books/{book_id}/notes")
    resp.raise_for_status()
    data = resp.json()
    items = data.get("items", data) if isinstance(data, dict) else data
    return {n["title"] for n in items}


def note_body(row):
    parts = []
    meta = []
    if row["word_type"]:
        meta.append(f"*{row['word_type']}*")
    if row["pronunciation"]:
        meta.append(f"/{row['pronunciation']}/")
    if meta:
        parts.append(" ".join(meta))
    if row["meaning"]:
        parts.append(row["meaning"])
    if row["synonym"]:
        parts.append(f"**Synonyms:** {row['synonym']}")
    if row["sentence"]:
        parts.append(f"> {row['sentence']}")
    if row["ai_memory_helper"]:
        parts.append(row["ai_memory_helper"])
    return "\n\n".join(parts)


def main():
    session = requests.Session()
    token = login()
    session.headers["Authorization"] = f"Bearer {token}"
    print("Logged in to Crossbill.")

    books_by_title = get_books(session)
    print(f"Crossbill books: {list(books_by_title.keys())}")

    note_title_cache = {}  # book_id -> set of existing note titles
    created, skipped_dupe, skipped_no_book = 0, 0, 0

    for db_path in sorted(DB_DIR.glob("*.sqlite3")):
        language = db_path.stem
        if language == "vocabdeck":
            continue

        conn = sqlite3.connect(str(db_path))
        conn.row_factory = sqlite3.Row
        books = {row["id"]: row["title"] for row in conn.execute("SELECT id, title FROM books")}
        rows = conn.execute("SELECT * FROM cards").fetchall()
        conn.close()

        for row in rows:
            book_title = books.get(row["book_id"])
            crossbill_book_id = books_by_title.get(book_title)
            if crossbill_book_id is None:
                print(f"SKIP (no matching Crossbill book '{book_title}'): {row['phrase']}")
                skipped_no_book += 1
                continue

            if crossbill_book_id not in note_title_cache:
                note_title_cache[crossbill_book_id] = get_existing_note_titles(session, crossbill_book_id)
            if row["phrase"] in note_title_cache[crossbill_book_id]:
                skipped_dupe += 1
                continue

            note_resp = session.post(
                f"{BASE_URL}/api/v1/notes",
                json={
                    "title": row["phrase"],
                    "body": note_body(row),
                    "kind": "term",
                    "book_id": crossbill_book_id,
                },
            )
            note_resp.raise_for_status()
            note_id = note_resp.json()["note"]["id"]
            note_title_cache[crossbill_book_id].add(row["phrase"])

            if row["meaning"]:
                fc_resp = session.post(
                    f"{BASE_URL}/api/v1/notes/{note_id}/flashcards",
                    json={
                        "question": f"What does \"{row['phrase']}\" mean?",
                        "answer": row["meaning"],
                    },
                )
                fc_resp.raise_for_status()

            created += 1
            print(f"Created: {row['phrase']} -> book_id={crossbill_book_id}, note_id={note_id}")

    print(f"\nDone. Created {created}, skipped {skipped_dupe} duplicates, "
          f"{skipped_no_book} had no matching Crossbill book.")


if __name__ == "__main__":
    main()
