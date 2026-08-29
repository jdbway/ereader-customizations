--[[
Immich Upload plugin.

Watches KOReader's own screenshots folder and uploads new ones to Immich.
Deliberately NOT a standalone background shell script (the previous
design, on both Kindle and Kobo): a shell process outside KOReader can't
call into KOReader's own Wi-Fi management, so it either had to assume
Wi-Fi/Tailscale was already up (silently failing otherwise) or be tied to
whenever Tailscale happened to be started -- neither of which is "only
touch the network when there's actually something new to upload."

This plugin's periodic check (CHECK_INTERVAL) is a local directory
listing only -- zero network activity. Only once a screenshot not already
in the uploaded-state file is found does it call NetworkMgr's normal
"ensure Wi-Fi is on, run this when it is" flow (the same mechanism
crossbill.koplugin's Network.ensureWifiEnabled uses, and the same one
users see as KOReader's ordinary "Connecting to Wi-Fi..." prompt), then
uploads over KOReader's own https client -- no curl/wget dependency.

Device-agnostic with no path-detection logic at all: KOReader's
screenshots folder is always DataStorage:getFullDataDir() .. "/screenshots"
on every platform, so there's nothing to branch on.
]]
local DataStorage = require("datastorage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local socket = require("socket")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local logger = require("logger")
local _ = require("gettext")

local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")

local SERVER = "https://immich.truepob.com"
local CHECK_INTERVAL = 300 -- seconds; local-only, so cheap to run often

local ImmichUpload = WidgetContainer:extend{
    name = "immichupload",
    is_doc_only = false,
}

local function screenshotsDir()
    return DataStorage:getFullDataDir() .. "/screenshots"
end

-- Plugin's own bookkeeping lives in KOReader's settings dir, not inside
-- the folder it's watching.
local function stateFile()
    return DataStorage:getSettingsDir() .. "/immich_uploaded.txt"
end

local function apiKeyFile()
    return DataStorage:getSettingsDir() .. "/immich_api.key"
end

-- Reuses the tailnet hostname already set for `tailscale up` as the
-- Immich deviceId, read directly off disk since it isn't a KOReader
-- setting -- avoids keeping a second per-device identifier in sync.
-- Checked on both known install layouts; harmless if tailscale isn't
-- installed at all (falls through to the fallback id).
local function deviceId()
    local candidates = {
        "/mnt/us/extensions/tailscale/bin/up.args",
        "/mnt/onboard/.adds/tailscale/bin/up.args",
    }
    for _, path in ipairs(candidates) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local hostname = content:match("%-%-hostname=(%S+)")
            if hostname then return hostname end
        end
    end
    return "unknown-device"
end

local function loadUploaded()
    local set = {}
    local f = io.open(stateFile(), "r")
    if not f then return set end
    for line in f:lines() do
        if line ~= "" then set[line] = true end
    end
    f:close()
    return set
end

local function markUploaded(name)
    local f = io.open(stateFile(), "a")
    if f then
        f:write(name, "\n")
        f:close()
    end
end

-- Pure local directory listing -- no network involved.
local function listNewScreenshots()
    if not ok_lfs then
        logger.warn("ImmichUpload: libkoreader-lfs unavailable, skipping check")
        return {}
    end
    local dir = screenshotsDir()
    if lfs.attributes(dir, "mode") ~= "directory" then
        return {}
    end
    local uploaded = loadUploaded()
    local new_files = {}
    for name in lfs.dir(dir) do
        if name:match("%.png$") and not uploaded[name] then
            table.insert(new_files, name)
        end
    end
    return new_files
end

local function readApiKey()
    local f = io.open(apiKeyFile(), "r")
    if not f then return nil end
    local key = f:read("*l")
    f:close()
    return key
end

-- Uploads one screenshot over KOReader's own https client. Assumes the
-- caller has already ensured Wi-Fi is up.
local function uploadOne(name)
    local dir = screenshotsDir()
    local path = dir .. "/" .. name
    local f = io.open(path, "rb")
    if not f then
        logger.warn("ImmichUpload: could not open", path)
        return false
    end
    local data = f:read("*a")
    f:close()

    local api_key = readApiKey()
    if not api_key then
        logger.warn("ImmichUpload: no API key at", apiKeyFile())
        return false
    end

    local attrs = ok_lfs and lfs.attributes(path)
    local mtime = attrs and attrs.modification or os.time()
    local ts = os.date("!%Y-%m-%dT%H:%M:%S.000Z", mtime)
    local dev_id = deviceId()

    local boundary = "----ImmichUpload" .. os.time()
    local function part(fname, value, extra_headers)
        local lines = {
            "--" .. boundary,
            string.format('Content-Disposition: form-data; name="%s"', fname) .. (extra_headers or ""),
            "",
            value,
        }
        return table.concat(lines, "\r\n")
    end

    local body = table.concat({
        part("deviceAssetId", name),
        part("deviceId", dev_id),
        part("fileCreatedAt", ts),
        part("fileModifiedAt", ts),
        table.concat({
            "--" .. boundary,
            string.format('Content-Disposition: form-data; name="assetData"; filename="%s"', name),
            "Content-Type: image/png",
            "",
            data,
        }, "\r\n"),
        "--" .. boundary .. "--",
        "",
    }, "\r\n")

    local response_body = {}
    local code = socket.skip(1, https.request{
        url = SERVER .. "/api/assets",
        method = "POST",
        headers = {
            ["x-api-key"] = api_key,
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Content-Length"] = tostring(#body),
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response_body),
    })
    socketutil:reset_timeout()

    if code == 200 or code == 201 then
        markUploaded(name)
        logger.info("ImmichUpload: uploaded", name)
        return true
    else
        logger.warn("ImmichUpload: failed to upload", name, "code:", code,
            "response:", table.concat(response_body))
        return false
    end
end

local wifi_enabled_by_us = false

local function uploadAll(names)
    for _, name in ipairs(names) do
        uploadOne(name)
    end
    if wifi_enabled_by_us then
        NetworkMgr:turnOffWifi()
        wifi_enabled_by_us = false
    end
end

-- The actual check: local-only unless it finds something. `NetworkMgr:
-- willRerunWhenOnline` is KOReader's standard "ask to enable Wi-Fi, then
-- run this callback once connected" flow -- the same one users see as an
-- ordinary "Connecting to Wi-Fi..." prompt elsewhere in KOReader, not a
-- bespoke mechanism for this plugin.
function ImmichUpload:check()
    local new_files = listNewScreenshots()
    if #new_files > 0 then
        if NetworkMgr:willRerunWhenOnline(function() uploadAll(new_files) end) then
            wifi_enabled_by_us = true
        else
            uploadAll(new_files)
        end
    end
    UIManager:scheduleIn(CHECK_INTERVAL, function() self:check() end)
end

function ImmichUpload:init()
    self:check()
end

return ImmichUpload
