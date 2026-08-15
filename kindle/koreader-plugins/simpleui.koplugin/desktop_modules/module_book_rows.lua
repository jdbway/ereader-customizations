-- module_book_rows.lua — Simple UI
-- Módulos "linha de capas" simples (não instanciáveis): Recent Books,
-- New Books e TBR (To Be Read). Todos construídos sobre
-- RowRenderer.makeModule (sui_book_row.lua) — cada um fica reduzido à sua
-- diferença real: fonte da lista, filtro por item, e extras de menu.
--
-- Um único require_mod devolve os três módulos via M.sub_modules — suportado
-- nativamente por moduleregistry.lua's _load(), sem necessidade de alterações
-- ao registry. Ver sui_book_row.lua para a API completa do makeModule.
--
-- TBR: o registo do módulo "linha de capas" vive aqui, mas a camada de
-- dados/API pública (addTBR, removeTBR, isTBR, getTBRList, migração,
-- genTBRButton, ...) fica em module_tbr.lua, porque é consumida via
-- require("desktop_modules/module_tbr") / package.loaded[...] a partir de
-- main.lua, sui_patches.lua, module_coverdeck.lua e module_collections.lua —
-- mudar esse caminho quebraria todos esses sítios.
--
-- Collection Row (module_coll_row.lua) mantém-se em ficheiro próprio: é
-- instanciável (o utilizador pode ter várias instâncias, uma por coleção) —
-- não encaixa no formato "sub_modules" de um módulo singleton simples.

local Device      = require("device")
local lfs          = require("libs/libkoreader-lfs")
local _ = require("sui_i18n").translate

local SUISettings = require("sui_store")
local RowRenderer = require("desktop_modules/sui_book_row")
local TBR         = require("desktop_modules/module_tbr")

-- =============================================================================
-- Recent Books
-- =============================================================================

local recent_module = RowRenderer.makeModule{
    id          = "recent",
    name        = _("Recent Books"),
    label       = _("Recent Books"),
    default_on  = false,
    is_book_mod = true,   -- suppresses empty-state when active
    max_items   = 5,

    getFileList = function(ctx) return ctx.recent_fps end,

    -- Exclui livros terminados, a menos que "Show finished books" esteja
    -- ligado (setting própria do módulo, independente da lógica de recência
    -- que produziu ctx.recent_fps).
    filterItem = function(fp, ctx)
        local pfx = ctx.pfx or ""
        if SUISettings:readSetting(pfx .. "recent_show_finished") == true then return true end
        local pd  = ctx.prefetched and ctx.prefetched[fp]
        local pct = pd and pd.percent or 0
        local is_done = (pct >= 1.0) or
                        (type(pd) == "table" and type(pd.summary) == "table"
                         and pd.summary.status == "complete")
        return not is_done
    end,

    toggles = { progress = "on", text = "on", overlay = "off" },

    extra_settings = {
        { key = "show_finished", label = _("Show finished books"), default = false },
    },

    reset = function() RowRenderer.reset() end,
}

-- =============================================================================
-- New Books — recentemente adicionados à biblioteca (por data de ficheiro)
-- =============================================================================

local _BOOK_EXTS = {
    epub = true, mobi = true, azw3 = true, azw = true, kfx = true,
    pdf = true, djvu = true, fb2 = true, cbz = true, cbr = true,
    doc = true, docx = true, rtf = true, txt = true,
}

