-- VocabDeck plugin entry point.
--
-- Responsibilities:
--   * Plugin lifecycle (init / onReaderReady / onFlushSettings).
--   * Injecting the "VocabDeck" action into the highlight menu and the
--     dictionary popup.
--   * Registering the main menu under the `tools` sorting hint.
--   * Instantiating the AI querier from vocabdeck_configuration.lua.
local _ = require("gettext")
local DataStorage = require("datastorage")
local InputContainer = require("ui/widget/container/inputcontainer")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local koutil = require("util")
local logger = require("logger")

local DB = require("vocabdeck_db")
local Bulk = require("vocabdeck_bulk")
local MenuBuilder = require("vocabdeck_menu")
local Querier = require("vocabdeck_ai")
local Stats = require("vocabdeck_stats")
local Config = require("vocabdeck_config")
local Context = require("vocabdeck_context")
local Add = require("vocabdeck_add")
local Define = require("vocabdeck_define")
local Grammar = require("vocabdeck_grammar")
local StudyEntry = require("vocabdeck_study_entry")
local Enrich = require("vocabdeck_enrich")

local SETTINGS_FILE = DataStorage:getSettingsDir() .. "/vocabdeck.lua"
local PLUGIN_VERSION = "1.2.0"

local CONFIGURATION, CONFIG_ERROR = Config.load()

-- ── Plugin definition ────────────────────────────────────────────────────

local VocabDeck = InputContainer:extend{
    name = "vocabdeck",
    is_doc_only = false,
    CONFIGURATION = nil,
    settings = nil,
    querier = nil,
}

Context.install(VocabDeck)
Add.install(VocabDeck)
Define.install(VocabDeck)
Grammar.install(VocabDeck)
StudyEntry.install(VocabDeck)

function VocabDeck:readSetting(key, default)
    if not self.settings then
        self.settings = LuaSettings:open(SETTINGS_FILE)
    end
    local val = self.settings:readSetting(key)
    if val == nil then return default end
    return val
end

function VocabDeck:saveSetting(key, value)
    if not self.settings then
        self.settings = LuaSettings:open(SETTINGS_FILE)
    end
    self.settings:saveSetting(key, value)
    -- Flush is deferred to onFlushSettings (called periodically by KOReader)
    -- to avoid unnecessary flash write cycles on e-ink devices.
end

function VocabDeck:onFlushSettings()
    if self.settings then
        self.settings:flush()
    end
end

function VocabDeck:getDefaultProvider()
    local config = self.CONFIGURATION
    if not config then return nil end
    if config.provider and koutil.tableGetValue(config, "provider_settings", config.provider) then
        return config.provider
    end
    if type(config.provider_settings) == "table" then
        for name, _settings in pairs(config.provider_settings) do
            return name
        end
    end
    return nil
end

function VocabDeck:getActiveProvider()
    return self.settings:readSetting("provider") or self:getDefaultProvider()
end

function VocabDeck:ensureAIProviderLoaded()
    if not self.querier then
        return false, _("Configure vocabdeck_configuration.lua with a valid AI provider first.")
    end
    local provider = self:getActiveProvider()
    if not provider or provider == "" then
        return false, _("Configure vocabdeck_configuration.lua with a valid AI provider first.")
    end
    if self.querier.provider_name == provider and self.querier:isInited() then
        return true
    end
    local ok, err = self.querier:loadProvider(provider)
    if not ok then
        return false, err or _("Configure vocabdeck_configuration.lua with a valid AI provider first.")
    end
    return true
end

-- ── Bulk operations ──────────────────────────────────────────────────────

function VocabDeck:bulkFetchMissing(book_id, on_finished)
    return Bulk.fetchMissing(self, book_id, on_finished)
end

function VocabDeck:showSummary()
    Stats.show(self)
end

-- ── Menu ─────────────────────────────────────────────────────────────────

function VocabDeck:addToMainMenu(menu_items)
    menu_items.vocabdeck = {
        sorting_hint = "tools",
        text = _("VocabDeck"),
        sub_item_table_func = function() return self:_buildMenu() end,
    }
end

function VocabDeck:_buildMenu()
    return MenuBuilder.build(self, CONFIG_ERROR, PLUGIN_VERSION)
end

-- ── Lifecycle ────────────────────────────────────────────────────────────

function VocabDeck:init()
    DB.init()
    DB.pruneEmptyLanguages()
    self.settings = LuaSettings:open(SETTINGS_FILE)
    if self.settings:readSetting("card_list_sort") == nil then
        self.settings:saveSetting("card_list_sort", "added")
    end
    if self.settings:readSetting("card_list_sort_dir") == nil then
        self.settings:saveSetting("card_list_sort_dir", "desc")
    end
    self.settings:flush()
    self.CONFIGURATION = CONFIGURATION

    if self.ui and self.ui.menu and self.ui.menu.registerToMainMenu then
        self.ui.menu:registerToMainMenu(self)
    end

    if CONFIGURATION then
        self.querier = Querier:new{ plugin = self }
    end
end

