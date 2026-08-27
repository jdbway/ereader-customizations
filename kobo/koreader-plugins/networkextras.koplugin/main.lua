local ConfirmBox = require("ui/widget/confirmbox")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local _ = require("gettext")

local TS_DIR = "/mnt/onboard/.adds/tailscale/bin"

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

function NetworkExtras:startTailscale()
    if not isTailscaledRunning() then
        os.execute(TS_DIR .. "/start_tailscaled.sh >/dev/null 2>&1")
        ffiutil.sleep(3)
    end
    os.execute(TS_DIR .. "/start_tailscale.sh >/dev/null 2>&1 &")
    UIManager:show(InfoMessage:new{ text = _("Starting Tailscale…"), timeout = 2 })
end

function NetworkExtras:stopTailscale()
    os.execute(TS_DIR .. "/stop_tailscale.sh >/dev/null 2>&1")
    os.execute(TS_DIR .. "/stop_tailscaled.sh >/dev/null 2>&1")
    UIManager:show(InfoMessage:new{ text = _("Tailscale stopped."), timeout = 2 })
end

-- update_tailscale.sh only replaces the binaries on disk (backing up the old
-- ones as *.bak first) — it doesn't touch the running process, so it's safe
-- to run while Tailscale is up. Start/Stop Tailscale afterward to actually
-- pick up the new binary.
function NetworkExtras:updateTailscale()
    UIManager:show(ConfirmBox:new{
        text = _("Check for and install the latest Tailscale binaries (~31MB download)? You'll need to Stop then Start Tailscale afterward for the update to take effect."),
        ok_text = _("Update"),
        ok_callback = function()
            os.execute(TS_DIR .. "/update_tailscale.sh >/dev/null 2>&1 &")
            UIManager:show(InfoMessage:new{ text = _("Checking for updates… see tailscale/bin/update_log.txt for progress."), timeout = 3 })
        end,
    })
end

function NetworkExtras:onStartTailscale()
    self:startTailscale()
end

function NetworkExtras:onStopTailscale()
    self:stopTailscale()
end

function NetworkExtras:onDispatcherRegisterActions()
    Dispatcher:registerAction("start_tailscale",
        { category = "none", event = "StartTailscale", title = _("Start Tailscale"), general = true })
    Dispatcher:registerAction("stop_tailscale",
        { category = "none", event = "StopTailscale", title = _("Stop Tailscale"), general = true })
end

function NetworkExtras:addToMainMenu(menu_items)
    menu_items.network_extras = {
        sorting_hint = "tools",
        text = _("Network Extras"),
        sub_item_table = {
            {
                text = _("Start Tailscale"),
                keep_menu_open = true,
                callback = function() self:startTailscale() end,
            },
            {
                text = _("Stop Tailscale"),
                keep_menu_open = true,
                callback = function() self:stopTailscale() end,
            },
            {
                text = _("Update Tailscale"),
                keep_menu_open = true,
                callback = function() self:updateTailscale() end,
            },
        }
    }
end

return NetworkExtras
