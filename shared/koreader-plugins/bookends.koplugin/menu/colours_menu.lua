--- Colour-related menus: text/symbol colours and bar colours/ticks.
-- Attached onto the Bookends class by main.lua on plugin load.
local _ = require("bookends_i18n").gettext
local Device = require("device")
local Screen = Device.screen
local Colour = require("bookends_colour")

return function(Bookends)

--- Build the shared colour items used by bar colours (progress bar /
--- track / tick / invert toggle / border / border thickness / tick-invert).
--
-- on_reopen (optional): called once when a colour row's sub-dialog (nudge
-- or palette picker) closes. The TouchMenu callers leave it nil and rely on
-- the touchmenu_instance restore closure instead; the inline ButtonDialog
-- caller passes it to reopen its rebuilt colour list. It must NOT be wired
-- to saveColors — saveColors fires on every nudge increment, and reopening
-- the list mid-nudge stacks dialogs (issue #57).
function Bookends:_buildColorItems(bc, saveColors, on_reopen)
    local function colorNudge(title, field, default_pct, touchmenu_instance)
        if Screen:isColorEnabled() then
            -- Colour device: show palette picker. Hex-shape takes priority; if
            -- the field still holds a legacy raw byte or {grey=N}, render
            -- the equivalent greyscale hex so the picker opens on the
            -- user's currently-stored value.
            local v = bc[field]
            local original = v  -- capture verbatim for revert
            local current_hex
            if type(v) == "table" and v.hex then
                current_hex = v.hex
            elseif type(v) == "table" and v.grey then
                local g = string.format("%02X", v.grey)
                current_hex = "#" .. g .. g .. g
            elseif type(v) == "number" then
                local g = string.format("%02X", v)
                current_hex = "#" .. g .. g .. g
            end
            local default_hex = Colour.defaultHexFor(field)
            self:showColourPicker(title, current_hex, default_hex,
                function(new_hex)
                    bc[field] = Colour.toStorageShape(new_hex)
                    saveColors()
                end,
                function()
                    bc[field] = nil
                    saveColors()
                end,
                function()
                    bc[field] = original  -- restore exact pre-picker shape
                    saveColors()
                end,
                touchmenu_instance, nil, nil, on_reopen)
            return
        end
        -- Greyscale device: nudge dialog. 0% renders pure white (since
        -- v5.10.2); Transparent is the separate explicit no-fill sentinel
        -- (issue #43) — stored as `false` and handled at the paint layer.
        local v = bc[field]
        local byte
        if type(v) == "table" and v.grey then byte = v.grey
        elseif type(v) == "number" then byte = v
        end
        local current = byte and math.floor((0xFF - byte) * 100 / 0xFF + 0.5) or default_pct
        self:showNudgeDialog(title, current, 0, 100, default_pct, "%",
            function(val)
                bc[field] = { grey = 0xFF - math.floor(val * 0xFF / 100 + 0.5) }
                saveColors()
            end,
            on_reopen, nil, nil, touchmenu_instance,
            function()
                bc[field] = nil; saveColors()
            end,
            _("Default") .. " (" .. _("per style") .. ")",
            {
                text = _("Transparent"),
                callback = function()
                    bc[field] = false
                    saveColors()
                end,
            })
    end

    local function pctLabel(field)
        local v = bc[field]
        -- Boolean check first: under LuaJIT, `not v` on an ffi.metatype with
        -- __eq (Blitbuffer.Color*) routes through __eq and crashes. Cheap
        -- type() check avoids it. `false` = explicit transparent (#43);
        -- `nil` = inherit-from-default; everything else is a stored colour.
        local t = type(v)
        if t == "nil" then return _("default") end
        if t == "boolean" then return _("transparent") end
        if t == "table" and v.hex then return v.hex end
        local byte
        if t == "table" and v.grey then byte = v.grey
        elseif t == "number" then byte = v
        end
        if byte then
            -- 0% (white) is a real colour since v5.10.2 — no longer aliased
            -- to "transparent". Users wanting no fill choose the explicit
            -- Transparent button which stores `false`.
            local pct = math.floor((0xFF - byte) * 100 / 0xFF + 0.5)
            return pct .. "%"
        end
        return _("default")
    end

    return {
        {
            text_func = function()
                return _("Progress bar colour") .. ": " .. pctLabel("fill")
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                colorNudge(_("Progress bar colour (% black)"), "fill", 75, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.fill = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                return _("Progress bar track colour") .. ": " .. pctLabel("bg")
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                colorNudge(_("Progress bar track colour (% black)"), "bg", 25, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.bg = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                return _("Tick color") .. ": " .. pctLabel("tick")
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                colorNudge(_("Tick color (% black)"), "tick", 100, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.tick = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text = _("Invert tick color on read portion"),
            checked_func = function() return bc.invert_read_ticks ~= false end,
            callback = function()
                if bc.invert_read_ticks == false then
                    bc.invert_read_ticks = nil
                else
                    bc.invert_read_ticks = false
                end
                saveColors()
            end,
        },
        {
            text_func = function()
                return _("Border color") .. ": " .. pctLabel("border")
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                colorNudge(_("Border color (% black)"), "border", 100, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.border = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                if bc.border_thickness then
                    return _("Border thickness") .. ": " .. bc.border_thickness .. "px"
                end
                return _("Border thickness") .. ": 1px"
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local default_val = 1
                local current = bc.border_thickness or default_val
                self:showNudgeDialog(_("Border thickness"), current, 0, 10, default_val, "px",
                    function(val)
                        bc.border_thickness = (val ~= default_val) and val or nil
                        saveColors()
                    end,
                    on_reopen, nil, nil, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.border_thickness = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                return _("Tick inversion color") .. ": " .. pctLabel("invert")
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                colorNudge(_("Tick inversion color (% black)"), "invert", 0, touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                bc.invert = nil; saveColors()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
    }
end


function Bookends:buildTextColourMenu()
    local function textColorNudge(field, title, default_label_suffix, touchmenu_instance)
        local stored = self.settings:readSetting(field)
        if Screen:isColorEnabled() then
            local original = stored  -- capture verbatim for revert
            local current_hex
            if stored and stored.hex then
                current_hex = stored.hex
            elseif stored and stored.grey then
                local g = string.format("%02X", stored.grey)
                current_hex = "#" .. g .. g .. g
            end
            local is_bg = (field == "background_color")
            local null_tile_label = is_bg and _("No background") or nil
            local white_hex = is_bg and "#FFFFFF" or nil
            self:showColourPicker(title, current_hex, Colour.defaultHexFor(field),
                function(new_hex)
                    self.settings:saveSetting(field, Colour.toStorageShape(new_hex))
                    self:markDirty()
                end,
                function()
                    self.settings:delSetting(field)
                    self:markDirty()
                end,
                function()
                    if original == nil then
                        self.settings:delSetting(field)
                    else
                        self.settings:saveSetting(field, original)
                    end
                    self:markDirty()
                end,
                touchmenu_instance,
                null_tile_label,
                white_hex)
            return
        end
        local byte = (stored and stored.grey) or nil
        local current = byte and math.floor((0xFF - byte) * 100 / 0xFF + 0.5) or 100
        -- background_color gets a one-tap "White" shortcut (val=0 → grey=0xFF),
        -- mirroring the colour-picker's White footer button. Distinct from
        -- "Default (off)": Off draws no fill (page shows through); White paints
        -- solid white pixels, masking dark page content like CBZ artwork.
        local extra_button
        if field == "background_color" then
            extra_button = { text = _("White"), value = 0 }
        end
        self:showNudgeDialog(title, current, 0, 100, 100, "%",
            function(val)
                self.settings:saveSetting(field, { grey = 0xFF - math.floor(val * 0xFF / 100 + 0.5) })
                self:markDirty()
            end,
            nil, nil, nil, touchmenu_instance,
            function()
                self.settings:delSetting(field)
                self:markDirty()
            end,
            _("Default") .. " (" .. default_label_suffix .. ")",
            extra_button)
    end

    local function textPctLabel()
        local text_color = self.settings:readSetting("text_color")
        if not text_color then
            return _("default") .. " (" .. _("book") .. ")"
        end
        if text_color.hex then return text_color.hex end
        if text_color.grey then
            local pct = math.floor((0xFF - text_color.grey) * 100 / 0xFF + 0.5)
            return pct .. "%"
        end
        return _("default") .. " (" .. _("book") .. ")"
    end

    local function symbolPctLabel()
        local symbol_color = self.settings:readSetting("symbol_color")
        if not symbol_color then
            return _("default") .. " (" .. _("text") .. ")"
        end
        if symbol_color.hex then return symbol_color.hex end
        if symbol_color.grey then
            local pct = math.floor((0xFF - symbol_color.grey) * 100 / 0xFF + 0.5)
            return pct .. "%"
        end
        return _("default") .. " (" .. _("text") .. ")"
    end

    local function bgPctLabel()
        local bg = self.settings:readSetting("background_color")
        if not bg then
            return _("off")
        end
        if bg.hex then return bg.hex end
        if bg.grey then
            local pct = math.floor((0xFF - bg.grey) * 100 / 0xFF + 0.5)
            return pct .. "%"
        end
        return _("off")
    end

    return {
        {
            text_func = function()
                return _("Text color") .. ": " .. textPctLabel()
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                textColorNudge("text_color", _("Text color"), _("book"), touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                self.settings:delSetting("text_color")
                self:markDirty()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                return _("Icon color") .. ": " .. symbolPctLabel()
            end,
            help_text = _("Applies to Nerd Font and FontAwesome icon glyphs (the Private Use Area range, e.g. %W, %B, %k). Unicode symbols in the regular text ranges (like the hourglass \"⌛\") follow the text color instead.\n\nAn inline [c=#RRGGBB]…[/c] tag in a line overrides the icon colour for any glyphs inside it."),
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                textColorNudge("symbol_color", _("Icon color"), _("text"), touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                self.settings:delSetting("symbol_color")
                self:markDirty()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text_func = function()
                return _("Background colour") .. ": " .. bgPctLabel()
            end,
            help_text = _("Solid fill drawn behind the top and bottom overlay regions, edge to edge across the screen. Choose a colour to enable, hold this row or tap Default in the picker to turn off."),
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                textColorNudge("background_color", _("Background colour"), _("off"), touchmenu_instance)
            end,
            hold_callback = function(touchmenu_instance)
                self.settings:delSetting("background_color")
                self:markDirty()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
    }
end

end
