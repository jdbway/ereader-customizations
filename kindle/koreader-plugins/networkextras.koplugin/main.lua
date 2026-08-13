local ConfirmBox = require("ui/widget/confirmbox")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiutil = require("ffi/util")
local _ = require("gettext")

local TS_DIR = "/mnt/us/extensions/tailscale/bin"
local FRAMEWORK_FLAG = "/mnt/us/DONT_START_FRAMEWORK"

local NetworkExtras = WidgetContainer:extend{
    name = "networkextras",
    is_doc_only = false,
}

local function isTailscaledRunning()
    return os.execute("pgrep -f tailscaled >/dev/null 2>&1") == 0
end

local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

function NetworkExtras:init()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

function NetworkExtras:startTailscale()
    if not isTailscaledRunning() then
        os.execute(TS_DIR .. "/start_tailscaled_tun.sh >/dev/null 2>&1 &")
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
            enabled = frameworkless,
            keep_menu_open = true,
            callback = function() self:rebootWithFramework() end,
        },
        {
            text = _("Reboot frameworkless (low power)"),
            enabled = not frameworkless,
            keep_menu_open = true,
            callback = function() self:rebootFrameworkless() end,
        },
    }
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
        text = _("Network Extras"),
        sub_item_table = {
            {
                text = _("Framework Mode"),
                sub_item_table_func = function() return self:getFrameworkModeMenu() end,
            },
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
        }
    }
end

return NetworkExtras
