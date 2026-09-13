# Calendar replacement research (KOrganizer → light frontend)

- **Date:** 2026-09-13
- **Status:** Closed. Decision (2026-09-13): keep flatpak Kontact as the
  calendar; host korganizer rpm uninstalled. GNOME Calendar / khal not pursued.

## Symptom / question

KOrganizer (layered rpm) drags in the Akonadi PIM stack: 10 always-on
daemons (incl. mysqld, 477 MB RSS measured), 127 MB of DB data in
`~/.local/share/akonadi`, 69 MB PIM rpms + 624 MB KF6/Qt6 deps. It also
re-injected `KDE_SESSION_VERSION`/`XDG_CURRENT_DESKTOP` into the systemd
user environment, which broke Firefox "Open Containing Folder" (fixed by
removing the env hack, see git log f36f79c). What are lighter replacements
compatible with a self-hosted Radicale server whose storage folder is
Syncthing-synced?

## Findings (verified Sep 2026)

### Disqualified
- **Merkuro** (Kalendar successor): still hard-requires Akonadi + kdepim-runtime.
- **Osmo**: stale (2020), no CalDAV.
- **etm**: EOL Mar 2026, replaced by `tklr` (TUI).

### Candidates compared

| App | Install on Sericea | Daemons | Radicale | Tasks (VTODO) | Notes |
|---|---|---|---|---|---|
| **khal + vdirsyncer** | pipx/distrobox (no reboot) | None | ✅ vdirsyncer is CI-tested against Radicale | ❌ | TUI; can read Syncthing-synced vdir copy directly (offline); reminders via timer+notify-send |
| **GNOME Calendar** (Flatpak) | flatpak + host `evolution-data-server` rpm layer (reboot) | 3–4 EDS processes, on-demand | ⚠️ works, most EDS↔Radicale edge cases (discovery fixed 2022, VTIMEZONE write 400s, URL must include username) | ❌ events-only, declined by design (gnome-calendar#713); VTODOs visible in GNOME Tasks/Endeavour via shared EDS | Reminders via host `evolution-alarm-notify` (needs `exec` line in sway config; XDG autostart does NOT run on sway); dunst renders GNotification |
| **Thunderbird** (Flatpak) | already installed | None | ✅ officially supported client | ⚠️ partial (one list reliably) | Mail-first UX (donate tab nags); must run for its own alarms — moot if phone does reminders |
| **Eventix** (Flatpak) | flatpak | None | ✅ CalDAV via bundled vdirsyncer | ✅ | Brand new (Flathub 2026-05), unproven, no dark theme |
| **Calindori** | rpm layer (~1 MB, 17 deps) | None — explicitly no Akonadi | ⚠️ local files only; needs vdirsyncer sidecar | local | Mobile-first UX |
| **calcurse** | tiny rpm/distrobox | 1 optional daemon | ❓ unverified | ✅ | TUI; CalDAV experimental |
| **InfCloud web UI** | zero (Radicale `[web]` plugin) | none | ✅ served by Radicale | ✅ | UI frozen at 2015 |

### Syncthing-over-Radicale-storage safety
Live-syncing Radicale's storage folder while the server runs is **not a
supported pattern**: external writes bypass the server (hooks never run,
maintainer statement in Radicale PR #1092), `.Radicale.lock` doesn't cross
machines (split-brain → `.sync-conflict-*` duplicates ingested as distinct
events), partial transfers can be read mid-sync. Recommended patterns:
1. One Radicale, all clients over CalDAV (conflict-free).
2. khal reading a Syncthing **copy** (exclude `.Radicale.cache/`,
   `.Radicale.lock`), read-only, with vdirsyncer-over-CalDAV as write path.
3. Live-tree sync only with single writer + Radicale stopped during sync.

## Decision state
- **Final decision (2026-09-13): compromise on flatpak Kontact.** The
  `$mod+Alt+c` keybind (commit d9869bf) launches flatpak
  `org.kde.kontact` (6.6.3) and that is now the permanent setup. The host
  korganizer rpm was uninstalled (confirmed gone after the 2026-09-13
  reboot, alongside the queued dolphin uninstall); the host Akonadi
  stack (10 daemons, mysqld, ~700 MB) is gone. Kontact still runs its
  own bundled Akonadi *inside the flatpak sandbox* — contained, no host
  env pollution, no host MySQL.
- GNOME Calendar and khal were not pursued; the research above remains
  valid as fallbacks if the flatpak Kontact trade-off stops being
  acceptable.
- **Correction to the symptom section:** the persistent
  `KDE_SESSION_VERSION`/`KDE_FULL_SESSION`/`XDG_CURRENT_DESKTOP` vars
  were *not* (only) injected by the Akonadi stack — the durable source
  is `~/.config/environment.d/kde-apps.conf` ("Help KDE applications
  pick up dark color scheme from kdeglobals"), which re-applies them at
  every login. After the reboot that removed both rpms, the vars were
  present again within seconds of `systemctl --user unset-environment`.
  With dolphin uninstalled, the Firefox "Open Containing Folder"→Dolphin
  misroute is moot (the target binary no longer exists); the vars'
  remaining effect is KDE/Qt dark theming. Disposition of that env file
  is tracked separately.

## Caveats
- EDS↔Radicale has the most historical edge cases of any client; keep both
  current. Fallbacks already vetted: Thunderbird-as-calendar, khal.
- GNOME Tasks/Endeavour (VTODO viewer) is maintenance mode (no release
  since 43.0/2022); successor-pattern app: Errands.
