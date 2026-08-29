-- ./settings/wallabag.lua
--
-- PASSWORD INTENTIONALLY BLANKED before committing to git — fill in
-- manually after copying this file to a device's koreader/settings/
-- directory. client_id/client_secret are this Wallabag instance's OAuth
-- app credentials, not a personal secret, but treat as sensitive too.
return {
    ["wallabag"] = {
        ["archive_abandoned"] = false,
        ["archive_directory"] = "/mnt/onboard/Books/Wallabag/archive",
        ["archive_finished"] = true,
        ["archive_read"] = false,
        ["articles_per_sync"] = 30,
        ["auto_archive"] = false,
        ["auto_tags"] = "",
        ["client_id"] = "",
        ["client_secret"] = "",
        ["delete_instead"] = false,
        ["directory"] = "/mnt/onboard/Books/Wallabag",
        ["download_original_document"] = false,
        ["file_block_timeout"] = 15,
        ["file_total_timeout"] = 60,
        ["filter_starred"] = false,
        ["filter_tag"] = "",
        ["ignore_tags"] = "",
        ["large_block_timeout"] = 10,
        ["large_total_timeout"] = 30,
        ["offline_queue"] = {},
        ["password"] = "",
        ["remove_abandoned_from_history"] = false,
        ["remove_finished_from_history"] = false,
        ["remove_read_from_history"] = false,
        ["send_review_as_tags"] = false,
        ["server_url"] = "https://wallabag.truepob.com",
        ["sync_remote_archive"] = false,
        ["use_local_archive"] = false,
        ["username"] = "jon",
    },
}
