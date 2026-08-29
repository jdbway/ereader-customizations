-- sui_book_row.lua — Simple UI
-- Fábrica partilhada de módulos "linha de capas com progresso" (cover row).
--
-- Duas camadas de API:
--   1. RowRenderer.build/getHeight/updateCovers — primitivas de baixo nível
--      (usadas internamente por makeModule; expostas para casos avançados).
--   2. RowRenderer.makeModule(spec) — fábrica de alto nível: recebe uma
--      tabela declarativa e devolve um módulo `M` completo (build, getHeight,
--      updateCovers, getMenuItems), pronto a ser exportado por um ficheiro
--      module_*.lua e registado no moduleregistry.lua.
--
-- Consumidores atuais:
--   • module_book_rows.lua (Recent, New Books — via makeModule)
--   • module_tbr.lua       (TBR, API pública própria — via makeModule)
--   • module_coll_row.lua  (Collection Row, instanciável — via makeModule)
--
-- Não é um módulo do registry (sem M.id / M.build ao nível de topo) — é uma
-- biblioteca pura.
--
-- Chaves de settings usadas (todas prefixadas por ctx.pfx .. id .. "_"):
--   show_progress, show_text, show_overlay, show_frame, solid_bg
-- Isto mantém retro-compatibilidade total com o TBR/Recent pré-existentes.

