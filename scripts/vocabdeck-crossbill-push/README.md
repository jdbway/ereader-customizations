# vocabdeck-crossbill-push

Pushes VocabDeck's vocabulary cards (pulled off a real KOReader device's
`koreader/vocabdeck/<Language>.sqlite3` databases) straight into
[Crossbill](https://github.com/Crossbill-App/crossbill-web) via its REST
API. A one-shot migration script, not ongoing sync.

**Why this exists instead of using Crossbill's own `anki-addon`:** that
addon only goes *Crossbill → Anki* ("Import flash card questions from
Crossbill to Anki," straight from its README) — there's no path in it for
getting Anki (or VocabDeck) data *into* Crossbill. This script skips Anki
as an intermediate entirely and talks to Crossbill's REST API directly:

1. `POST /api/v1/auth/login` (OAuth2 password grant)
2. `GET /api/v1/books/` — resolve each VocabDeck card's book title to a
   Crossbill `book_id`
3. `POST /api/v1/notes` — one note per word, `kind: "term"` (a real enum
   value in Crossbill's schema, exactly the right fit for vocabulary
   entries), body = the full enrichment as markdown
4. `POST /api/v1/notes/{note_id}/flashcards` — a linked flashcard
   (question/answer), so the word shows up in Crossbill's own review UI too

Idempotent-ish: checks existing note titles per book first (via
`GET /api/v1/books/{book_id}/notes`) and skips anything already there, so
reruns after adding new VocabDeck words don't duplicate old ones.

```
python3 -m venv venv
./venv/bin/pip install requests
export CROSSBILL_URL=https://your-crossbill-instance.example.com
export CROSSBILL_USERNAME=your-username
export CROSSBILL_PASSWORD=your-password
./venv/bin/python3 push_to_crossbill.py
```

Reads from `data/vocabdeck/*.sqlite3` (gitignored — pull your own off the
device first, e.g. `scp`/`ssh ... tar` the `koreader/vocabdeck/` directory
down; same layout the
[vocabdeck-anki-export](https://github.com/jdbway/vocabdeck-anki-export)
repo's `export.py` reads).

## A real limitation worth knowing before relying on this

Crossbill's flashcard `answer` field only gets the plain `meaning` — the
richer enrichment (synonyms, memory hook, example sentence) lives on the
linked *Note*, not the flashcard itself. That's partly deliberate (a review
card cramming in everything defeats active recall) and partly just this
script's own choice — `note_body()` puts everything in the note, `answer`
stays lean. Adjust `answer` in `push_to_crossbill.py` if you want more of
the enrichment folded into the reviewable card.

Separately: Crossbill's own schema currently drops any *note* attached to a
*highlight* synced through the normal `crossbill.koplugin` path (a schema
redesign in
[crossbill-web#409](https://github.com/Crossbill-App/crossbill-web/pull/409)
removed the per-highlight note column) — tracked upstream in
[crossbill-web#592](https://github.com/Crossbill-App/crossbill-web/issues/592).
Doesn't affect this script (VocabDeck words go in as their own Notes, not
as highlight-attached notes), just worth knowing if you're also relying on
`crossbill.koplugin`'s highlight sync for annotations — see
`kindle/koreader-settings/crossbill-NOTE.md` in this repo.

## Where this fits in a bigger picture

See [jdbway/koreader-joplin-sync](https://github.com/jdbway/koreader-joplin-sync)
for the confirmed VocabDeck schema and the AI-note-vs-stock-note classifier
this reuses, and
[jdbway/vocabdeck-anki-export](https://github.com/jdbway/vocabdeck-anki-export)
for the sibling VocabDeck → Anki (`.apkg`) export script this one was split
out from.
