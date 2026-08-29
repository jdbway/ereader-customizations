-- Not a drop-in settings/bookshelf.lua -- this is just the `tabs` key,
-- confirmed working on kobo-sabrina (2026-08-29). Merge this key into a
-- device's real settings/bookshelf.lua (which also holds unrelated keys
-- like start_menu_items, active_chip, etc.) rather than overwriting the
-- whole file. See BASE_SETUP.md's "Bookshelf chip bar" section for how
-- the id="504150a3" hash was computed (a djb2 digest of
-- https://calibre.truepob.com/opds) and for the exact steps if this
-- OPDS server URL ever changes.
return {
    ["tabs"] = {
        [1] = { ["id"] = "all", ["label"] = "Home", ["source"] = { ["kind"] = "all" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "filename", ["reverse"] = false } },
                ["enabled"] = true },
        [2] = { ["id"] = "recent", ["label"] = "Recent", ["source"] = { ["kind"] = "recent" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "last_opened", ["reverse"] = true } },
                ["enabled"] = true },
        [3] = { ["id"] = "opds_504150a3", ["label"] = "Calibre",
                ["source"] = { ["kind"] = "opds", ["id"] = "504150a3" },
                ["filter"] = {}, ["sort_priority"] = {},
                ["enabled"] = true },
        [4] = { ["id"] = "latest", ["label"] = "Latest", ["source"] = { ["kind"] = "latest" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "date_added", ["reverse"] = true } },
                ["enabled"] = false },
        [5] = { ["id"] = "series", ["label"] = "Series", ["source"] = { ["kind"] = "series" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "series_name", ["reverse"] = false } },
                ["enabled"] = false },
        [6] = { ["id"] = "authors", ["label"] = "Authors", ["source"] = { ["kind"] = "authors" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "author_surname", ["reverse"] = false } },
                ["enabled"] = false },
        [7] = { ["id"] = "genres", ["label"] = "Genres", ["source"] = { ["kind"] = "genres" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "book_count", ["reverse"] = true } },
                ["enabled"] = false },
        [8] = { ["id"] = "tags", ["label"] = "Tags", ["source"] = { ["kind"] = "tags" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "book_count", ["reverse"] = true } },
                ["enabled"] = false },
        [9] = { ["id"] = "languages", ["label"] = "Languages", ["source"] = { ["kind"] = "languages" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "book_count", ["reverse"] = true } },
                ["enabled"] = false },
        [10] = { ["id"] = "favorites", ["label"] = "Favourites", ["source"] = { ["kind"] = "favorites" },
                ["filter"] = {}, ["sort_priority"] = { [1] = { ["key"] = "date_added", ["reverse"] = true } },
                ["enabled"] = false },
    },
}
