-- ./settings/bookshelf.lua
return {
    ["active_chip"] = "recent",
    ["active_cursor"] = 1,
    ["active_page"] = 1,
    ["author_format"] = "first_last",
    ["aux_data_relocated_v2"] = true,
    ["bookshelf_columns"] = 4,
    ["bookshelf_fonts_seeded"] = true,
    ["bookshelf_rows"] = 1,
    ["bookshelf_ui_font"] = "RobotoCondensed-Regular.ttf",
    ["check_updates"] = true,
    ["chip_flex_widths"] = true,
    ["desc_font_size"] = 20,
    ["drill_path"] = {},
    ["fullscreen_module_items"] = {
        [1] = {
            ["id"] = "fsm6",
            ["module"] = "clock",
            ["type"] = "module",
        },
        [2] = {
            ["id"] = "fsm4",
            ["module"] = "reading_streak",
            ["type"] = "module",
        },
    },
    ["fullscreen_module_next_id"] = 9,
    ["fullscreen_modules_seeded"] = true,
    ["hero_module_items"] = {
        [1] = {
            ["id"] = "hm_clock",
            ["module"] = "analogue_clock",
            ["type"] = "module",
        },
    },
    ["hero_modules_seeded"] = true,
    ["home_expanded"] = false,
    ["last_install_source"] = "release",
    ["micro_modules_placement"] = "fullscreen",
    ["migrated"] = true,
    ["opds_descriptions"] = {
        ["/mnt/us/koreader/epubs/books/The Gate of the Feral Gods.epub"] = "New Achievement! Total, Utter Failure. You failed a quest less than five minutes after you received it. Now that’s talent. A floating fortress occupied by warrior gnomes. A castle made of sand. A derelict submarine guarded by malfunctioning machines. A haunted crypt surrounded by lethal traps. It was supposed to be easy. One bubble. Four castles. Fifteen days. Capture each one, and the stairwell is unlocked. Here's the thing. It's never easy. Carl and his team can't go it alone. Not this time. They must rely on the help of the low-level, I-can't-believe-these-idiots-are-still-alive crawlers trapped in the bubble with them. But can they be trusted? Welcome, Crawler. Welcome to the fifth floor of the dungeon.",
    },
    ["opds_downloads"] = {
        ["OPDS://504150a3/urn:uuid:8ab0fd59-eb9c-46e5-ba03-27e9a44be1ad"] = "/mnt/us/koreader/epubs/books/The Gate of the Feral Gods.epub",
    },
    ["quote_of_day_daily_cache"] = {
        ["data"] = {
            ["author"] = "John Keegan",
            ["filepath"] = "/mnt/us/koreader/epubs/books/John Keegan - The First World War.epub",
            ["page"] = "/body/DocFragment[7]/body/p[102]/span[1]/text().0",
            ["pos0"] = "/body/DocFragment[7]/body/p[102]/span[1]/text().0",
            ["text"] = "Durchhalten",
            ["title"] = "The First World War",
        },
        ["key"] = "d2026-08-13:0",
    },
    ["reader_menu_button"] = false,
    ["start_menu_items"] = {
        [1] = {
            ["id"] = "sm_quote",
            ["module"] = "quote_of_day",
            ["type"] = "module",
        },
        [2] = {
            ["icon"] = "⚙",
            ["id"] = "sm_settings",
            ["internal"] = "settings",
            ["label"] = "Bookshelf menu",
            ["type"] = "action",
        },
        [3] = {
            ["icon"] = "",
            ["id"] = "sm8",
            ["label"] = "Calibre Sync",
            ["menu_path"] = {
                [1] = {
                    ["id"] = "tools",
                },
                [2] = {
                    ["id"] = "cwa_progress_sync",
                },
                [3] = {
                    ["text"] = "Push progress from this device now",
                },
            },
            ["type"] = "action",
        },
        [4] = {
            ["action"] = {
                ["stats_calendar_view"] = true,
            },
            ["icon"] = "",
            ["id"] = "sm_cal",
            ["label"] = "Reading calendar",
            ["type"] = "action",
        },
        [5] = {
            ["icon"] = "",
            ["id"] = "sm10",
            ["label"] = "Vocabulary builder",
            ["menu_path"] = {
                [1] = {
                    ["id"] = "search",
                },
                [2] = {
                    ["id"] = "vocabbuilder",
                },
            },
            ["type"] = "action",
        },
        [6] = {
            ["icon"] = "",
            ["id"] = "sm9",
            ["label"] = "ReadMastery",
            ["plugin"] = {
                ["key"] = "ReadMastery",
                ["method"] = "__menu_submenu",
            },
            ["type"] = "action",
        },
        [7] = {
            ["icon"] = "",
            ["id"] = "sm4",
            ["label"] = "Calibre Sync",
            ["menu_path"] = {
                [1] = {
                    ["id"] = "tools",
                },
                [2] = {
                    ["id"] = "cwa_progress_sync",
                },
                [3] = {
                    ["text"] = "Push progress from this device now (No Active Document)",
                },
            },
            ["type"] = "action",
        },
        [8] = {
            ["icon"] = "",
            ["id"] = "sm_close",
            ["internal"] = "close",
            ["label"] = "Exit bookshelf",
            ["scope"] = "library",
            ["type"] = "action",
        },
        [9] = {
            ["icon"] = "",
            ["id"] = "sm_reader_home",
            ["label"] = "Close book",
            ["menu_path"] = {
                [1] = {
                    ["id"] = "filemanager",
                },
            },
            ["scope"] = "reader",
            ["type"] = "action",
        },
        [10] = {
            ["action"] = {
                ["suspend"] = true,
            },
            ["icon"] = "",
            ["id"] = "sm_sleep",
            ["label"] = "Sleep",
            ["type"] = "action",
        },
    },
    ["start_menu_next_id"] = 11,
    ["start_menu_seeded"] = true,
    ["tabs"] = {
        [1] = {
            ["enabled"] = true,
            ["filter"] = {},
            ["id"] = "all",
            ["label"] = "Home",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "filename",
                    ["reverse"] = false,
                },
            },
            ["source"] = {
                ["kind"] = "all",
            },
        },
        [2] = {
            ["enabled"] = true,
            ["filter"] = {},
            ["id"] = "recent",
            ["label"] = "Recent",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "last_opened",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "recent",
            },
        },
        [3] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "latest",
            ["label"] = "Latest",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "date_added",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "latest",
            },
        },
        [4] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "series",
            ["label"] = "Series",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "series_name",
                    ["reverse"] = false,
                },
            },
            ["source"] = {
                ["kind"] = "series",
            },
        },
        [5] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "authors",
            ["label"] = "Authors",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "author_surname",
                    ["reverse"] = false,
                },
            },
            ["source"] = {
                ["kind"] = "authors",
            },
        },
        [6] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "genres",
            ["label"] = "Genres",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "book_count",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "genres",
            },
        },
        [7] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "tags",
            ["label"] = "Tags",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "book_count",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "tags",
            },
        },
        [8] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "languages",
            ["label"] = "Languages",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "book_count",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "languages",
            },
        },
        [9] = {
            ["enabled"] = false,
            ["filter"] = {},
            ["id"] = "favorites",
            ["label"] = "Favourites",
            ["sort_priority"] = {
                [1] = {
                    ["key"] = "date_added",
                    ["reverse"] = true,
                },
            },
            ["source"] = {
                ["kind"] = "favorites",
            },
        },
        [10] = {
            ["enabled"] = true,
            ["filter"] = {},
            ["id"] = "custom_2",
            ["label"] = "Calibre",
            ["sort_priority"] = {},
            ["source"] = {
                ["id"] = "504150a3",
                ["kind"] = "opds",
            },
        },
    },
    ["tags_font_size"] = 20,
}
