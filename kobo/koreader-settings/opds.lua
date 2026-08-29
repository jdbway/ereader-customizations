-- ./settings/opds.lua
--
-- PASSWORD for the Calibre entry INTENTIONALLY BLANKED before committing to
-- git — fill in manually after copying this file to a device's
-- koreader/settings/ directory. The public feeds (Gutenberg, Standard
-- Ebooks, etc.) have no credentials and are safe as-is.
return {
    ["downloads"] = {},
    ["pending_syncs"] = {},
    ["servers"] = {
        [1] = {
            ["title"] = "Project Gutenberg",
            ["url"] = "https://m.gutenberg.org/ebooks.opds/?format=opds",
        },
        [2] = {
            ["title"] = "Standard Ebooks",
            ["url"] = "https://standardebooks.org/feeds/opds",
        },
        [3] = {
            ["title"] = "ManyBooks",
            ["url"] = "http://manybooks.net/opds/index.php",
        },
        [4] = {
            ["title"] = "Internet Archive",
            ["url"] = "https://bookserver.archive.org/",
        },
        [5] = {
            ["title"] = "textos.info (Spanish)",
            ["url"] = "https://www.textos.info/catalogo.atom",
        },
        [6] = {
            ["title"] = "Gallica (French)",
            ["url"] = "https://gallica.bnf.fr/opds",
        },
        [7] = {
            ["password"] = "",
            ["title"] = "Calibre",
            ["url"] = "https://calibre.truepob.com/opds",
            ["username"] = "admin",
        },
    },
    ["settings"] = {
        ["sync_dir"] = "/mnt/onboard/.adds/koreader/data",
    },
}
