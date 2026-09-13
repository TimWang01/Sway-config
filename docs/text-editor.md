# Text editor decision (flatpak KWrite retained)

- **Date:** 2026-09-13
- **Status:** Closed. Keeping flatpak KWrite; research persisted for future reference.

## Question

Alternatives to KWrite for this machine (Fedora Sway Atomic, sway+foot+dunst,
quiet/lightweight/daemon-free philosophy, de-KDE-ing the base image).

## Finding

KWrite was already installed as flatpak `org.kde.kwrite` (26.04.3, alongside
KCalc/Kontact/Okular flatpaks) — the "KWrite slot" was already filled the
sane way: no rpm layering, no KF6/Qt6 on the base image, no daemons.

Researched alternatives (2026 status, via @librarian):

| Option | Verdict |
|---|---|
| **GNOME Text Editor** (flatpak org.gnome.TextEditor) | Strongest alternative: lighter sandbox, portal-native dark via `color-scheme: prefer-dark`, healthy upstream, no daemons |
| **micro** (static Go binary → ~/.local/bin) | Best terminal complement to foot: mouse support, truecolor highlighting, Ctrl-S/C/V keys; active (v2.0.15 Dec 2025); coexists with nano |
| featherpad (Qt6, no KF6) | DE-independent and lightweight but no Flathub → needs rpm layer + reboot |
| Kate flatpak | Only if missing KWrite features (sessions, projects, LSP); never layer rpm (dozens of KF6/Qt6 pkgs) |
| gedit | Skip — one-maintainer mode, plugins being removed |
| mousepad / xed | Skip — strictly worse than GNOME Text Editor |
| helix | Skip unless modal editing wanted (lifestyle choice, not a nano upgrade) |
| Zed | Skip for this slot — Vulkan GPU need, telemetry, IDE weight |

## Decision

- **Keep flatpak KWrite** as the GUI text editor. No switch warranted; the
  research above stands as the map if that ever changes.
- Fixed `text/plain` default: was `com.google.AndroidStudio.desktop`
  (double-clicking .txt/.md opened the IDE); now
  `org.kde.kwrite.desktop` via `xdg-mime default` in
  `~/.config/mimeapps.list` (user-level, not repo).
- Terminal editing stays on nano; micro noted as the drop-in upgrade if
  wanted (single static binary, no config weight).

## Caveats

- Flatpak KWrite dark theme under sway depends on Qt theming (portal /
  QT_QPA_PLATFORMTHEME); if it renders light, scope env vars to the app:
  `flatpak override --user org.kde.kwrite --env=KDE_SESSION_VERSION=6`
  (same pattern considered for Kontact after the kde-apps.conf removal).
- Upstream notes flatpak Kate/KWrite: "stable, some features may not fully
  work in Flatpak yet."
