local _ = require("gettext")
return {
    fullname = _("Immich Upload"),
    description = _([[Uploads new KOReader screenshots to Immich, checking locally on a timer and only touching the network (via KOReader's own Wi-Fi manager) once a genuinely new screenshot is found.]]),
}
