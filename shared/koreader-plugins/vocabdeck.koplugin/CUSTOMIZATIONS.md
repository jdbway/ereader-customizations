# Customizations vs. upstream

This fork deviates from [`yupmoon/vocabdeck.koplugin`](https://github.com/yupmoon/vocabdeck.koplugin)
(currently pinned to `v1.2.1`, the latest tagged release as of this writing)
in 7 files. Everything below was found and applied while getting VocabDeck to
work alongside the stock `vocabbuilder.koplugin`'s "Add to vocabulary
builder" button — see `kindle/koreader-plugins/README.md` (or the top-level
`kindle/README.md`) for why this plugin is vendored here instead of just
linked like `bookshelf`/`bookends`/`simpleui`.

Filed upstream, both open as of this writing — check these before assuming
this document is still accurate, since a future upstream release may fix or
supersede some of this:

- **Bugs**: [yupmoon/vocabdeck.koplugin#2](https://github.com/yupmoon/vocabdeck.koplugin/issues/2)
- **Design discussion / opinionated changes**: [yupmoon/vocabdeck.koplugin#3](https://github.com/yupmoon/vocabdeck.koplugin/issues/3)

## Bug fixes (not a matter of taste — upstream is objectively broken here)

### 1. Dictionary popup buttons never appeared at all

**File:** `main.lua`

Upstream listens for a `"DictButtonsReady"` event that `dictquicklookup.lua`
never actually fires on current KOReader (`v2026.07.2` as installed on this
Kindle) — checked `dictquicklookup.lua` and `readerdictionary.lua` directly,
no `Event:new("DictButtonsReady", ...)` anywhere. As shipped, "Add to VD" /
"VD +AI" / "Define (VD)" silently never show up in the dictionary popup. The
real, documented extension point — used by the stock `vocabbuilder.koplugin`
and documented in `dictquicklookup.lua`'s own header comment — is
`ReaderDictionary:addToDictButtons(spec)`. This fork uses that instead (see
"Consolidated dictionary popup button" below — the fix and a UX change
happened in the same edit).

### 2. `NetworkMgr:runWhenOnline()` takes ~20s to notice Wi-Fi is off

**Files:** `vocabdeck_ai_runner.lua`, `vocabdeck_bulk.lua`

`runWhenOnline()` checks `isOnline()` first, which does a real DNS
resolution and takes ~20s to time out before falling back to the "Do you
want to turn on Wi-Fi?" prompt — measured via timestamped logging while
debugging why adding a word with Wi-Fi off appeared to hang. This hits two
*independent* code paths: `AIRunner.run` (shared by "VD +AI," "Refetch AI
data," "AI memory helper") and, separately, `Bulk.fetchMissing`, since
`Enrich.bulkEnrich` calls the AI querier directly and bypasses `AIRunner`
entirely — fixing one doesn't fix the other.

Fix: a `runWhenOnlineFast(callback)` helper (duplicated in both files, no
shared module between them upstream) that checks `NetworkMgr:isWifiOn()`
first — a plain local radio-state check, no network round-trip. If Wi-Fi's
definitively off, it jumps straight to `NetworkMgr:promptWifiOn(callback)`
(the same prompt `runWhenOnline` would eventually reach anyway). If Wi-Fi is
on, it defers to the normal `runWhenOnline` (which still needs the real
`isOnline()` check there, not just radio state).

### 3. "Fetch AI data for all cards" only fetched for the current language tab

**File:** `vocabdeck_bulk.lua`

VocabDeck splits cards into one SQLite file per detected language
(`English.sqlite3`, `French.sqlite3`, etc., switched via `DB.setLanguage`).
The Actions-menu button is explicitly labeled "Fetch AI data for **all**
cards" when no `book_id` is given (`vocabdeck_card_filters.lua`), but
`Bulk.fetchMissing(plugin, nil, ...)` just called `DB.listPendingCards(nil)`
against whichever language happened to be `DB.active_language` at that
moment — with more than one language in the deck, this silently only
processed the currently open tab, contradicting its own label.

**This one is closer to a judgment call than the other two** — see
"Opinionated behavior changes" below; filed as a design question upstream
(#3, item 5), not purely as a bug.

## Opinionated behavior changes

Everything below is a real default/behavior change, not a bug fix — a
reasonable person could want the original per-action granularity or the
scoped/preserved behavior back instead. See vocabdeck.koplugin#3 for the
open question of whether any of this should go upstream as a new default, an
opt-in setting, or not at all.

### Consolidated dictionary popup button

**File:** `main.lua` — `registerDictButtons()`, `vocabDeckDefinition()`

The three separate buttons ("Add to VD" / "VD +AI" / "Define (VD)") are
replaced with one: **"VocabDeck Definition."** Online, it runs the existing
AI-define-and-preview flow (same as the old "Define (VD)"). Offline, it
skips straight to the plain add dialog rather than attempting AI at all
(same as the old "Add to VD"). Motivation: fewer buttons in an already
crowded dictionary popup — this device gets used by family members who don't
need three near-identical options to choose between.

The **highlight-menu** entries (Add to VD / Add to VD (Enriched) / Define
(VD) / Grammar (VD), registered separately in `main.lua`'s `onReaderReady`)
are **unchanged** — this only touches the dictionary popup.

### Preview screen matches Card Details' format, plus auto memory helper

**Files:** `vocabdeck_define.lua`, `vocabdeck_memory_helper.lua`

The definition preview (both the fresh-AI-fetch case and the
already-saved-card case) now reuses `Format.buildPreviewText` — the exact
function `vocabdeck_card_filters.lua`'s Card Details screen uses — so it
shows the same "✨ Enriched by AI" badge and field layout whether or not the
word has actually been saved yet.

It also auto-generates and appends the AI memory helper section (Morphology
/ Collocations / Memory hook / Example) inline, instead of requiring a
separate manual "AI memory helper" tap from Card Details. `MemoryHelper.generate`
is a new function alongside upstream's existing `MemoryHelper.showForCard` —
it does the same AI fetch without popping its own dialog, so the caller can
fold the result into one combined view. It also works for a card that isn't
saved yet (no `card.id`): generates ephemerally, no DB write, just sets
`ai_memory_helper` on the in-memory params table for that render. If "Add
Card" is tapped afterward, `main.lua`'s add-dialog callback wires up
`after_save` to persist it retroactively via `DB.updateCardMemoryHelper`,
since `_persistCard`'s own insert doesn't carry that field.

### Manual "Add new card" auto-enriches if online

**File:** `vocabdeck_manual_add.lua` — `afterManualSave` (replaces
upstream's `showFetchChoice`)

Used to show a "Fetch AI data now / Close" choice dialog after saving. Now
checks `NetworkMgr:isWifiOn()` and enriches immediately with no extra tap if
online; if offline, just tells you it's pending (picked up later by "Fetch
AI data for all cards," same as any other offline-added card).

### Stock "Add to vocabulary builder" button also adds to VocabDeck

**File:** `main.lua` — `hookVocabBuilderAdd()`, `captureFromVocabBuilder()`

The point of this one: tapping the *stock* KOReader dictionary button people
already know how to use also adds+enriches a VocabDeck card, so there's one
familiar action instead of teaching a family member a second app's UI.

Implementation note, since this took real effort to get right: the first
attempt listened for the `"WordLookedUp"` event the stock button fires
(`is_manual=true`) — that event travels through `ReaderUI`'s widget-tree
propagation (`WidgetContainer:propagateEvent`), which stops at the first
handler that returns `true`. `vocabbuilder.koplugin`'s own handler always
returns `true` on success and loads before `vocabdeck` alphabetically, so the
event never reached this plugin — confirmed by an empty `vocabdeck.sqlite3`
despite the stock button visibly working. The actual fix reaches into the
*already-loaded* `vocabbuilder.koplugin` instance (`self.ui.vocabbuilder`,
per `ReaderUI:registerModule` — the registration key comes from the plugin's
**folder name**, `vocabbuilder.koplugin` → `vocabbuilder`, not any field
declared in its own class table or `_meta.lua`) and wraps its
`onWordLookedUp` method at the *instance* level. Only that one object's
field is reassigned; `vocabbuilder.koplugin`'s file and class table are
never touched. One more gotcha along the way: KOReader wraps every
plugin-defined `on*` handler in a `HandlerSandbox` (`pluginloader.lua`) — a
callable *table* via `__call`, not a plain function — so a naive
`type(handler) == "function"` check incorrectly rejects it even though it's
fully callable the normal way.

Offline, capture happens silently (no card, no AI, just skipped) rather than
prompting — consistent with the "one familiar button, no extra decisions"
goal above.

### Empty per-language databases get pruned at startup

**Files:** `vocabdeck_db.lua` — `DB.pruneEmptyLanguages()`; `main.lua` —
called once from `VocabDeck:init()`

Deleting a card never checked whether it was the last one in its language,
so an emptied-out language's `.sqlite3` file just sat there forever, showing
as a permanent empty tab in the card list — confirmed still present after
several app restarts before this fix. `pruneEmptyLanguages()` deletes the
`.sqlite3` (+ `-wal`/`-shm`/`-backup` siblings) for any language with zero
cards, once at plugin init. Never touches the legacy (pre-language-split, nil
language) database. There's a real case for keeping a tab as history of
every language you've ever touched even when empty — see the open question
in vocabdeck.koplugin#3, item 6.

## Not covered here

Two files that came up while investigating the above were found to be
**unmodified** and don't need re-syncing beyond what's already in this
repo: everything in this fork's `main.lua`/`vocabdeck_bulk.lua`/etc. changes
is additive or targeted, not a wholesale rewrite — diffing against a fresh
`v1.2.1` download and confirming only the 7 files above differ is the fastest
way to re-verify this document is still accurate after a future re-sync.
