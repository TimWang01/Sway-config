# Calendar replacement research (KOrganizer → light frontend)

- **Date:** 2026-09-13
- **Status:** Research-only; decision pending. No implementation committed.

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
- User's reminders fire on their phone → desktop only needs view/edit.
- Lean path: uninstall korganizer (reclaims ~700 MB layered packages via
  rpm-ostree orphan removal, kills Akonadi permanently); replacement
  undecided between GNOME Calendar (chosen direction as of this session:
  mature, light, events-only acceptable) and khal (zero-daemon TUI).
- `$mod+Alt+c` now launches flatpak `org.kde.kontact` (commit d9869bf) —
  interim step; sandboxed Kontact still runs its own bundled Akonadi
  inside the flatpak sandbox but cannot touch host env vars.
- GNOME Calendar setup prerequisites (if chosen): `rpm-ostree install
  evolution-data-server` → reboot → flatpak install → Radicale account
  with full principal URL incl. username (`https://host:5232/<user>/`) →
  `gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'`.
- Optional desktop reminders: `exec /usr/libexec/evolution-data-server/evolution-alarm-notify`
  in sway config (EDS factories are D-Bus-activatable; no dex needed).

## Caveats
- EDS↔Radicale has the most historical edge cases of any client; keep both
  current. Fallbacks already vetted: Thunderbird-as-calendar, khal.
- GNOME Tasks/Endeavour (VTODO viewer) is maintenance mode (no release
  since 43.0/2022); successor-pattern app: Errands.