function VocabDeck:onReaderReady()
    if not self.ui then return end

    -- Highlight menu entry.
    if self.ui.highlight and self.ui.highlight.addToHighlightDialog then
        self.ui.highlight:addToHighlightDialog("vocabdeck_add", function(reader_highlight)
            return {
                text = _("Add to VD"),
                callback = function()
                    self:addFromHighlight(reader_highlight)
                end,
            }
        end)
        self.ui.highlight:addToHighlightDialog("vocabdeck_add_ai", function(reader_highlight)
            return {
                text = _("Add to VD (Enriched)"),
                callback = function()
                    self:addWithAIFromHighlight(reader_highlight)
                end,
            }
        end)
        self.ui.highlight:addToHighlightDialog("vocabdeck_define", function(reader_highlight)
            return {
                text = _("Define (VD)"),
                callback = function()
                    self:defineFromHighlight(reader_highlight)
                end,
            }
        end)
        self.ui.highlight:addToHighlightDialog("vocabdeck_grammar", function(reader_highlight)
            return {
                text = _("Grammar (VD)"),
                callback = function()
                    self:grammarFromHighlight(reader_highlight)
                end,
            }
        end)
    end

    self:registerDictButtons()
    self:hookVocabBuilderAdd()
end

-- Dictionary popup integration, via the documented extension point in
-- dictquicklookup.lua (ReaderDictionary:addToDictButtons). Registered once
-- self.ui.dictionary exists (onReaderReady, same as the highlight dialog
-- entries above) rather than the "DictButtonsReady" event this used to
-- listen for, which dictquicklookup.lua never actually fires on this
-- KOReader build -- the handler was silently dead code.
--
-- Originally three separate buttons (Add to VD / VD +AI / Define (VD)) --
-- consolidated into one so the popup stays simple: online, it runs the
-- existing AI-define-and-preview flow (defineWithVocabDeck, same as the
-- old Define (VD)); offline, it skips straight to the plain add dialog
-- (same as the old Add to VD) rather than attempting AI at all.
function VocabDeck:registerDictButtons()
    if not self.ui or not self.ui.dictionary then return end

    self.ui.dictionary:addToDictButtons({
        id = "vocabdeck_definition",
        menu_text = _("VocabDeck Definition"),
        text = _("VocabDeck Definition"),
        font_bold = true,
        insert_first = true,
        callback = function(dict_popup)
            self:vocabDeckDefinition(dict_popup)
        end,
    })
end

-- Checks for an already-enriched existing card before doing anything
-- network-related: if this phrase is already in the deck with real AI data,
-- just show it (_showExistingCardResult, works offline, no wasted API
-- call). Otherwise falls through to the online/offline split as before.
function VocabDeck:vocabDeckDefinition(dict_popup)
    local params = self:_buildDictionaryCardParams(dict_popup)
    logger.info("VD-DEF: called, params=", params and params.phrase or "nil")
    if not params then return end

    local source_language = self:resolveSourceLanguage(params)
    if source_language ~= "" then params.source_language = source_language end
    logger.info("VD-DEF: source_language=", source_language)
    local book_id = self:_getBookId(params)
    logger.info("VD-DEF: book_id=", tostring(book_id))
    if book_id then
        local existing = DB.findDuplicateCard(book_id, params.phrase, source_language)
        logger.info("VD-DEF: existing=", tostring(existing), "ai_status=", existing and tostring(existing.ai_status) or "n/a")
        if existing and existing.ai_status == DB.STATUS_ENRICHED then
            logger.info("VD-DEF: showing existing card result")
            self:_showExistingCardResult(existing)
            return
        end
    end

    local NetworkMgr = require("ui/network/manager")
    local wifi_on = NetworkMgr:isWifiOn()
    logger.info("VD-DEF: isWifiOn=", tostring(wifi_on))
    if wifi_on then
        logger.info("VD-DEF: calling defineWithVocabDeck")
        self:defineWithVocabDeck(params)
    else
        logger.info("VD-DEF: calling _showAddDialog (offline)")
        self:_showAddDialog(params)
    end
end

