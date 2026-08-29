-- module_coll_row.lua — Simple UI
-- Módulo: Collection Row (instâncias dinâmicas).
--
-- Igual ao TBR/Recent/New Books na forma de apresentação (linha horizontal
-- de até 5 capas — motor partilhado em sui_book_row.lua), mas cada instância
-- está ligada a QUALQUER coleção existente no ReadCollection, escolhida
-- pelo utilizador — não apenas "To Be Read".
--
-- Diferença para module_collections.lua: aquele é uma grelha com até 5
-- coleções diferentes ao mesmo tempo (1 capa por coleção). Este módulo é
-- o inverso: 1 coleção, várias capas — e, tal como o Quick Actions Row,
-- podes ter N instâncias na tua homescreen (uma por coleção que quiseres
-- destacar).
--
-- Expõe M.instanciable = true e M.makeInstance(id) para o registry.
-- Instâncias persistem em "simpleui_coll_row_instances" (M.instances_key).
--
-- NOTA IMPORTANTE (moduleregistry / sui_settings_window):
-- o id base termina em "_row" de propósito — Registry.createInstance gera
-- ids como "coll_row_a1b2c3", que contêm a substring "_row_" usada em
-- sui_settings_window.lua para distinguir instâncias de módulos singleton.
-- Ver a nota em moduleregistry.lua se este padrão for alterado no futuro.

local _  = require("sui_i18n").translate

local CenterContainer = require("ui/widget/container/centercontainer")
local Font            = require("ui/font")
local Geom            = require("ui/geometry")

local SUISettings = require("sui_store")
local SUIStyle    = require("sui_style")
local UI          = require("sui_core")
local RowRenderer = require("desktop_modules/sui_book_row")

local PAD = UI.PAD

local MAX_ITEMS = 5

-- ---------------------------------------------------------------------------
-- ReadCollection accessor (lazy, igual ao padrão do module_tbr.lua)
-- ---------------------------------------------------------------------------
local function getRC()
    local ok, rc = pcall(require, "readcollection")
    return ok and rc or nil
end

-- Nome da coleção do TBR (module_tbr.lua) — excluído do seletor de coleções
-- deste módulo, já que o TBR tem a sua própria instância/módulo dedicado e
-- não faz sentido poder ser escolhido também aqui.
local function getTBRCollName()
    local ok, TBR = pcall(require, "desktop_modules/module_tbr")
    return ok and TBR and TBR.TBR_COLL_NAME or nil
end

