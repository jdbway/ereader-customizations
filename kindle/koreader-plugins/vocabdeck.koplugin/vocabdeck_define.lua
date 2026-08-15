-- AI Define flow for selected text and dictionary popup entries.
local _ = require("gettext")
local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")

local AIRunner = require("vocabdeck_ai_runner")
local DB = require("vocabdeck_db")
local Capture = require("vocabdeck_capture")
local Enrich = require("vocabdeck_enrich")
local Format = require("vocabdeck_card_format")
local MemoryHelper = require("vocabdeck_memory_helper")

local Define = {}

local DEFINE_CACHE_TTL = 300
local DEFINE_CACHE_MAX = 50
local define_cache = {}

local function defineCacheKey(phrase)
    return Capture.cleanText(phrase or ""):lower()
end

local function defineCacheGet(phrase)
    local key = defineCacheKey(phrase)
    local entry = define_cache[key]
    if entry and os.time() - entry.created_at <= DEFINE_CACHE_TTL then
        return entry.result
    end
    return nil
end

local function defineCacheSet(phrase, result)
    local key = defineCacheKey(phrase)
    if not define_cache[key] then
        local keys = {}
        for k in pairs(define_cache) do keys[#keys + 1] = k end
        if #keys >= DEFINE_CACHE_MAX then
            table.sort(keys, function(a, b)
                return (define_cache[a].created_at or 0) < (define_cache[b].created_at or 0)
            end)
            define_cache[keys[1]] = nil
        end
    end
    define_cache[key] = { result = result, created_at = os.time() }
end

function Define.install(VocabDeck)
    function VocabDeck:_showDefineFailure(params, message)
        local viewer
        local buttons = { {
            {
                text = _("Cancel"),
                callback = function()
                    UIManager:close(viewer)
                end,
            },
            {
                text = _("Save without meaning"),
                callback = function()
                    UIManager:close(viewer)
                    params.meaning = ""
                    params.ai_status = DB.STATUS_PENDING
                    self:_showAddDialog(params)
                end,
            },
        } }
        viewer = TextViewer:new{
            title = _("Define (VocabDeck)"),
            text = message or _("Could not fetch a definition."),
            buttons_table = buttons,
            add_default_buttons = false,
        }
        UIManager:show(viewer)
    end

    function VocabDeck:_applyDefineResult(params, result)
        local headword = Capture.cleanText(result.headword or "")
        if headword ~= "" then
            params.phrase = headword
        end
        params.meaning = Capture.cleanMeaning(result.meaning or "")
        params.synonym = Capture.cleanMeaning(result.synonym or "")
        params.pronunciation = Capture.cleanMeaning(result.pronunciation or "")
        params.word_type = Capture.cleanMeaning(result.word_type or "")
        local ai_lang = Capture.cleanMeaning(result.source_language or "")
        if (params.source_language or "") == "" or ai_lang ~= "" then
            params.source_language = self:resolveSourceLanguage{
                source_language = Capture.cleanMeaning(result.source_language or ""),
                dictionary_source_language = params.dictionary_source_language,
            }
        end
        if Capture.isPhrase(params.phrase) then
            params.pronunciation = ""
            if params.word_type == "" then
                params.word_type = "Phrase"
            end
        end
        params.ai_status = DB.STATUS_ENRICHED
        params.allow_update_existing = true
    end

    -- Builds the same text Card details uses (Format.buildPreviewText --
    -- phrase, word type/pronunciation, meaning, synonyms, context, note,
    -- book/added date, and the "✨ Enriched by AI" badge), so this popup
    -- reads exactly like a saved card whether or not it actually is one
    -- yet. Appends the AI memory helper's own sections (Morphology /
    -- Collocations / Memory hook / Example) verbatim when the card already
    -- has one generated -- that field is pre-formatted at generation time
    -- (see vocabdeck_memory_helper.lua's cleanText), so no reformatting
    -- needed here. TextViewer scrolls on its own when content runs long.
    local function buildPreviewParts(card)
        local parts = { Format.buildPreviewText(card) }
        if card.ai_memory_helper and card.ai_memory_helper ~= "" then
            parts[#parts + 1] = "✎ " .. _("Memory helper") .. "\n" .. card.ai_memory_helper
        end
        return table.concat(parts, "\n\n")
    end

    -- params has no card.id yet (not saved), so MemoryHelper.generate runs
    -- in its ephemeral mode here -- no DB write, just sets
    -- params.ai_memory_helper for this render. If "Add Card" is tapped
    -- afterward, after_save persists whatever got generated once a real
    -- card.id exists (DB.updateCardMemoryHelper) -- otherwise it would be
    -- silently discarded, since _persistCard's own insert doesn't carry
    -- ai_memory_helper.
    function VocabDeck:_showDefineResult(params, result)
        self:_applyDefineResult(params, result)

        local function render()
            local viewer
            local buttons = { {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(viewer)
                    end,
                },
                {
                    text = _("Add Card"),
                    callback = function()
                        UIManager:close(viewer)
                        if params.ai_memory_helper and params.ai_memory_helper ~= "" then
                            local helper_text = params.ai_memory_helper
                            local prior_after_save = params.after_save
                            params.after_save = function(card_id, ...)
                                if prior_after_save then prior_after_save(card_id, ...) end
                                DB.updateCardMemoryHelper(card_id, helper_text)
                            end
                        end
                        self:_showAddDialog(params)
                    end,
                },
            } }
            viewer = TextViewer:new{
                title = _("Define (VocabDeck)"),
                text = buildPreviewParts(params),
                buttons_table = buttons,
                add_default_buttons = false,
            }
            UIManager:show(viewer)
        end

        local NetworkMgr = require("ui/network/manager")
        if NetworkMgr:isWifiOn() then
            MemoryHelper.generate(self, params, function(helper_text)
                params.ai_memory_helper = helper_text or ""
                render()
            end)
        else
            render()
        end
    end

    -- Shown instead of running a fresh AI call when this phrase already has
    -- an enriched card sitting in the deck -- works offline too for the
    -- base definition, since nothing there needs the network. If the card
    -- doesn't have a memory helper yet, generates one automatically first
    -- (MemoryHelper.generate, no separate popup, no manual button needed)
    -- when online -- can only do this for a card that's already saved,
    -- since generation caches/persists by card.id, which a fresh unsaved
    -- lookup doesn't have.
    function VocabDeck:_showExistingCardResult(card)
        local function render()
            local viewer
            viewer = TextViewer:new{
                title = _("VocabDeck Definition"),
                text = buildPreviewParts(card),
                buttons_table = { {
                    {
                        text = _("Close"),
                        callback = function() UIManager:close(viewer) end,
                    },
                } },
                add_default_buttons = false,
            }
            UIManager:show(viewer)
        end

        local needs_memory_helper = not card.ai_memory_helper or card.ai_memory_helper == ""
        local NetworkMgr = require("ui/network/manager")
        if needs_memory_helper and NetworkMgr:isWifiOn() then
            MemoryHelper.generate(self, card, function(helper_text)
                card.ai_memory_helper = helper_text or ""
                render()
            end)
        else
            render()
        end
    end

    function VocabDeck:defineWithVocabDeck(params)
        if not params or not params.phrase or params.phrase == "" then
            UIManager:show(InfoMessage:new{ text = _("No word or phrase selected."), timeout = 3 })
            return
        end
        local book_id, err = self:_getBookId()
        if not book_id then
            UIManager:show(InfoMessage:new{ text = err, timeout = 3 })
            return
        end

        local cached = defineCacheGet(params.phrase)
        if cached then
            self:_showDefineResult(params, cached)
            return
        end

        AIRunner.run(self, {
            message = _("Defining... Tap outside to cancel."),
            phrase = params.phrase,
            work = function(trap)
                local anchored = Capture.anchorInfoMessageBottomLeft(trap)
                return Enrich.enrichCard(self, {
                    phrase = params.phrase,
                    ai_context = Capture.firstText(params.ai_context, params.sentence, params.display_context),
                    is_phrase = Capture.isPhrase(params.phrase),
                    source_language = "",  -- let AI detect independently
                }, anchored)
            end,
            on_error = function(define_err)
                self:_showDefineFailure(params, AIRunner.formatError(define_err or _("Unknown error")))
            end,
            on_success = function(result)
                result.meaning = Capture.cleanMeaning(result.meaning or "")
                result.synonym = Capture.cleanMeaning(result.synonym or "")
                if result.meaning == "" then
                    self:_showDefineFailure(params, _("VocabDeck did not receive a usable definition."))
                    return
                end
                defineCacheSet(params.phrase, result)
                self:_showDefineResult(params, result)
            end,
        })
    end

    function VocabDeck:defineFromHighlight(reader_highlight)
        local params = self:_buildHighlightCardParams(reader_highlight)
        if not params then
            return
        end
        self:_closeHighlightDialog(reader_highlight)
        self:defineWithVocabDeck(params)
    end

    function VocabDeck:defineFromDictionary(dict_popup)
        local params = self:_buildDictionaryCardParams(dict_popup)
        if params then
            self:defineWithVocabDeck(params)
        end
    end
end

return Define