-- Hook the stock "Add to vocabulary builder" button without editing
-- vocabbuilder.koplugin's file. First attempt listened for the
-- "WordLookedUp" event it fires (is_manual=true) on a manual tap -- that
-- event travels through ReaderUI's widget-tree propagation
-- (WidgetContainer:propagateEvent), which stops at the FIRST handler that
-- returns true. vocabbuilder.koplugin's own onWordLookedUp always returns
-- true on a successful add, and it loads before vocabdeck alphabetically,
-- so the event never reached us -- confirmed by an empty vocabdeck.sqlite3
-- despite the stock button visibly working.
--
-- Instead, reach into the already-loaded vocabbuilder module instance
-- (self.ui.vocabbuilder, per ReaderUI:registerModule) and wrap its
-- onWordLookedUp method at the INSTANCE level -- only this one object's
-- field is reassigned; vocabbuilder.koplugin's file and class table are
-- untouched. The wrapper always calls the original first (unchanged stock
-- behavior, including its own "already exists" dialog), then captures into
-- VocabDeck afterward, AI-enriching if a provider is configured.
function VocabDeck:hookVocabBuilderAdd()
    logger.info("VD-HOOK: hookVocabBuilderAdd called")
    if not self.ui then
        logger.info("VD-HOOK: no self.ui, bailing")
        return
    end
    if not self.ui.vocabbuilder then
        logger.info("VD-HOOK: self.ui.vocabbuilder is nil, bailing")
        return
    end
    local vb = self.ui.vocabbuilder
    if vb._vocabdeck_hooked then
        logger.info("VD-HOOK: already hooked, skipping")
        return
    end
    vb._vocabdeck_hooked = true

    -- KOReader wraps every plugin-defined on* handler in a HandlerSandbox
    -- (pluginloader.lua) for stack-trace purposes -- a TABLE with a __call
    -- metamethod, not a plain function. It's still invoked exactly like a
    -- function (original(vb_self, ...) already dispatches through __call
    -- correctly), so only nil is actually unusable here.
    local original = vb.onWordLookedUp
    logger.info("VD-HOOK: original onWordLookedUp type is", type(original))
    if original == nil then return end
    local vocabdeck = self

    vb.onWordLookedUp = function(vb_self, word, title, is_manual)
        logger.info("VD-HOOK: wrapper fired, word=", word, "is_manual=", tostring(is_manual))
        local result = original(vb_self, word, title, is_manual)
        if is_manual and word and word ~= "" then
            logger.info("VD-HOOK: calling captureFromVocabBuilder for", word)
            vocabdeck:captureFromVocabBuilder(word)
        end
        return result
    end
    logger.info("VD-HOOK: wrapper installed successfully")
end

-- Same context capture vocabbuilder itself uses for its own prev/next
-- snippet (self.ui.highlight:getSelectedWordContext), then run through VD's
-- own Enrich helpers (Enrich.buildContextWindows / Enrich.extractSentence --
-- the same two calls Enrich.captureContexts makes) so cards added via the
-- stock button get a real "Source sentence" / "Surrounding context" like
-- cards added via VD's own buttons, instead of blank fields.
function VocabDeck:captureFromVocabBuilder(word)
    logger.info("VD-HOOK: captureFromVocabBuilder entered for", word)

    local sentence, ai_context, display_context = "", "", ""
    if self.ui and self.ui.highlight and self.ui.highlight.getSelectedWordContext then
        local ai_words = tonumber(self.settings:readSetting("ai_context_words", 15)) or 15
        local display_words = tonumber(self.settings:readSetting("display_context_words", 15)) or 15
        local max_words = math.max(ai_words, display_words, 10)
        local ok, prev_ctx, next_ctx = pcall(
            self.ui.highlight.getSelectedWordContext,
            self.ui.highlight,
            max_words
        )
        logger.info("VD-HOOK: getSelectedWordContext ok=", tostring(ok), "prev=", tostring(prev_ctx), "next=", tostring(next_ctx))
        if ok then
            ai_context, display_context = Enrich.buildContextWindows(word, prev_ctx, next_ctx, ai_words, display_words)
            sentence = Enrich.extractSentence(word, prev_ctx, next_ctx)
        end
    end

    local params = {
        phrase = word,
        sentence = sentence,
        ai_context = ai_context,
        display_context = display_context,
        source_language = self:resolveSourceLanguage(),
        ai_status = DB.STATUS_PENDING,
    }

    -- _defineAndAutoSave -> AIRunner.run -> NetworkMgr:runWhenOnline(...),
    -- which doesn't fail when offline, it WAITS indefinitely for
    -- connectivity -- that's the original "hangs with WiFi off" behavior.
    -- First attempt at a fix used NetworkMgr:isOnline(), which does a real
    -- DNS resolution and took ~20s to time out and report offline -- traded
    -- an indefinite hang for a bounded-but-still-slow one (confirmed via
    -- the VD-HOOK timestamps: ensureAIProviderLoaded to isOnline()=false
    -- was a consistent 20s gap). isWifiOn() is a plain local state check,
    -- no network round-trip -- same approach vocabdeck_updater.lua already
    -- uses elsewhere in this plugin. The card still lands in VD
    -- immediately either way; "Fetch AI data for all cards" (Actions menu)
    -- picks up ai_status=PENDING cards like this one once you're online.
    local ok, err = self:ensureAIProviderLoaded()
    logger.info("VD-HOOK: ensureAIProviderLoaded ok=", tostring(ok), "err=", tostring(err))
    if ok then
        local NetworkMgr = require("ui/network/manager")
        local wifi_on = NetworkMgr:isWifiOn()
        logger.info("VD-HOOK: NetworkMgr:isWifiOn()=", tostring(wifi_on))
        if not wifi_on then
            ok = false
        end
    end
    if ok then
        logger.info("VD-HOOK: calling _defineAndAutoSave")
        self:_defineAndAutoSave(params)
    else
        logger.info("VD-HOOK: calling _persistCard directly")
        local card_id = self:_persistCard(params.phrase, "", params)
        logger.info("VD-HOOK: _persistCard returned", tostring(card_id))
    end
end

return VocabDeck