-- ---------------------------------------------------------------------------
-- Instance factory
-- ---------------------------------------------------------------------------
local function makeInstance(inst_id)
    local COLL_KEY = inst_id .. "_coll_name"

    local function getCollName(pfx)
        return SUISettings:readSetting(pfx .. COLL_KEY)
    end
    local function setCollName(pfx, name)
        SUISettings:saveSetting(pfx .. COLL_KEY, name)
    end

    -- Nome a mostrar quando a coleção-alvo já não existe (apagada fora do
    -- SimpleUI) ou ainda não foi escolhida.
    local function displayName(pfx)
        local name = getCollName(pfx)
        if not name then return _("Collection Row — tap to configure") end
        local RC = getRC()
        if RC then
            -- Not calling RC:_read() — it destructively reloads rc.coll from
            -- disk and can wipe an in-memory-only collection the native
            -- Collections UI hasn't flushed to disk yet. The singleton is
            -- already live in-process.
            if not (RC.coll and RC.coll[name]) then
                return name .. "  " .. _("(collection not found)")
            end
        end
        return name
    end

    local function getFileList(pfx)
        local name = getCollName(pfx)
        if not name then return {} end
        return RowRenderer.getCollectionFileList(name)
    end

    -- ── Itens de menu específicos do Collection Row: seletor de coleção,
    --    Sort e Arrange. Antepostos aos itens genéricos (Scale/Frame/...)
    --    gerados por makeModule. ──────────────────────────────────────────
    local function extraMenuItemsBefore(ctx_menu)
        local _lc         = ctx_menu._
        local refresh      = ctx_menu.refresh
        local pfx          = ctx_menu.pfx
        local SortWidget   = ctx_menu.SortWidget
        local _UIManager   = ctx_menu.UIManager
        local InfoMessage  = ctx_menu.InfoMessage

        local items = {}

        -- Escolha da coleção-alvo (single-select, radio). Implementado como
        -- sub_item_table_func (não item_picker) porque funciona
        -- identicamente no menu nativo do KOReader e no SUIWindow, sem
        -- depender de um contexto de navegação aninhado (push/pop).
        items[#items + 1] = {
            text_func = function()
                local name = getCollName(pfx)
                return name and (_lc("Collection: ") .. name) or _lc("Collection: (none)")
            end,
            separator = true,
            sub_item_table_func = function()
                local tbr_name = getTBRCollName()
                local exclude  = tbr_name and { [tbr_name] = true } or nil
                local all = RowRenderer.listAllCollectionNames(exclude)
                local sub = {}
                if #all == 0 then
                    sub[#sub + 1] = { text = _lc("No collections found."), enabled = false }
                    return sub
                end
                for _, name in ipairs(all) do
                    local _n = name
                    sub[#sub + 1] = {
                        text           = _n,
                        radio          = true,
                        checked_func   = function() return getCollName(pfx) == _n end,
                        keep_menu_open = true,
                        callback       = function()
                            setCollName(pfx, _n)
                            refresh()
                        end,
                    }
                end
                return sub
            end,
        }

        -- Sort (ação de um clique — reescreve a ordem persistida; o Arrange
        -- manual continua disponível por cima do resultado).
        items[#items + 1] = {
            text = _lc("Sort"),
            enabled_func = function() return #getFileList(pfx) > 1 end,
            sub_item_table_func = function()
                local name = getCollName(pfx)
                local function sortAction(mode)
                    return function()
                        if name then
                            RowRenderer.sortCollection(name, mode)
                            refresh()
                        end
                    end
                end
                return {
                    { text = _lc("Title (A–Z)"),        keep_menu_open = true, callback = sortAction("title_asc") },
                    { text = _lc("Title (Z–A)"),         keep_menu_open = true, callback = sortAction("title_desc") },
                    { text = _lc("Author (A–Z)"),        keep_menu_open = true, callback = sortAction("author_asc") },
                    { text = _lc("% Read (ascending)"),  keep_menu_open = true, callback = sortAction("percent_asc") },
                    { text = _lc("% Read (descending)"), keep_menu_open = true, callback = sortAction("percent_desc") },
                    { text = _lc("Shuffle"), separator = true, keep_menu_open = true, callback = sortAction("shuffle") },
                }
            end,
        }

        -- Arrange (reordenar a coleção escolhida).
        items[#items + 1] = {
            text = _lc("Arrange"),
            enabled_func = function() return getCollName(pfx) ~= nil end,
            sub_item_table_func = function()
                local sub_items = {}
                local name = getCollName(pfx)
                local list = getFileList(pfx)

                sub_items[#sub_items + 1] = {
                    text         = _lc("Arrange Collection"),
                    enabled_func = function() return #list > 1 end,
                    keep_menu_open = true,
                    callback = function()
                        if #list < 2 then
                            _UIManager:show(InfoMessage:new{
                                text = _lc("Add at least 2 books to arrange."), timeout = 2 })
                            return
                        end
                        local sort_items = {}
                        for _, fp in ipairs(list) do
                            sort_items[#sort_items + 1] = {
                                text      = RowRenderer.getBookTitle(fp),
                                filepath  = fp,
                                mandatory = "",
                            }
                        end
                        local function on_save()
                            local new_list = {}
                            for _, item in ipairs(sort_items) do
                                if item.filepath then new_list[#new_list + 1] = item.filepath end
                            end
                            local RC = getRC()
                            if RC and RC.coll[name] then
                                local ordered = {}
                                for _, fp in ipairs(new_list) do
                                    local entry = RC.coll[name][fp]
                                    if entry then ordered[#ordered + 1] = entry end
                                end
                                RC:updateCollectionOrder(name, ordered)
                                RC:write({ [name] = true })
                            end
                            refresh()
                        end
                        _UIManager:show(SortWidget:new{
                            title = _lc("Arrange Collection"),
                            item_table = sort_items,
                            covers_fullscreen = true,
                            callback = on_save,
                        })
                    end,
                }

                sub_items[#sub_items + 1] = { text = _lc("Books"), enabled = false, separator = true }

                if #list == 0 then
                    sub_items[#sub_items + 1] = { text = _lc("No books in this collection."), enabled = false }
                else
                    for _, fp in ipairs(list) do
                        local _fp    = fp
                        local _title = RowRenderer.getBookTitle(fp)
                        sub_items[#sub_items + 1] = {
                            text           = _title,
                            keep_menu_open = true,
                            callback       = function()
                                local RC = getRC()
                                if RC then RC:removeItem(_fp, name) end
                                refresh()
                            end,
                        }
                    end
                end
                return sub_items
            end,
            sui_build = ctx_menu.is_sui and function(ctx, _item)
                local SUIWindow = require("sui_window")
                return SUIWindow.ListRow{
                    title        = _lc("Arrange"),
                    subtitle     = function()
                        local list = getFileList(pfx)
                        if #list == 0 then return _lc("No books in this collection.") end
                        local names = {}
                        for _, fp in ipairs(list) do names[#names + 1] = RowRenderer.getBookTitle(fp) end
                        return table.concat(names, "  ·  ")
                    end,
                    inner_w      = ctx.inner_w,
                    show_chevron = true,
                    enabled      = getCollName(pfx) ~= nil,
                    on_tap       = function()
                        local name = getCollName(pfx)
                        local list = getFileList(pfx)
                        local sort_items = {}
                        for _, fp in ipairs(list) do
                            sort_items[#sort_items + 1] = { text = RowRenderer.getBookTitle(fp), orig_item = fp }
                        end
                        ctx.push("nested_menu", {
                            title = _lc("Arrange"),
                            items_func = function()
                                return {
                                    {
                                        text = "Items List",
                                        sui_build = function(ctx2)
                                            local SUIWindow2 = require("sui_window")
                                            local function save_order(items_to_save)
                                                local new_list = {}
                                                for _, it in ipairs(items_to_save) do
                                                    new_list[#new_list + 1] = it.orig_item
                                                end
                                                local RC2 = getRC()
                                                if RC2 and RC2.coll[name] then
                                                    local ordered = {}
                                                    for _, fp in ipairs(new_list) do
                                                        local entry = RC2.coll[name][fp]
                                                        if entry then ordered[#ordered + 1] = entry end
                                                    end
                                                    RC2:updateCollectionOrder(name, ordered)
                                                    RC2:write({ [name] = true })
                                                end
                                            end
                                            local cards = {}
                                            for i, item in ipairs(sort_items) do
                                                local _i  = i
                                                local _fp = item.orig_item
                                                cards[#cards + 1] = SUIWindow2.ArrangeCard{
                                                    inner_w   = ctx2.inner_w,
                                                    title     = item.text,
                                                    on_delete = function()
                                                        table.remove(sort_items, _i)
                                                        local RC3 = getRC()
                                                        if RC3 then RC3:removeItem(_fp, name) end
                                                        ctx_menu.refresh()
                                                        ctx2.repaint()
                                                    end,
                                                    on_move_up = (_i > 1) and function()
                                                        sort_items[_i], sort_items[_i-1] = sort_items[_i-1], sort_items[_i]
                                                        save_order(sort_items)
                                                        ctx_menu.refresh()
                                                        ctx2.repaint()
                                                    end or nil,
                                                    on_move_down = (_i < #sort_items) and function()
                                                        sort_items[_i], sort_items[_i+1] = sort_items[_i+1], sort_items[_i]
                                                        save_order(sort_items)
                                                        ctx_menu.refresh()
                                                        ctx2.repaint()
                                                    end or nil,
                                                }
                                            end
                                            if #cards == 0 then
                                                cards[#cards + 1] = SUIWindow2.ListRow{
                                                    title   = _lc("No books in this collection."),
                                                    inner_w = ctx2.inner_w,
                                                }
                                            end
                                            return cards
                                        end,
                                    },
                                }
                            end,
                        })
                    end,
                }
            end or nil,
        }

        return items
    end

    local mod = RowRenderer.makeModule{
        id          = inst_id,
        name        = _("Collection Row"),
        default_on  = false,
        is_book_mod = true,   -- necessário para o repaint cirúrgico do swipe
        max_items   = MAX_ITEMS,
        paged       = true,
        label_fn    = displayName,
        getFileList = function(ctx) return getFileList(ctx.pfx) end,
        extra_menu_items_before = extraMenuItemsBefore,
    }

    -- Aviso de "por configurar", tal como module_collections.lua quando
    -- nenhuma coleção está selecionada: sem isto, uma Collection Row ainda
    -- sem coleção escolhida reserva o espaço (getHeight não depende da
    -- lista) mas não pinta nada — uma área em branco sem explicação.
    local orig_build = mod.build
    function mod.build(w, ctx)
        local widget = orig_build(w, ctx)
        if widget then return widget end
        if getCollName(ctx.pfx) then return nil end -- coleção escolhida mas vazia: mantém o comportamento antigo

        local hold_on = SUISettings:nilOrTrue("simpleui_hs_settings_on_hold")
        local ph_text = hold_on and _("No collection selected  —  long press to configure")
                                 or _("No collection selected")
        return CenterContainer:new{
            dimen = Geom:new{ w = w, h = mod.getHeight(ctx) },
            UI.makeColoredText{
                text    = ph_text,
                face    = Font:getFace(SUIStyle.FACE_REGULAR, SUIStyle.FS_BODY),
                fgcolor = SUIStyle.getThemeColor("text_secondary"),
                width   = w - PAD * 2,
            },
        }
    end

    return mod
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------
local M = {}
M.id            = "coll_row"
M.name          = _("Collection Row")
M.instanciable  = true
M.instances_key = "simpleui_coll_row_instances"
M.makeInstance  = makeInstance

return M
