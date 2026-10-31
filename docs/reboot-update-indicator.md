# rpm-ostree reboot-for-security indicator

**Question:** show a waybar icon telling me to reboot when rpm-ostree has
staged a deployment carrying Important/Critical security fixes; use the
critical color when any Critical advisory is included; use an update icon.

## Findings

- `rpm-ostree db diff -a` / `rpm-ostree status --advisories` print nothing for
  the staged deployment: Fedora's commits carry no `rpmostree.advisories`
  metadata (`ostree show --print-metadata-key=rpmostree.advisories` →
  "No such metadata key" on booted, rollback, and pending commits). Do not rely
  on them.
- rpm-ostree keeps the Fedora updates `updateinfo.xml` locally in
  `/var/cache/rpm-ostree/repomd/updates-<rel>-<arch>/repodata/*-updateinfo.xml.zck`.
  It is zchunk: a header followed by independent zstd frames. Concatenating the
  frames yields the ~48 MB XML. Decoded here with `compression.zstd`
  (Python 3.14+, `/usr/bin/python3`); no `zck` CLI is needed. Cached files are
  named by their own checksum, not by the repomd `href` (which lists `.zst`).
- Each `<update>` has `type` (security/bugfix/...), `<severity>`
  (Critical/Important/Moderate/Low/None) and a `<pkglist>` of name, version,
  release. Security advisories are matched to the staged diff by exact
  (name, version-release).
- `rpm-ostree db diff -F json <booted> <staged>` gives `pkgdiff` entries; a
  `NewPackage` key marks an added or upgraded package. This is the staged set.
- Icon: Font Awesome 6 Solid is installed; U+F021 (arrows-rotate) renders via
  fontconfig fallback, as the memory icon U+F0C9 does. Nerd Font MDI U+F06B0 is
  not installed.

## Implementation

- `config/waybar/reboot-update.py` (`/usr/bin/python3`). Logic:
  1. `rpm-ostree status --json`: no staged deployment → print nothing.
  2. `rpm-ostree db diff -F json booted staged` → staged (name, version-release).
  3. Newest `updates-<VERSION_ID>-<arch>` updateinfo in the repomd cache.
  4. Matches are `type=security` with severity Important or Critical whose
     packages intersect the staged set. No match → print nothing.
  5. Output `{"text": U+F021, "tooltip": ..., "class": "critical"}`. The class is
     set only with ≥1 Critical match.
- Cache: `$XDG_RUNTIME_DIR/reboot-update-<uid>.json`, keyed on booted/staged
  checksums plus updateinfo path, mtime, and size. The 48 MB parse runs only
  when one of them changes (~0.8 s first run, ~0.06 s cached).
- Waybar: `custom/reboot-update` in `modules-right` after `tray`; interval 600 s;
  `return-type: json`; tooltip on. CSS: `#custom-reboot-update` glyph surface
  and color `@fg`; `#custom-reboot-update.critical` → `@critical`.
- Test hooks: `REBOOT_UPDATE_RPM_OSTREE` (binary) and `REBOOT_UPDATE_REPOMD_DIR`
  (cache root).

## Caveats

- Freshness depends on the cached updateinfo. `rpm-ostreed-automatic.timer`
  (stage policy) refreshes it on each run, about daily.
- Only the **staged** deployment counts, not a downloaded-but-unstaged
  `cached-update`. Advisories that fix a package already in the booted
  deployment are not counted, because they are not new in the staged image.
- Epoch is ignored in matching. Moderate/Low/None security advisories and
  bugfix/enhancement updates are not shown ("no news is good news").
- Error paths (rpm-ostree failure, missing cache) print nothing and log one
  line to the journal (stderr).

## Status

Implemented. At the time of writing the live staged deployment
(44.20261031.0) only upgrades pipewire 1.6.10 → 1.6.11, which is a bugfix with
no advisory, so the module stays hidden. Positive paths (Important-only,
Critical → critical class, no staged, rpm-ostree failure, cache hit) were
verified with a fake `rpm-ostree` against the real updateinfo cache.