--- Recursively scan `dir` for book files, collecting path + mtime.
local function collectBooks(dir, files, depth, state)
    if depth > 5 or state.count > 5000 then return end
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return end
    for f in iter, dir_obj do
        state.count = state.count + 1
        if state.count > 5000 then break end
        if f ~= "." and f ~= ".." and not f:match("^%.") then
            local path = dir .. "/" .. f
            local attr = lfs.attributes(path)
            if attr then
                if attr.mode == "file" then
                    local ext = f:match("%.([^%.]+)$")
                    if ext and _BOOK_EXTS[ext:lower()] then
                        files[#files + 1] = { path = path, mtime = attr.modification }
                    end
                elseif attr.mode == "directory" then
                    collectBooks(path, files, depth + 1, state)
                end
            end
        end
    end
end

--- Return up to `limit` file paths from home_dir, newest first by mtime.
local function scanNewBooks(limit)
    limit = limit or 5
    local home = G_reader_settings:readSetting("home_dir")
    if not home or home == "" then home = Device.home_dir end
    if not home then return {} end

    local files = {}
    collectBooks(home, files, 1, { count = 0 })
    table.sort(files, function(a, b) return a.mtime > b.mtime end)

    local result = {}
    for i = 1, math.min(limit, #files) do
        result[i] = files[i].path
    end
    return result
end

-- Cache do scan (I/O pesado — percorre a home_dir recursivamente), TTL 5min.
local _cached_new_fps      = nil
local _cached_new_fps_time = 0

--- Fetches 15 candidates (compensando os que o filtro vai excluir) com cache
--- de 5 minutos entre scans do disco.
local function getNewBooksCandidates()
    local now = os.time()
    if _cached_new_fps and (now - _cached_new_fps_time < 300) then
        return _cached_new_fps
    end
    local fps = scanNewBooks(15)
    _cached_new_fps      = fps
    _cached_new_fps_time = now
    return fps
end

local new_books_module = RowRenderer.makeModule{
    id          = "new_books",
    name        = _("New Books"),
    label       = _("New Books"),
    default_on  = false,  -- opt-in; users enable via Arrange Modules
    max_items   = 5,

    getFileList = function(_ctx) return getNewBooksCandidates() end,

    -- Exclui o livro atualmente aberto e livros 100% lidos/completos —
    -- mesma lógica de filtragem usada por prefetchBooks() em
    -- module_books_shared.lua, com fallback para leitura direta do
    -- DocSettings quando o livro ainda não está em ctx.prefetched.
    filterItem = function(fp, ctx)
        if fp == ctx.current_fp then return false end
        local pct, is_complete = 0, false
        local pre = ctx.prefetched and ctx.prefetched[fp]
        if pre and pre ~= false then
            pct = pre.percent or 0
            is_complete = type(pre.summary) == "table" and pre.summary.status == "complete"
        else
            local ok, DS = pcall(require, "docsettings")
            if ok and DS then
                local ok2, ds = pcall(DS.open, DS, fp)
                if ok2 and ds then
                    pct = ds:readSetting("percent_finished") or 0
                    local summary = ds:readSetting("summary")
                    is_complete = type(summary) == "table" and summary.status == "complete"
                    pcall(function() ds:close() end)
                end
            end
        end
        return pct < 1.0 and not is_complete
    end,

    -- Sempre visível, sem toggle no menu: "New" para não iniciados, senão
    -- a percentagem lida.
    toggles = { progress = "locked_on", text = "locked_on", overlay = "locked_off" },
    labelForItem = function(bd)
        if (bd.percent or 0) < 0.01 then return _("New") end
        return string.format(_("%d%% Read"), math.floor((bd.percent or 0) * 100 + 0.5))
    end,

    reset = function()
        RowRenderer.reset()
        _cached_new_fps      = nil
        _cached_new_fps_time = 0
    end,
}

-- Preservado como API pública (não é chamado internamente por este ficheiro,
-- mas outros módulos/versões futuras podem querer forçar um rescan).
function new_books_module.invalidateCache()
    _cached_new_fps      = nil
    _cached_new_fps_time = 0
end

-- =============================================================================
-- TBR (To Be Read) — dados/API pública em module_tbr.lua; registo do módulo
-- "linha de capas" aqui, ao lado de Recent/New Books. `paged = true` tira o
-- antigo limite de 5 livros: com mais de max_items (5) na lista, a linha
-- pagina por swipe em vez de cortar o resto, tal como o Collection Row.
-- =============================================================================

local tbr_module = RowRenderer.makeModule{
    id          = "tbr",
    name        = _("To Be Read"),
    label       = _("To Be Read"),
    default_on  = false,
    is_book_mod = true,   -- necessário para o repaint cirúrgico do swipe
    max_items   = 5,
    paged       = true,
    cache_key   = "_tbr_fps",   -- partilhado com module_coverdeck.lua
    getFileList = TBR.getTBRList,
    extra_menu_items_before = TBR.arrangeMenuItems,

    reset = function() RowRenderer.reset() end,
}

-- =============================================================================
-- Export
-- =============================================================================

local M = {}
M.sub_modules = { recent_module, new_books_module, tbr_module }
return M
