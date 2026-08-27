local _ = require("gettext")
return {
    name = "wifiwatchdogtune",
    fullname = _("Wi-Fi Auto-off Tuning"),
    description = _([[Adjusts the timing/threshold constants in KOReader's core "disable Wi-Fi when inactive" watchdog (frontend/ui/network/networklistener.lua) via a menu instead of hand-editing the file. Useful when a device has enough baseline background chatter (e.g. a vendor telemetry daemon) that the stock threshold never lets Wi-Fi turn off. These are core KOReader constants, not a saved setting - a full KOReader reinstall/update will reset them to stock, and any change here needs a KOReader restart to take effect.]]),
}
