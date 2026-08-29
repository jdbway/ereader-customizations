local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local FRAMEWORK_FLAG = "/mnt/us/DONT_START_FRAMEWORK"

local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- Device mount points differ (Kindle: /mnt/us, Kobo: /mnt/onboard), so the
-- tailscale install location can't be a single hardcoded path if this plugin
-- is meant to run on either. Auto-detects by checking known candidate
-- layouts for the actual `tailscale` binary, rather than assuming Kindle.
-- Kobo also runs its daemon on a non-default control socket (its boot
-- script fixes this at /tmp/tailscaled.sock so `tailscale` and `tailscaled`
-- can always find each other regardless of what launched them), so every
-- direct `tailscale <verb>` call this plugin makes needs that flag too —
-- Kindle's daemon uses the compiled-in default and needs no flag at all.
local TS_CANDIDATES = {
    { dir = "/mnt/us/extensions/tailscale/bin", socket = nil },                  -- Kindle (KUAL extensions)
    { dir = "/mnt/onboard/.adds/tailscale/bin", socket = "/tmp/tailscaled.sock" }, -- Kobo (.adds convention)
}

local function detectTailscale()
    for _, c in ipairs(TS_CANDIDATES) do
        if fileExists(c.dir .. "/tailscale") then
            return c.dir, c.socket
        end
    end
    return nil, nil
end

local TS_DIR, TS_SOCKET = detectTailscale()
local SOCK_ARG = TS_SOCKET and (" --socket=" .. TS_SOCKET) or ""

local NetworkExtras = WidgetContainer:extend{
    name = "networkextras",
    is_doc_only = false,
}

local function isTailscaledRunning()
    return os.execute("pgrep -f tailscaled >/dev/null 2>&1") == 0
end

function NetworkExtras:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

-- Polls `tailscale status` a few times after firing the start scripts and
-- reports what actually happened, instead of a blind "Starting…" toast with
-- no way to tell success from failure short of checking manually. Both start
-- scripts run backgrounded (non-blocking for the UI thread), so this is the
-- only way to know the outcome without polling.
function NetworkExtras:checkTailscaleStartResult(attempt)
    local ok = os.execute(TS_DIR .. "/tailscale" .. SOCK_ARG .. " status >/dev/null 2>&1") == 0
    if ok then
        UIManager:show(InfoMessage:new{ text = _("Tailscale connected."), timeout = 3 })
    elseif attempt < 4 then
        UIManager:scheduleIn(4, function() self:checkTailscaleStartResult(attempt + 1) end)
    else
        UIManager:show(InfoMessage:new{
            text = _("Tailscale failed to connect after 3 attempts.\nCheck tailscale_start_log.txt."),
            timeout = 6,
        })
    end
end

function NetworkExtras:startTailscale()
    if not TS_DIR then
        UIManager:show(InfoMessage:new{ text = _("Tailscale not found on this device."), timeout = 3 })
        return
    end
    if isTailscaledRunning() then
        os.execute(TS_DIR .. "/start_tailscale.sh >/dev/null 2>&1 &")
    else
        os.execute(TS_DIR .. "/start_tailscaled_tun.sh >/dev/null 2>&1 &")
        -- Give the daemon a moment to create its control socket before
        -- `start_tailscale.sh` tries `tailscale up` against it. Scheduled
        -- rather than ffiutil.sleep(3), which would block the whole UI.
        UIManager:scheduleIn(3, function()
            os.execute(TS_DIR .. "/start_tailscale.sh >/dev/null 2>&1 &")
        end)
    end
    UIManager:show(InfoMessage:new{ text = _("Starting Tailscale…"), timeout = 2 })
    UIManager:scheduleIn(9, function() self:checkTailscaleStartResult(1) end)
end

function NetworkExtras:stopTailscale()
    if not TS_DIR then
        UIManager:show(InfoMessage:new{ text = _("Tailscale not found on this device."), timeout = 3 })
        return
    end
    local stop_ok = os.execute(TS_DIR .. "/stop_tailscale.sh >/dev/null 2>&1") == 0
    local daemon_ok = os.execute(TS_DIR .. "/stop_tailscaled.sh >/dev/null 2>&1") == 0
    if stop_ok and daemon_ok and not isTailscaledRunning() then
        UIManager:show(InfoMessage:new{ text = _("Tailscale stopped."), timeout = 2 })
    else
        UIManager:show(InfoMessage:new{
            text = _("Tailscale stop reported a problem — check tailscaled_stop_log.txt."),
            timeout = 5,
        })
    end
end

-- update_tailscale.sh only replaces the binaries on disk (backing up the old
-- ones as *.bak first) — it doesn't touch the running process, so it's safe
-- to run while Tailscale is up. Progress prints directly to the screen via
-- eips. Start/Stop Tailscale afterward to actually pick up the new binary.
function NetworkExtras:updateTailscale()
    if not TS_DIR then
        UIManager:show(InfoMessage:new{ text = _("Tailscale not found on this device."), timeout = 3 })
        return
    end
    UIManager:show(ConfirmBox:new{
        text = _("Check for and install the latest Tailscale binaries (~31MB download)? Progress shows on-screen. You'll need to Stop then Start Tailscale afterward for the update to take effect."),
        ok_text = _("Update"),
        ok_callback = function()
            os.execute(TS_DIR .. "/update_tailscale.sh >/dev/null 2>&1 &")
            UIManager:show(InfoMessage:new{ text = _("Checking for updates…"), timeout = 2 })
        end,
    })
end

