-- Preset-name generator for the "+ New preset" tile.
-- Pure Lua, no KOReader dependencies — unit-testable via tests/_test_preset_naming.lua.

local PresetNaming = {}

--- Return the first unused name in the sequence: stem, "stem 2", "stem 3", ...
--- Collisions are checked by exact string match against the `name` field of
--- every entry in `presets` (the shape produced by Bookends:readPresetFiles).
function PresetNaming.nextUntitledName(presets, stem)
    local taken = {}
    for _, p in ipairs(presets) do
        taken[p.name] = true
    end
    if not taken[stem] then return stem end
    local i = 2
    while taken[stem .. " " .. i] do
        i = i + 1
    end
    return stem .. " " .. i
end

--- True if `name` looks like a plugin-default placeholder rather than something
--- the user chose. Used to gate gallery submissions so the curated index doesn't
--- fill up with "My setup" / "Untitled 3" entries.
--- @param name             the preset's current `name` field
--- @param default_names    list of strings that exactly match a known default
---                         (e.g. `{"My setup", _("My setup")}` to cover both the
---                         English source and the current-locale translation)
--- @param untitled_prefixes list of stems where any name *starting with* the
---                         stem counts as default (e.g. `{"Untitled", _("Untitled")}`)
function PresetNaming.looksLikeDefaultName(name, default_names, untitled_prefixes)
    if not name or name == "" then return true end
    if default_names then
        for _i, d in ipairs(default_names) do
            if name == d then return true end
        end
    end
    if untitled_prefixes then
        for _i, p in ipairs(untitled_prefixes) do
            -- Escape Lua pattern magic so the prefix matches as a literal string,
            -- not as a regex (defensive against translations like "Sin nombre%").
            local escaped = (p:gsub("(%W)", "%%%1"))
            if name:find("^" .. escaped) then return true end
        end
    end
    return false
end

--- True if `description` looks like a plugin-default placeholder.
--- @param description  the preset's current `description` field
--- @param defaults     list of strings to compare against (English source +
---                    current-locale translation forms)
function PresetNaming.looksLikeDefaultDescription(description, defaults)
    if not description or description == "" then return true end
    if defaults then
        for _i, d in ipairs(defaults) do
            if description == d then return true end
        end
    end
    return false
end

return PresetNaming
