-- ./settings/kosync.lua
--
-- No credentials stored here (KOReader's native kosync protocol uses a
-- hashed-password login handled separately at login time, not persisted in
-- this file) — safe as-is.
return {
    ["settings"] = {
        ["auto_sync"] = false,
        ["checksum_method"] = 0,
        ["custom_server"] = "https://calibre.truepob.com/kosync",
        ["sync_backward"] = 3,
        ["sync_forward"] = 1,
    },
}