-- Switching Wi-Fi networks reliably requires the Amazon framework: KOReader's
-- own picker calls com.lab126.cmd's ensureConnection, which is a no-op with
-- the framework disabled, and direct wifid/wpa_supplicant control (wpa_cli,
-- cmConnect, netidValue) proved unreliable against wifid's own independent,
-- undocumented reconnect logic. Toggling the boot flag and rebooting is the
-- only mechanism that's actually deterministic.
function NetworkExtras:rebootWithFramework()
    UIManager:show(ConfirmBox:new{
        text = _("Reboot with the Amazon framework enabled? Wi-Fi network switching only works correctly in this mode. The device will use more power until you switch back."),
        ok_text = _("Reboot"),
        ok_callback = function()
            os.remove(FRAMEWORK_FLAG)
            UIManager:show(InfoMessage:new{ text = _("Rebooting…"), timeout = 2 })
            os.execute("sync; nohup sh -c 'sleep 1; reboot' >/dev/null 2>&1 &")
        end,
    })
end

function NetworkExtras:rebootFrameworkless()
    UIManager:show(ConfirmBox:new{
        text = _("Reboot back into low-power frameworkless mode?"),
        ok_text = _("Reboot"),
        ok_callback = function()
            local f = io.open(FRAMEWORK_FLAG, "w")
            if f then f:close() end
            UIManager:show(InfoMessage:new{ text = _("Rebooting…"), timeout = 2 })
            os.execute("sync; nohup sh -c 'sleep 1; reboot' >/dev/null 2>&1 &")
        end,
    })
end

function NetworkExtras:getFrameworkModeMenu()
    local frameworkless = fileExists(FRAMEWORK_FLAG)
    return {
        {
            text = frameworkless and _("Currently: frameworkless (low power)") or _("Currently: framework enabled"),
            enabled = false,
        },
        {
            text = _("Reboot with framework (to switch Wi-Fi)"),
            keep_menu_open = true,
            callback = function() self:rebootWithFramework() end,
        },
        {
            text = _("Reboot frameworkless (low power)"),
            keep_menu_open = true,
            callback = function() self:rebootFrameworkless() end,
        },
    }
end

-- Plain-text `tailscale status` is used instead of --json to avoid depending
-- on a JSON decoder being available in every KOReader build; the self row's
-- column layout (ip, hostname, user, os, ...) has been stable across the
-- versions this device has run.
function NetworkExtras:getTailscaleStatusText()
    if not TS_DIR then
        return _("Tailscale: not found on this device")
    end
    if not isTailscaledRunning() then
        return _("Tailscale: not running")
    end

    local handle = io.popen(TS_DIR .. "/tailscale" .. SOCK_ARG .. " status --self --peers=false 2>&1")
    local output = handle and handle:read("*a") or ""
    if handle then handle:close() end
    output = output:gsub("^%s+", ""):gsub("%s+$", "")

    if output == "" then
        return _("Tailscale: running, but status unavailable")
    elseif output:match("Tailscale is stopped") then
        return _("Tailscale: stopped")
    elseif output:match("Logged out") then
        return _("Tailscale: logged out")
    elseif output:match("NeedsMachineAuth") then
        return _("Tailscale: awaiting authorization")
    end

    local ip, hostname = output:match("^(%S+)%s+(%S+)")
    if ip then
        return string.format(_("Tailscale: connected\nIP: %s\nHost: %s"), ip, hostname or "?")
    end
    return _("Tailscale:\n") .. output
end

function NetworkExtras:showTailscaleStatus()
    UIManager:show(InfoMessage:new{
        text = self:getTailscaleStatusText(),
        timeout = 5,
    })
end

function NetworkExtras:onStartTailscale()
    self:startTailscale()
end

function NetworkExtras:onStopTailscale()
    self:stopTailscale()
end

function NetworkExtras:onShowTailscaleStatus()
    self:showTailscaleStatus()
end

function NetworkExtras:onDispatcherRegisterActions()
    Dispatcher:registerAction("start_tailscale",
        { category = "none", event = "StartTailscale", title = _("Start Tailscale"), general = true })
    Dispatcher:registerAction("stop_tailscale",
        { category = "none", event = "StopTailscale", title = _("Stop Tailscale"), general = true })
    Dispatcher:registerAction("show_tailscale_status",
        { category = "none", event = "ShowTailscaleStatus", title = _("Tailscale Status"), general = true })
end

function NetworkExtras:addToMainMenu(menu_items)
    local sub_item_table = {}

    -- Framework Mode is an Amazon-framework concept with no Kobo equivalent
    -- (KOReader manages Wi-Fi directly there) — showing it unconditionally
    -- would let a Kobo user "reboot frameworkless" into a Kindle-only path
    -- (/mnt/us/DONT_START_FRAMEWORK) that doesn't exist on their device,
    -- rebooting it for nothing.
    if Device:isKindle() then
        table.insert(sub_item_table, {
            text = _("Framework Mode"),
            sub_item_table_func = function() return self:getFrameworkModeMenu() end,
        })
    end

    table.insert(sub_item_table, {
        text = _("Tailscale Status"),
        keep_menu_open = true,
        callback = function() self:showTailscaleStatus() end,
    })
    table.insert(sub_item_table, {
        text = _("Start Tailscale"),
        keep_menu_open = true,
        callback = function() self:startTailscale() end,
    })
    table.insert(sub_item_table, {
        text = _("Stop Tailscale"),
        keep_menu_open = true,
        callback = function() self:stopTailscale() end,
    })
    table.insert(sub_item_table, {
        text = _("Update Tailscale"),
        keep_menu_open = true,
        callback = function() self:updateTailscale() end,
    })

    menu_items.network_extras = {
        sorting_hint = "tools",
        text = _("Network Extras"),
        sub_item_table = sub_item_table,
    }
end

return NetworkExtras