local Blitbuffer      = require("ffi/blitbuffer")
local BD              = require("ui/bidi")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LineWidget      = require("ui/widget/linewidget")
local OverlapGroup    = require("ui/widget/overlapgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local VerticalGroup   = require("ui/widget/verticalgroup")
local _ = require("sui_i18n").translate

local Config      = require("sui_config")
local UI          = require("sui_core")
local SUISettings = require("sui_store")
local SUIStyle    = require("sui_style")
local PAD    = UI.PAD
local Screen = require("device").screen

local CLR_TEXT_SUB    = UI.CLR_TEXT_SUB
local _BASE_RB_PCT_FS = SUIStyle.FS_DETAIL  -- 15: "XX% Read" label font size

local RowRenderer = {}

local _SH = nil
local function getSH()
    if not _SH then
        local ok, m = pcall(require, "desktop_modules/module_books_shared")
        if ok and m then _SH = m end
    end
    return _SH
end

-- Limpa a cache interna do módulo (referência a module_books_shared). Chamado
-- no teardown do plugin para permitir ao GC recolher a tabela antiga assim
-- que o seu package.loaded é limpo, em vez de esperar pelo upvalue.
function RowRenderer.reset() _SH = nil end

-- ---------------------------------------------------------------------------
-- Settings accessors — genéricos, namespaced por opts.id
--
-- progress/text/overlay aceitam um "toggle mode" opcional (3º parâmetro):
--   "on"  / "off"          — valor por omissão, o utilizador pode mudar
--   "locked_on"/"locked_off" — fixo, sem leitura de settings, sem item de menu
-- Omitir o modo é equivalente a "off" (comportamento pré-existente do TBR).
-- ---------------------------------------------------------------------------
local function _toggleDefault(mode) return mode == "on" or mode == "locked_on" end
local function _toggleLocked(mode)  return mode == "locked_on" or mode == "locked_off" end

function RowRenderer.showProgress(pfx, id, mode)
    if _toggleLocked(mode) then return _toggleDefault(mode) end
    local v = SUISettings:readSetting(pfx .. id .. "_show_progress")
    if v == nil then return _toggleDefault(mode) end
    return v == true
end
function RowRenderer.showText(pfx, id, mode)
    if _toggleLocked(mode) then return _toggleDefault(mode) end
    local v = SUISettings:readSetting(pfx .. id .. "_show_text")
    if v == nil then return _toggleDefault(mode) end
    return v == true
end
function RowRenderer.showOverlay(pfx, id, mode)
    if _toggleLocked(mode) then return _toggleDefault(mode) end
    local v = SUISettings:readSetting(pfx .. id .. "_show_overlay")
    if v == nil then return _toggleDefault(mode) end
    return v == true
end
function RowRenderer.showFrame(pfx, id) return SUISettings:isTrue(pfx .. id .. "_show_frame") end
function RowRenderer.solidBg(pfx, id)   return SUISettings:isTrue(pfx .. id .. "_solid_bg") end

-- ---------------------------------------------------------------------------
-- build(w, ctx, opts) → widget | nil
--
-- opts:
--   id          string    namespace de settings (ex: "tbr" ou inst_id)
--   getFileList function  () -> { fp, ... } (lista ordenada de ficheiros)
--   max_items   number?   máximo de capas mostradas por página (default 5)
--   cache_key   string?   chave para cache em ctx (default "_row_fps_" .. id)
--   paged       bool?     se true e #fps > max_items, ativa paginação por
--                         swipe horizontal (wraparound), sem indicador
--                         visual — a fila mostra sempre até `max_items`
--                         capas alinhadas à esquerda. Requer que o módulo
--                         consumidor tenha `is_book_mod = true` (ver
--                         moduleregistry.lua) para que o repaint cirúrgico
--                         funcione — sem isso o swipe é ignorado. Estado da
--                         página é scoped à sessão (ctx), não persiste entre
--                         reinícios — mesmo princípio do coverdeck_cur_idx
--                         do module_coverdeck.
--   filterItem  function? (fp, ctx) -> bool — exclui itens da lista (aplicado
--                         uma vez, antes de cachear em ctx)
--   labelForItem function? (bd) -> string — substitui o texto "XX% Read"
--                         por omissão (ex: "New" do New Books)
--   toggles     table?   { progress=mode, text=mode, overlay=mode }, cada
--                         mode em "on"|"off"|"locked_on"|"locked_off"
--                         (omitido = "off", igual ao comportamento anterior)
-- ---------------------------------------------------------------------------
function RowRenderer.build(w, ctx, opts)
    local id          = opts.id
    local max_items   = opts.max_items or 5
    local cache_key    = opts.cache_key or ("_row_fps_" .. id)
    local page_key     = "_row_page_" .. id
    local toggles      = opts.toggles or {}

    local fps = ctx[cache_key]
    if not fps then
        fps = opts.getFileList() or {}
        if opts.filterItem then
            local filtered = {}
            for _, fp in ipairs(fps) do
                if opts.filterItem(fp, ctx) then filtered[#filtered + 1] = fp end
            end
            fps = filtered
        end
        ctx[cache_key] = fps
    end
    local npages_key = "_row_npages_" .. id
    if #fps == 0 then
        ctx[npages_key] = 1
        return nil
    end

    -- Paginação: recorta a página atual de fps. Sem paginação (ou lista
    -- pequena), comportamento idêntico ao anterior — página única.
    local npages = 1
    local page   = 1
    local paged  = opts.paged and #fps > max_items
    if paged then
        npages = math.ceil(#fps / max_items)
        page   = ctx[page_key] or 1
        if page < 1 or page > npages then page = 1 end
        ctx[page_key] = page
    end
    ctx[npages_key] = npages
    local page_start = (page - 1) * max_items + 1
    local page_fps    = {}
    for i = page_start, math.min(page_start + max_items - 1, #fps) do
        page_fps[#page_fps + 1] = fps[i]
    end

    local ok_ss, SUIStyle2 = pcall(require, "sui_style")
    local _theme_fg        = ok_ss and SUIStyle2 and SUIStyle2.getThemeColor("fg")
    local _theme_secondary = ok_ss and SUIStyle2 and SUIStyle2.getThemeColor("text_secondary")
    local _clr_blk        = _theme_fg or Blitbuffer.COLOR_BLACK
    local _clr_sub        = _theme_secondary or _theme_fg or CLR_TEXT_SUB

    local SH          = getSH()
    local pfx         = ctx.pfx
    local scale       = Config.getModuleScale(id, pfx)
    local thumb_scale = Config.getThumbScale(id, pfx)
    local lbl_scale   = Config.getItemLabelScale(id, pfx)
    local D           = SH.getDims(scale, thumb_scale)
    local pct_fs      = math.max(8, math.floor(_BASE_RB_PCT_FS * scale * lbl_scale))

    local cols    = math.min(#page_fps, max_items)
    local inner_w = w - PAD * 2

    -- Tamanho das capas: a base é sempre o tamanho "auto-fit" — as
    -- `max_items` capas + gaps a preencher `inner_w`, adaptando-se ao
    -- dispositivo. O gap usa o mesmo PAD do resto do layout, para o
    -- espaçamento ficar consistente com o restante UI.
    --
    -- Scale/Cover Size (cs = scale * thumb_scale) é aplicado como
    -- multiplicador SOBRE essa base, não como troca para uma constante
    -- fixa não relacionada (D.RECENT_W/D.RECENT_H, calibrados para outro
    -- contexto). Isto garante que 100% = preenche a linha (como sempre) e
    -- que subir/descer a percentagem cresce/encolhe de forma contínua a
    -- partir do que já estava visível — antes, qualquer cs ~= 1.0 saltava
    -- para uma base tipicamente mais pequena do que o auto-fit, fazendo
    -- as capas encolherem mesmo ao subir a escala acima de 100%.
    local cw, ch, gap
    local cs = scale * thumb_scale
    local autofit_cw = math.max(1, math.floor((inner_w - (max_items - 1) * PAD) / max_items))
    if cs == 1.0 then
        gap = PAD
        cw  = autofit_cw
        ch  = math.max(1, math.floor(cw * (D.RECENT_H / D.RECENT_W)))
    else
        cw  = math.max(1, math.floor(autofit_cw * cs))
        ch  = math.max(1, math.floor(cw * (D.RECENT_H / D.RECENT_W)))
        gap = max_items > 1 and math.floor((inner_w - max_items * cw) / (max_items - 1)) or 0
    end
    local pct_face = Font:getFace(SUIStyle.FACE_REGULAR, pct_fs)

    local show_progress = RowRenderer.showProgress(pfx, id, toggles.progress)
    local show_text     = RowRenderer.showText(pfx, id, toggles.text)
    local use_overlay   = RowRenderer.showOverlay(pfx, id, toggles.overlay)

    local draw_progress = show_progress and not use_overlay
    local draw_text     = show_text     and not use_overlay

    -- D.RB_LABEL_H (Screen:scaleBySize(14)) is a hand-picked constant that
    -- was never actually tied to the font drawn into that space (pct_face,
    -- 15pt by default) -- real glyph height (ascent+descent) for a 15pt
    -- font runs closer to ~1.8x the point size, i.e. well over 14px. Ask
    -- the font engine for the real line height instead (face.ftsize is the
    -- underlying freetype face object -- see how TextWidget:updateSize()
    -- itself measures line height), so the row always reserves at least as
    -- much as the text actually needs. Without this, the label overflows
    -- cell_h, and the swipe/pagination eraser+refresh rect (sized off
    -- cell_h) stops short of the label's true bottom, leaving a strip of
    -- the previous page's text un-cleared on swipe.
    local ok_h, face_height = pcall(function() return pct_face.ftsize:getHeightAndAscender() end)
    local label_h = (ok_h and face_height and math.ceil(face_height)) or math.ceil(pct_fs * 1.8)

    local badge_r = math.floor(cw * 0.28)
    local cell_h  = use_overlay and (ch + badge_r)
                                 or (ch + D.RB_GAP1 + D.RB_BAR_H + D.RB_GAP2 + label_h)

    local row = HorizontalGroup:new{ align = "top" }
    local cover_slots = {}
    for i = 1, cols do
        local fp    = page_fps[i]
        local bd    = SH.getBookData(fp, ctx.prefetched and ctx.prefetched[fp])
        local cover = SH.getBookCover(fp, cw, ch, nil, 0.10) or SH.coverPlaceholder(bd.title, bd.authors, cw, ch)

        local cover_widget
        if use_overlay then
            local pct_int = math.floor((bd.percent or 0) * 100 + 0.5)
            local badge_d = badge_r * 2
            local border_sz = SUIStyle.BADGE_BORDER_SZ
            local border_color = SUIStyle.BADGE_BORDER_CLR
            local badge = FrameContainer:new{
                bordersize  = border_sz,
                color       = border_color,
                background  = Blitbuffer.gray(0.15),
                padding     = 0,
                dimen       = Geom:new{ w = badge_d, h = badge_d },
                radius      = badge_r,
                CenterContainer:new{
                    dimen = Geom:new{ w = badge_d - 2 * border_sz, h = badge_d - 2 * border_sz },
                    UI.makeColoredText{
                        text    = string.format(_("%d%%"), pct_int),
                        face    = pct_face,
                        bold    = true,
                        fgcolor = _clr_blk,
                    },
                },
            }
            badge.overlap_offset = {
                math.floor((cw - badge_d) / 2),
                ch - badge_r,
            }
            cover_widget = OverlapGroup:new{
                dimen = Geom:new{ w = cw, h = ch + badge_r },
                cover,
                badge,
            }
        else
            cover_widget = cover
        end

        local cell = VerticalGroup:new{ align = "center", cover_widget }

        if draw_progress then
            cell[#cell+1] = SH.vspan(D.RB_GAP1, ctx.vspan_pool)
            cell[#cell+1] = UI.progressBar(cw, bd.percent, D.RB_BAR_H)
        end

        if draw_text then
            cell[#cell+1] = SH.vspan(draw_progress and D.RB_GAP2 or D.RB_GAP1, ctx.vspan_pool)
            cell[#cell+1] = UI.makeColoredText{
                text      = opts.labelForItem and opts.labelForItem(bd)
                            or string.format(_("%d%% Read"), math.floor((bd.percent or 0) * 100 + 0.5)),
                face      = pct_face,
                bold      = true,
                fgcolor   = _clr_sub,
                width     = cw,
                alignment = "center",
            }
        end

        local tappable = InputContainer:new{
            dimen    = Geom:new{ w = cw, h = cell_h },
            [1]      = cell,
            _fp      = fp,
            _open_fn = ctx.open_fn,
        }
        tappable.ges_events = {
            TapBook = {
                GestureRange:new{
                    ges   = "tap",
                    range = function() return tappable.dimen end,
                },
            },
        }
        function tappable:onTapBook()
            if self._open_fn then self._open_fn(self._fp) end
            return true
        end

        if use_overlay then
            cover_slots[#cover_slots+1] = { container = cover_widget, idx = 1, fp = fp, w = cw, h = ch, align = nil, stretch = 0.10 }
        else
            cover_slots[#cover_slots+1] = { container = cell, idx = 1, fp = fp, w = cw, h = ch, align = nil, stretch = 0.10 }
        end

        local cell_widget = tappable
        if ctx.kb_recent_focus_idx == i then
            local bw = Screen:scaleBySize(3)
            cell_widget = OverlapGroup:new{
                dimen = Geom:new{ w = cw, h = cell_h },
                tappable,
                LineWidget:new{ dimen = Geom:new{ w = cw, h = bw },    background = Blitbuffer.COLOR_BLACK },
                LineWidget:new{ dimen = Geom:new{ w = cw, h = bw },    background = Blitbuffer.COLOR_BLACK, overlap_offset = {0, cell_h - bw} },
                LineWidget:new{ dimen = Geom:new{ w = bw, h = cell_h }, background = Blitbuffer.COLOR_BLACK },
                LineWidget:new{ dimen = Geom:new{ w = bw, h = cell_h }, background = Blitbuffer.COLOR_BLACK, overlap_offset = {cw - bw, 0} },
            }
        end

        if i > 1 then row[#row + 1] = HorizontalSpan:new{ width = gap } end
        row[#row + 1] = cell_widget
    end

    -- ── Swipe entre páginas (wraparound), sem indicador visual ───────────
    -- Sem chevron nem barra: a fila mostra sempre até `max_items` capas,
    -- alinhadas à esquerda (HorizontalGroup começa em x=0 por omissão); o
    -- swipe é a única forma de navegar quando há mais itens do que cabem
    -- numa linha.
    local content = row
    if paged and npages > 1 then
        local hs    = ctx._hs_widget
        local row_h = row:getSize().h
        -- Eraser: quando a página atual tem menos itens do que a anterior
        -- (cols < max_items), `row` só pinta `cols` células — a área à
        -- direita, onde a página anterior tinha mais capas/labels/barras de
        -- progresso, não é tocada por este paintTo(). _refreshBookModSlot
        -- pede um refresh parcial e-ink desse dimen (que já cobre sempre
        -- inner_w, largura constante — ver swipe_area.dimen abaixo), mas um
        -- refresh parcial só reflete o que estiver no framebuffer; sem algo
        -- a repintar essa área, os pixels antigos da página anterior ficam
        -- lá (o "ghost" reportado).
        --
        -- Só faz sentido SEM wallpaper: nesse caso os widgets do módulo são
        -- transparentes por omissão (ver comentário em
        -- HomescreenWidget:_initLayout) e nada mais repinta essa área. Uma
        -- camada opaca do tamanho de inner_w x row_h, pintada ANTES de
        -- `row` num OverlapGroup, garante que cada rebuild repinta sempre a
        -- área inteira.
        --
        -- COM wallpaper, content_widget:paintTo já pinta o wallpaper por
        -- trás de toda a árvore em CADA repaint (incluindo este parcial —
        -- ver o override em _initLayout), o que já limpa qualquer ghost
        -- sozinho; um eraser opaco aqui só tapava o wallpaper recém-pintado
        -- com um retângulo sólido, exatamente o bug reportado.
        local content_row = row
        if not ctx.has_wallpaper then
            local eraser_bg = (ok_ss and SUIStyle2 and SUIStyle2.getThemeColor("bg")) or Blitbuffer.COLOR_WHITE
            local eraser = LineWidget:new{
                dimen      = Geom:new{ w = inner_w, h = row_h },
                background = eraser_bg,
            }
            content_row = OverlapGroup:new{
                dimen = Geom:new{ w = inner_w, h = row_h },
                eraser,
                row,
            }
        end
        local swipe_area = InputContainer:new{
            dimen = Geom:new{ w = inner_w, h = row_h },
            [1]   = content_row,
        }
        swipe_area.ges_events = {
            Swipe = { GestureRange:new{ ges = "swipe", range = function() return swipe_area.dimen end } },
        }
        function swipe_area:onSwipe(_, ges)
            local dir = ges.direction
            if BD.mirroredUILayout() then
                if dir == "west" then dir = "east" elseif dir == "east" then dir = "west" end
            end
            local new_page
            if dir == "west" then
                new_page = page % npages + 1          -- próxima página, wraparound
            elseif dir == "east" then
                new_page = (page - 2 + npages) % npages + 1  -- página anterior, wraparound
            else
                return false
            end
            if hs and hs._ctx_cache then
                hs._ctx_cache[page_key] = new_page
                if hs._refreshBookModSlot and hs:_refreshBookModSlot(id) then return true end
                if hs._refreshImmediate then hs:_refreshImmediate(true) end
            end
            return true
        end
        content = swipe_area
    end

    local show_frame = RowRenderer.showFrame(pfx, id)
    local solid_bg   = RowRenderer.solidBg(pfx, id)
    local has_box    = show_frame or solid_bg
    local border_sz  = show_frame and SUIStyle.BORDER_SZ or 0
    local radius     = has_box and math.floor(Screen:scaleBySize(12) * scale) or 0
    local border_color = Blitbuffer.gray(0.72)
    if ok_ss and SUIStyle2 then
        border_color = SUIStyle2.getThemeColor("separator") or border_color
    end
    local bg_color = nil
    if solid_bg then
        bg_color = (ok_ss and SUIStyle2 and SUIStyle2.getThemeColor("bg")) or Blitbuffer.COLOR_WHITE
    end

    local result = FrameContainer:new{
        bordersize = border_sz,
        radius     = radius,
        color      = border_color,
        background = bg_color,
        padding = PAD, padding_top = has_box and PAD or 0, padding_bottom = has_box and PAD or 0,
        content,
    }
    result._cover_slots = cover_slots
    return result
end

-- ---------------------------------------------------------------------------
-- updateCovers(widget, ctx) — genérico, igual ao antigo M.updateCovers do TBR.
-- ---------------------------------------------------------------------------
function RowRenderer.updateCovers(widget, _ctx)
    if not widget or not widget._cover_slots then return true end
    local SH = getSH()
    if not SH then return true end
    local all_done = true
    for _, slot in ipairs(widget._cover_slots) do
        local new_cover = SH.getBookCover(slot.fp, slot.w, slot.h, slot.align, slot.stretch)
        if new_cover then
            slot.container[slot.idx] = new_cover
        elseif not Config.isCoverMissing(slot.fp) then
            all_done = false
        end
    end
    return all_done
end

-- ---------------------------------------------------------------------------
-- getHeight(ctx, opts) — opts:
--   id, toggles?     (como antes)
--   max_items?       usado para replicar o dimensionamento de capas de
--                     build() (ver ali para a explicação completa — a base
--                     é sempre o tamanho auto-fit, e Scale/Cover Size é
--                     aplicado como multiplicador sobre essa base, nunca
--                     como troca para uma constante fixa não relacionada).
--                     Como esta função não recebe a largura real da
--                     coluna, usa ctx.col_w/ctx.inner_w quando
--                     disponíveis, ou uma estimativa a partir do ecrã na
--                     sua ausência (ex: pré-visualização no editor de
--                     layout).
-- ---------------------------------------------------------------------------
function RowRenderer.getHeight(_ctx, opts)
    local id      = opts.id
    local toggles = opts.toggles or {}
    local pfx = _ctx and _ctx.pfx or ""
    local scale       = Config.getModuleScale(id, pfx)
    local thumb_scale = Config.getThumbScale(id, pfx)
    local lbl_scale   = Config.getItemLabelScale(id, pfx)
    local SH  = getSH()
    local D   = SH.getDims(scale, thumb_scale)

    local max_items = opts.max_items or 5
    local w = (_ctx and (_ctx.col_w or _ctx.inner_w))
              or (Screen:getWidth() - UI.SIDE_PAD * 2)
    local inner_w = w - PAD * 2
    local autofit_cw = math.max(1, math.floor((inner_w - (max_items - 1) * PAD) / max_items))

    local cs = scale * thumb_scale
    local cw = (cs == 1.0) and autofit_cw or math.max(1, math.floor(autofit_cw * cs))
    local rh = math.max(1, math.floor(cw * (D.RECENT_H / D.RECENT_W)))

    -- NOTA: esta reserva de altura tem de espelhar exatamente a de
    -- RowRenderer.build's `cell_h` (ver ali) — incluindo o facto de, fora do
    -- modo overlay, reservar SEMPRE gap+barra+gap+label, independentemente
    -- de show_progress/show_text estarem ativos. build() reserva sempre essa
    -- altura (para manter a altura da linha estável e a área de refresh/
    -- eraser consistente entre toggles); antes, getHeight() só somava essas
    -- parcelas condicionalmente, o que subestimava a altura real sempre que
    -- progress bar e texto estavam ambos desligados — divergência visível no
    -- placeholder "no collection selected" do Collection Row (mais baixo do
    -- que o conteúdo real que o substitui).
    --
    -- label_h: ver a mesma nota em build() — D.RB_LABEL_H é uma constante
    -- fixa nunca calibrada para o tamanho real da fonte desenhada (pct_face),
    -- pelo que a altura real do texto (ascent+descent) costuma ultrapassá-la.
    -- Medir a mesma face usada em build(), via face.ftsize:getHeightAndAscender()
    -- (a API real do freetype/KOReader — não face.size, que é só o tamanho
    -- em pontos, um número, não uma tabela).
    local use_overlay = RowRenderer.showOverlay(pfx, id, toggles.overlay)
    local pct_fs   = math.max(8, math.floor(_BASE_RB_PCT_FS * scale * lbl_scale))
    local pct_face = Font:getFace(SUIStyle.FACE_REGULAR, pct_fs)
    local ok_h, face_height = pcall(function() return pct_face.ftsize:getHeightAndAscender() end)
    local label_h  = (ok_h and face_height and math.ceil(face_height)) or math.ceil(pct_fs * 1.8)
    local h = rh
    if use_overlay then
        local badge_r = math.floor(cw * 0.28)
        h = h + badge_r
    else
        h = h + D.RB_GAP1 + D.RB_BAR_H + D.RB_GAP2 + label_h
    end


    local show_frame = RowRenderer.showFrame(pfx, id)
    if show_frame or RowRenderer.solidBg(pfx, id) then
        h = h + PAD * 2
    end
    -- Mirror build()'s `border_sz = show_frame and SUIStyle.BORDER_SZ or 0`
    -- passed as FrameContainer's `bordersize` — FrameContainer:getSize()
    -- adds (margin + bordersize) * 2 to the content height, so the border
    -- itself (not just the padding) grows the real widget by border_sz * 2
    -- pixels whenever the frame is on.
    if show_frame then
        h = h + SUIStyle.BORDER_SZ * 2
    end
    return Config.getScaledLabelH() + h
end

-- ---------------------------------------------------------------------------
-- getBookTitle(fp) — título curto para listas de arranjo (Arrange).
-- ---------------------------------------------------------------------------
function RowRenderer.getBookTitle(fp)
    local title = fp:match("([^/]+)%.[^%.]+$") or fp
    pcall(function()
        local DS = require("docsettings")
        local ok2, ds = pcall(DS.open, DS, fp)
        if ok2 and ds then
            local rp = ds:readSetting("doc_props") or {}
            if rp.title and rp.title ~= "" then title = rp.title end
            pcall(function() ds:close() end)
        end
    end)
    if #title > 48 then title = title:sub(1, 45) .. "…" end
    return title
end

-- ---------------------------------------------------------------------------
-- listAllCollectionNames() → { name, ... }
--
-- Todas as coleções conhecidas do ReadCollection, com "favorites" primeiro
-- (se existir), ordenadas alfabeticamente a seguir.
-- ---------------------------------------------------------------------------
-- exclude_names: optional { [name] = true, ... } — coleções a omitir da
-- lista (ex: a coleção do TBR, que já tem módulo próprio e não deve poder
-- ser escolhida de novo aqui).
function RowRenderer.listAllCollectionNames(exclude_names)
    local ok_rc, rc = pcall(require, "readcollection")
    local all = {}
    if not (ok_rc and rc) then return all end
    -- Not calling rc:_read() — it destructively reloads rc.coll/rc.coll_settings
    -- from disk and can wipe an in-memory-only collection the native
    -- Collections UI hasn't flushed to disk yet. The singleton is already
    -- live in-process.
    local fav = rc.default_collection_name or "favorites"
    local coll_set = {}
    if rc.coll then for n in pairs(rc.coll) do coll_set[n] = true end end
    if rc.coll_folders then for n in pairs(rc.coll_folders) do coll_set[n] = true end end
    if exclude_names then
        for n in pairs(exclude_names) do coll_set[n] = nil end
    end
    if coll_set[fav] then
        all[#all + 1] = fav
        coll_set[fav] = nil
    end
    local others = {}
    for name in pairs(coll_set) do others[#others + 1] = name end
    table.sort(others, function(a, b) return a:lower() < b:lower() end)
    for _, n in ipairs(others) do all[#all + 1] = n end
    return all
end

-- ---------------------------------------------------------------------------
-- getCollectionFileList(coll_name) → { fp, ... } ordenado por RC "order"
--
-- Mesma lógica de leitura que module_tbr.getTBRList(), mas para qualquer
-- coleção. Filtra entradas cujo ficheiro já não existe em disco.
-- ---------------------------------------------------------------------------
function RowRenderer.getCollectionFileList(coll_name)
    if not coll_name then return {} end
    local ok_rc, rc = pcall(require, "readcollection")
    if not (ok_rc and rc) then return {} end
    -- Not calling rc:_read() — see note in listAllCollectionNames() above.
    local coll = rc.coll and rc.coll[coll_name]
    if not coll then return {} end
    local lfs = require("libs/libkoreader-lfs")
    local items = {}
    for _, item in pairs(coll) do
        if lfs.attributes(item.file, "mode") == "file" then
            items[#items + 1] = item
        end
    end
    table.sort(items, function(a, b) return (a.order or 0) < (b.order or 0) end)
    local fps = {}
    for _, item in ipairs(items) do fps[#fps + 1] = item.file end
    return fps
end

-- ---------------------------------------------------------------------------
-- sortCollection(coll_name, mode) → bool (sucesso)
--
-- Recalcula e persiste a ordem de uma coleção via RC:updateCollectionOrder,
-- exatamente como o "Arrange" manual — ou seja, isto é uma ação de um só
-- disparo: depois de ordenar, o utilizador continua a poder reordenar à mão
-- por cima do resultado.
--
-- mode:
--   "title_asc" | "title_desc"     — por título (RowRenderer.getBookTitle)
--   "author_asc"                   — por autor (SH.getBookData(fp).authors)
--   "percent_asc" | "percent_desc" — por progresso de leitura
--   "shuffle"                      — ordem aleatória
-- ---------------------------------------------------------------------------
function RowRenderer.sortCollection(coll_name, mode)
    if not coll_name then return false end
    local ok_rc, rc = pcall(require, "readcollection")
    if not (ok_rc and rc) then return false end
    -- Not calling rc:_read() — see note in listAllCollectionNames() above.
    local coll = rc.coll and rc.coll[coll_name]
    if not coll then return false end

    local fps = RowRenderer.getCollectionFileList(coll_name)
    if #fps < 2 then return false end

    local SH = getSH()
    if mode == "title_asc" or mode == "title_desc" then
        local titles = {}
        for _, fp in ipairs(fps) do titles[fp] = RowRenderer.getBookTitle(fp):lower() end
        table.sort(fps, function(a, b)
            if mode == "title_asc" then return titles[a] < titles[b] else return titles[a] > titles[b] end
        end)
    elseif mode == "author_asc" then
        local authors = {}
        for _, fp in ipairs(fps) do
            local bd = SH.getBookData(fp)
            authors[fp] = (bd.authors or ""):lower()
        end
        table.sort(fps, function(a, b) return authors[a] < authors[b] end)
    elseif mode == "percent_asc" or mode == "percent_desc" then
        local pct = {}
        for _, fp in ipairs(fps) do
            local bd = SH.getBookData(fp)
            pct[fp] = bd.percent or 0
        end
        table.sort(fps, function(a, b)
            if mode == "percent_asc" then return pct[a] < pct[b] else return pct[a] > pct[b] end
        end)
    elseif mode == "shuffle" then
        for i = #fps, 2, -1 do
            local j = math.random(i)
            fps[i], fps[j] = fps[j], fps[i]
        end
    else
        return false
    end

    local ordered = {}
    for _, fp in ipairs(fps) do
        local entry = coll[fp]
        if entry then ordered[#ordered + 1] = entry end
    end
    rc:updateCollectionOrder(coll_name, ordered)
    rc:write({ [coll_name] = true })
    return true
end

-- ---------------------------------------------------------------------------
-- makeModule(spec) → M
--
-- Fábrica de alto nível: gera um módulo completo (build/getHeight/
-- updateCovers/getMenuItems) a partir de uma tabela declarativa. Reduz cada
-- módulo "linha de capas" concreto a só as suas diferenças reais.
--
-- spec:
--   id            string   (obrigatório) — namespace de settings + M.id
--   name          string   (obrigatório) — M.name (nome no "Add Module")
--   label         string?  — texto por omissão do rótulo de secção
--   label_fn      function? (pfx) -> string — rótulo dinâmico (sobrepõe label)
--   default_on    bool?    (default false)
--   is_book_mod   bool?    (default false) — ver moduleregistry.lua
--   max_items     number?  (default 5)
--   paged         bool?    (default false) — ver RowRenderer.build
--   getFileList   function (ctx) -> { fp, ... }  (obrigatório)
--   cache_key     string?
--   filterItem    function? (fp, ctx) -> bool
--   labelForItem  function? (bd) -> string
--   toggles       table?   { progress=mode, text=mode, overlay=mode }
--   extra_settings  { { key, label, default }, ... }?  — toggles adicionais
--       (settings key = pfx..id.."_"..key; aparecem no menu depois dos
--       toggles padrão; o valor lido fica acessível a getFileList/filterItem
--       via SUISettings, não é passado automaticamente — cada spec lê o que
--       precisa a partir do seu próprio closure)
--   extra_menu_items_before  function? (ctx_menu) -> { item, ... }
--   extra_menu_items_after   function? (ctx_menu) -> { item, ... }
--   updateCovers  function? — substitui RowRenderer.updateCovers (ex: para
--       uma otimização de patch in-place mais sofisticada)
--   reset         function? — exposto como M.reset (limpeza de caches
--       internas do módulo; chamado no teardown do plugin)
--   enabled_key   string?  (default id.."_enabled")
--   isEnabled     function? (pfx) -> bool — substitui enabled_key/default_on
-- ---------------------------------------------------------------------------
function RowRenderer.makeModule(spec)
    assert(spec.id, "makeModule: spec.id is required")
    assert(spec.getFileList, "makeModule: spec.getFileList is required")

    local id      = spec.id
    local toggles = spec.toggles or {}

    local M = {}
    M.id          = id
    M.name        = spec.name or id
    M.label       = spec.label
    M.enabled_key = spec.enabled_key or (id .. "_enabled")
    M.default_on  = spec.default_on or false
    M.has_covers  = true
    if spec.is_book_mod then M.is_book_mod = true end
    if spec.isEnabled    then M.isEnabled    = spec.isEnabled end
    if spec.reset         then M.reset         = spec.reset end

    local row_opts = {
        id           = id,
        max_items    = spec.max_items or 5,
        cache_key    = spec.cache_key,
        paged        = spec.paged,
        filterItem   = spec.filterItem,
        labelForItem = spec.labelForItem,
        toggles      = toggles,
    }

    function M.build(w, ctx)
        local lbl = spec.label_fn and spec.label_fn(ctx.pfx) or spec.label
        if lbl then Config.applyLabelToggle(M, lbl) end
        row_opts.getFileList = function() return spec.getFileList(ctx) end
        return RowRenderer.build(w, ctx, row_opts)
    end

    function M.getHeight(ctx)
        return RowRenderer.getHeight(ctx, {
            id        = id,
            toggles   = toggles,
            max_items = spec.max_items or 5,
        })
    end

    function M.updateCovers(widget, ctx)
        if spec.updateCovers then return spec.updateCovers(widget, ctx) end
        return RowRenderer.updateCovers(widget, ctx)
    end

    function M.getMenuItems(ctx_menu)
        local _lc    = ctx_menu._
        local refresh = ctx_menu.refresh
        local pfx    = ctx_menu.pfx
        local items  = {}

        if spec.extra_menu_items_before then
            for _, it in ipairs(spec.extra_menu_items_before(ctx_menu)) do
                items[#items + 1] = it
            end
        end

        items[#items + 1] = Config.makeScaleItem{
            text_func    = function() return _lc("Scale") end,
            enabled_func = function() return not Config.isScaleLinked() end,
            title        = _lc("Scale"),
            info         = _lc("Scale for this module.\n100% is the default size."),
            get          = function() return Config.getModuleScalePct(id, pfx) end,
            set          = function(v) Config.setModuleScale(v, id, pfx) end,
            refresh      = refresh,
        }
        items[#items + 1] = Config.makeScaleItem{
            text_func = function() return _lc("Text Size") end,
            title     = _lc("Text Size"),
            info      = _lc("Scale for the percentage read text.\n100% is the default size."),
            get       = function() return Config.getItemLabelScalePct(id, pfx) end,
            set       = function(v) Config.setItemLabelScale(v, id, pfx) end,
            refresh   = refresh,
        }
        items[#items + 1] = Config.makeScaleItem{
            text_func = function() return _lc("Cover Size") end,
            separator = true,
            title     = _lc("Cover Size"),
            info      = _lc("Scale for the cover thumbnails only.\nText and progress bar follow the module scale.\n100% is the default size."),
            get       = function() return Config.getThumbScalePct(id, pfx) end,
            set       = function(v) Config.setThumbScale(v, id, pfx) end,
            refresh   = refresh,
        }

        local lbl = spec.label_fn and spec.label_fn(pfx) or spec.label
        if lbl then
            items[#items + 1] = Config.makeLabelToggleItem(id, lbl, refresh, _lc)
        end

        items[#items + 1] = {
            text           = _lc("Frame"),
            checked_func   = function() return RowRenderer.showFrame(pfx, id) end,
            keep_menu_open = true,
            callback       = function()
                SUISettings:saveSetting(pfx .. id .. "_show_frame", not RowRenderer.showFrame(pfx, id))
                refresh()
            end,
        }
        items[#items + 1] = {
            text           = _lc("Solid Background"),
            checked_func   = function() return RowRenderer.solidBg(pfx, id) end,
            keep_menu_open = true,
            callback       = function()
                SUISettings:saveSetting(pfx .. id .. "_solid_bg", not RowRenderer.solidBg(pfx, id))
                refresh()
            end,
        }

        if not _toggleLocked(toggles.progress) then
            items[#items + 1] = {
                text           = _lc("Progress Bar"),
                checked_func   = function() return RowRenderer.showProgress(pfx, id, toggles.progress) end,
                enabled_func   = function() return not RowRenderer.showOverlay(pfx, id, toggles.overlay) end,
                keep_menu_open = true,
                callback       = function()
                    SUISettings:saveSetting(pfx .. id .. "_show_progress",
                        not RowRenderer.showProgress(pfx, id, toggles.progress))
                    refresh()
                end,
            }
        end
        if not _toggleLocked(toggles.text) then
            items[#items + 1] = {
                text           = _lc("Percentage Text"),
                checked_func   = function() return RowRenderer.showText(pfx, id, toggles.text) end,
                enabled_func   = function() return not RowRenderer.showOverlay(pfx, id, toggles.overlay) end,
                keep_menu_open = true,
                callback       = function()
                    SUISettings:saveSetting(pfx .. id .. "_show_text",
                        not RowRenderer.showText(pfx, id, toggles.text))
                    refresh()
                end,
            }
        end
        if not _toggleLocked(toggles.overlay) then
            items[#items + 1] = {
                text           = _lc("Percentage Overlay on Cover"),
                checked_func   = function() return RowRenderer.showOverlay(pfx, id, toggles.overlay) end,
                keep_menu_open = true,
                callback       = function()
                    SUISettings:saveSetting(pfx .. id .. "_show_overlay",
                        not RowRenderer.showOverlay(pfx, id, toggles.overlay))
                    refresh()
                end,
            }
        end

        for _, es in ipairs(spec.extra_settings or {}) do
            local skey = pfx .. id .. "_" .. es.key
            items[#items + 1] = {
                text           = es.label,
                checked_func   = function() return SUISettings:readSetting(skey) == true
                                              or (SUISettings:readSetting(skey) == nil and es.default) end,
                keep_menu_open = true,
                callback       = function()
                    local cur = SUISettings:readSetting(skey)
                    if cur == nil then cur = es.default end
                    SUISettings:saveSetting(skey, not cur)
                    refresh()
                end,
            }
        end

        if spec.extra_menu_items_after then
            for _, it in ipairs(spec.extra_menu_items_after(ctx_menu)) do
                items[#items + 1] = it
            end
        end

        return items
    end

    return M
end

return RowRenderer
