# Kobo setup

Not started yet. Planning notes:

- Leaning toward Kobo over buying more Kindles for the nephew e-reader fleet:
  KOReader manages Wi-Fi directly on Kobo (a real network picker, not the
  toggle-only, framework-dependent mess on Kindle), and `advboot`/KSM gives a
  boot-time Nickel-vs-KOReader picker with an autoselect timeout — a lower-risk
  equivalent to the Kindle's Framework Mode reboot toggle, without needing to
  touch upstart/boot files the way Kindle autostart does.
- Existing device `kobo-sabrina` is on the tailnet already; still need to
  confirm it's running Tailscale in real TUN mode (not the userspace/SOCKS5
  proxy fallback some jailbroken readers need) and check why its MagicDNS
  apparently works with no watcher script needed, unlike the Kindle.
- `cwasync.koplugin` (see `../kindle/README.md`) should work here too with no
  Kobo-specific changes — it already ships a `kobo_sqlite_provider.lua` for
  bridging highlights into stock Nickel, though that's unrelated to progress
  sync itself, which is fully cross-platform.
