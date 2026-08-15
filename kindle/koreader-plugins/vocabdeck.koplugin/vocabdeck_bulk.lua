-- VocabDeck bulk enrichment workflow.
--
-- Handles "fetch missing info" actions without making main.lua own the
-- refetch prompt, network handoff, and batch call plumbing.
local _ = require("gettext")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local Trapper = require("ui/trapper")

local AIRunner = require("vocabdeck_ai_runner")
local DB = require("vocabdeck_db")
local Enrich = require("vocabdeck_enrich")

local Bulk = {}

-- NetworkMgr:runWhenOnline() checks isOnline() first, which does a real DNS
-- resolution and takes ~20s to time out when there's no connectivity at all
-- -- same slowness diagnosed for the "Add to vocabulary builder" hook, just
-- hit here via a different call path. When WiFi is definitively off,
-- isWifiOn() (a plain local state check) lets us skip straight to the same
-- "Do you want to turn on Wi-Fi?" prompt runWhenOnline would eventually
-- reach anyway, without the wait. When WiFi is already on, defer to the
-- normal runWhenOnline (isOnline() resolves quickly against a real
-- connection, and this still needs isOnline's actual-Internet check, not
-- just isWifiOn's radio-state check).
local function runWhenOnlineFast(callback)
    local NetworkMgr = require("ui/network/manager")
    if NetworkMgr:isWifiOn() then
        NetworkMgr:runWhenOnline(callback)
    else
        NetworkMgr:promptWifiOn(callback)
    end
end

-- Runs `step(language, done)` once per language DB (English, French, etc.,
-- from DB.listLanguages(), plus the pre-language-split legacy DB as
-- `false`), one at a time -- only one language's SQLite connection can be
-- active at once (DB.setLanguage switches it), so these can't run
-- concurrently. `step` must call `done(succeeded, failed)` when its
-- language is finished. Restores whatever language was active before this
-- ran, so it doesn't leave the user's card-list view on a different tab.
local function forEachLanguage(step, on_finished)
    local languages = DB.listLanguages()
    table.insert(languages, 1, false) -- false = legacy/no-language DB, checked first
    local original_language = DB.getActiveLanguage()

    local total_ok, total_fail = 0, 0
    local i = 0

    local function next_language()
        i = i + 1
        local lang = languages[i]
        if lang == nil then
            DB.setLanguage(original_language)
            if on_finished then on_finished(total_ok, total_fail) end
            return
        end
        DB.setLanguage(lang or nil)
        step(lang, function(ok, fail)
            total_ok = total_ok + (ok or 0)
            total_fail = total_fail + (fail or 0)
            next_language()
        end)
    end

    next_language()
end

-- Synchronous (local SQLite reads only, no network): total pending-card
-- count across every language DB, switching DB.setLanguage back and forth
-- and restoring it before returning. Used only to decide which prompt to
-- show -- DB.listPendingCards(nil) alone would just report whichever
-- language happened to be active, which is the exact bug being fixed here.
local function countPendingAllLanguages()
    local languages = DB.listLanguages()
    table.insert(languages, 1, false)
    local original_language = DB.getActiveLanguage()
    local total = 0
    for _, lang in ipairs(languages) do
        DB.setLanguage(lang or nil)
        total = total + #DB.listPendingCards(nil)
    end
    DB.setLanguage(original_language)
    return total
end

function Bulk.fetchMissing(plugin, book_id, on_finished)
    local provider_ok, provider_err = plugin:ensureAIProviderLoaded()
    if not provider_ok then
        UIManager:show(InfoMessage:new{
            text = AIRunner.formatError(provider_err),
            timeout = 4,
        })
        if on_finished then on_finished(0, 0) end
        return
    end

    -- A specific book_id means "this book" (from a single book's card
    -- view) -- stays scoped to the currently active language's DB, as
    -- before. No book_id means "all cards" -- now genuinely all, looping
    -- every language DB rather than just whichever one happened to be
    -- active when the Actions menu was opened.
    if not book_id then
        if countPendingAllLanguages() == 0 then
            UIManager:show(ConfirmBox:new{
                text = _("All cards already have AI info. Refetch AI data anyway?"),
                ok_text = _("Refetch"),
                ok_callback = function()
                    runWhenOnlineFast(function()
                        Trapper:wrap(function()
                            forEachLanguage(function(_lang, done)
                                Enrich.bulkEnrich(plugin, DB.listCardsForRefetch(nil), done)
                            end, on_finished)
                        end)
                    end)
                end,
            })
            return
        end

        runWhenOnlineFast(function()
            Trapper:wrap(function()
                forEachLanguage(function(_lang, done)
                    Enrich.bulkEnrich(plugin, DB.listPendingCards(nil), done)
                end, on_finished)
            end)
        end)
        return
    end

    local cards = DB.listPendingCards(book_id)
    if #cards == 0 then
        UIManager:show(ConfirmBox:new{
            text = _("All cards already have AI info. Refetch AI data anyway?"),
            ok_text = _("Refetch"),
            ok_callback = function()
                local refetch_cards = DB.listCardsForRefetch(book_id)
                if #refetch_cards == 0 then
                    UIManager:show(InfoMessage:new{
                        text = _("No cards found."),
                        timeout = 3,
                    })
                    if on_finished then on_finished(0, 0) end
                    return
                end
                runWhenOnlineFast(function()
                    Trapper:wrap(function()
                        Enrich.bulkEnrich(plugin, refetch_cards, on_finished)
                    end)
                end)
            end,
        })
        return
    end

    runWhenOnlineFast(function()
        Trapper:wrap(function()
            Enrich.bulkEnrich(plugin, cards, on_finished)
        end)
    end)
end

return Bulk
