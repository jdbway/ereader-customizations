--- Central constants: defaults, schema, and preset key groupings.
-- Pure data, no logic. Any module that needs a setting default reads it here.
local Config = {}

Config.MAX_BARS = 8

--- Schema version for persisted preset / position data. Bumped when the
--- stored form changes (e.g. v5 token rename from single-letter to
--- descriptive names). Startup migration uses this to decide whether to
--- canonicaliseLegacy against `self.positions` and on-disk preset files.
--- Once bumped on disk, migration is skipped — one-time cost per upgrade.
Config.SCHEMA_VERSION = 5

Config.DEFAULT_MARGINS = {
    margin_top = 10, margin_bottom = 10,
    margin_left = 18, margin_right = 18,
}

Config.DEFAULT_TICK_WIDTH_MULTIPLIER = 2

--- Default per-progress-bar configuration.
Config.BAR_DEFAULTS = {
    enabled = false, type = "book", style = "solid", height = 20,
    v_anchor = "bottom", margin_v = 0, margin_left = 0, margin_right = 0,
    chapter_ticks = "off",
}

--- First-run default positions. Loaded only when no saved config exists.
Config.DEFAULT_POSITIONS = {
    tl = { lines = { "%author \xE2\x8B\xAE %title" }, line_font_size = { [1] = 12 } },
    tc = { lines = { "%time_12h \xC2\xB7 %weekday_short %date" }, line_font_size = { [1] = 14 }, line_style = { [1] = "bold" } },
    tr = { lines = { "%chap_title" }, line_style = { [1] = "bold" } },
    bl = { lines = { "\xE2\x8F\xB3 %session_time session" } },
    bc = { lines = { "Page %page_num of %page_count" }, line_font_size = { [1] = 16 } },
    br = { lines = { "%batt_icon %wifi" }, line_font_size = { [1] = 10 } },
}

--- Per-line attribute field names. Used anywhere per-line metadata is
--- rebased/shifted (line delete, line swap) to avoid hard-coding the list.
Config.LINE_FIELDS = {
    "line_style", "line_font_size", "line_font_face",
    "line_v_nudge", "line_h_nudge", "line_uppercase",
    "line_page_filter", "line_bar_type", "line_bar_height", "line_bar_style",
    "line_bar_chapter_ticks", "line_bar_direction",
    "line_bar_unread_height", "line_bar_colors", "line_bar_markers",
}

--- Settings keys that belong to the "defaults" group (font/margin/layout
--- shared across every position). Drives bulk save/load in preset logic.
Config.DEFAULTS_KEYS = {
    "font_face", "font_size", "font_bold", "font_scale",
    "margin_top", "margin_bottom", "margin_left", "margin_right",
    "overlap_gap", "truncation_priority",
}

--- Optional settings that a preset may carry. Each key is saved if the
--- preset provides a value, or cleared from settings otherwise. Omit
--- `font_face` — the user's default font is never overridden by a preset.
Config.PRESET_OPTIONAL_KEYS = {
    "text_color", "symbol_color", "background_color",
}

--- Legacy G_reader_settings keys migrated into the plugin's own settings
--- file on first run. Only read once; safe to extend without breaking users.
Config.LEGACY_GLOBAL_KEYS = {
    "enabled", "font_face", "font_size", "font_bold", "font_scale",
    "margin_top", "margin_bottom", "margin_left", "margin_right",
    "overlap_gap", "truncation_priority", "presets", "last_cycled_preset",
}

--- Settings keys introduced by the Preset Manager. Documented here so all
--- persistence-related settings are visible in one place. No runtime use.
Config.PRESET_MANAGER_KEYS = {
    "active_preset_filename",        -- string: filename of the currently-open preset
    "preset_cycle",                  -- array of preset filenames
    "preset_manager_migration_done", -- boolean: one-time migration ran
}

return Config
