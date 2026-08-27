local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local SpinWidget = require("ui/widget/spinwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- Core KOReader file, not a plugin/setting - lives under /mnt/us so it's
-- always writable regardless of the device's root-fs read-only state, but
-- a full KOReader reinstall/update will reset it to stock. Path is fixed
-- rather than derived, since this plugin only makes sense bundled with the
-- exact KOReader tree it's patching.
local TARGET_FILE = "/mnt/us/koreader/frontend/ui/network/networklistener.lua"

local WifiWatchdogTune = WidgetContainer:extend{
    name = "wifiwatchdogtune",
    is_doc_only = false,
}

-- These three are plain `local`s in networklistener.lua, not fields on an
-- exported table - there's no live reference a plugin could require() and
-- reassign. Reading/writing the file directly (and requiring a restart to
-- pick up the change) is the only way to adjust them from outside that file.
local function readCurrentValues()
    local f = io.open(TARGET_FILE, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local first_check_min = content:match("local default_network_timeout_seconds = (%d+)%*60")
    local max_check_min = content:match("local max_network_timeout_seconds = (%d+)%*60")
    local noise_margin = content:match("local network_activity_noise_margin = (%d+)")

    if not (first_check_min and max_check_min and noise_margin) then
        return nil
    end
    return {
        first_check_min = tonumber(first_check_min),
        max_check_min = tonumber(max_check_min),
        noise_margin = tonumber(noise_margin),
    }
end

-- Targeted substring replacement - only the matched constant's line is
-- touched, everything else (comments, formatting, the rest of the file)
-- is left exactly as-is.
local function patchValue(pattern, replacement)
    local f = io.open(TARGET_FILE, "r")
    if not f then return false, _("Could not open networklistener.lua") end
    local content = f:read("*a")
    f:close()

    local new_content, count = content:gsub(pattern, replacement, 1)
    if count == 0 then
        return false, _("Pattern not found - core file may have changed format")
    end

    local out = io.open(TARGET_FILE, "w")
    if not out then return false, _("Could not write networklistener.lua") end
    out:write(new_content)
    out:close()
    return true
end

local function showResult(ok, err)
    if ok then
        UIManager:show(InfoMessage:new{
            text = _("Saved. Restart KOReader for the new value to take effect."),
            timeout = 4,
        })
    else
        UIManager:show(InfoMessage:new{ text = err, timeout = 4 })
    end
end

function WifiWatchdogTune:init()
    self.ui.menu:registerToMainMenu(self)
end

function WifiWatchdogTune:editFirstCheck()
    local current = readCurrentValues()
    if not current then
        UIManager:show(InfoMessage:new{ text = _("Could not read current settings."), timeout = 3 })
        return
    end
    UIManager:show(SpinWidget:new{
        title_text = _("First Wi-Fi activity check"),
        info_text = _("Minutes of idle time before the first check of whether Wi-Fi can be turned off. KOReader default: 5."),
        value = current.first_check_min,
        value_min = 1,
        value_max = 60,
        value_step = 1,
        ok_text = _("Save"),
        callback = function(spin)
            local ok, err = patchValue(
                "local default_network_timeout_seconds = %d+%*60",
                "local default_network_timeout_seconds = " .. spin.value .. "*60")
            showResult(ok, err)
        end,
    })
end

function WifiWatchdogTune:editMaxCheck()
    local current = readCurrentValues()
    if not current then
        UIManager:show(InfoMessage:new{ text = _("Could not read current settings."), timeout = 3 })
        return
    end
    UIManager:show(SpinWidget:new{
        title_text = _("Backoff ceiling"),
        info_text = _("Longest interval the check backs off to when Wi-Fi keeps looking active. KOReader default: 30."),
        value = current.max_check_min,
        value_min = 5,
        value_max = 120,
        value_step = 5,
        ok_text = _("Save"),
        callback = function(spin)
            local ok, err = patchValue(
                "local max_network_timeout_seconds = %d+%*60",
                "local max_network_timeout_seconds = " .. spin.value .. "*60")
            showResult(ok, err)
        end,
    })
end

function WifiWatchdogTune:editNoiseMargin()
    local current = readCurrentValues()
    if not current then
        UIManager:show(InfoMessage:new{ text = _("Could not read current settings."), timeout = 3 })
        return
    end
    UIManager:show(SpinWidget:new{
        title_text = _("Noise margin"),
        info_text = _([[How many packets of traffic in the check window still count as "idle enough" to disable Wi-Fi. KOReader default: 12. Raise this if background chatter (e.g. a vendor telemetry daemon) keeps Wi-Fi from ever turning off.]]),
        value = current.noise_margin,
        value_min = 1,
        value_max = 200,
        value_step = 1,
        ok_text = _("Save"),
        callback = function(spin)
            local ok, err = patchValue(
                "local network_activity_noise_margin = %d+",
                "local network_activity_noise_margin = " .. spin.value)
            showResult(ok, err)
        end,
    })
end

function WifiWatchdogTune:getMenuItems()
    local current = readCurrentValues()
    local status_text = current
        and string.format(_("Current: %d min first check, %d min backoff ceiling, %d packet margin"),
            current.first_check_min, current.max_check_min, current.noise_margin)
        or _("Could not read current settings")

    return {
        { text = status_text, enabled = false },
        {
            text = _("First check delay"),
            keep_menu_open = true,
            callback = function() self:editFirstCheck() end,
        },
        {
            text = _("Backoff ceiling"),
            keep_menu_open = true,
            callback = function() self:editMaxCheck() end,
        },
        {
            text = _("Noise margin"),
            keep_menu_open = true,
            callback = function() self:editNoiseMargin() end,
        },
    }
end

function WifiWatchdogTune:addToMainMenu(menu_items)
    menu_items.wifi_watchdog_tune = {
        sorting_hint = "tools",
        text = _("Wi-Fi Auto-off Tuning"),
        sub_item_table_func = function() return self:getMenuItems() end,
    }
end

return WifiWatchdogTune
