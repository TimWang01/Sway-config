# GitHub Polish — Design

Date: 2026-08-30
Status: Approved

## Goal

Polish this Sway desktop configuration repo for publication on GitHub as a
public showcase, while keeping it usable as a personal backup/sync source.
No changes to live config behavior.

## Scope

1. **README rewrite** — public-facing, generalized (no `/home/b.n/...` paths,
   no "BN-PC" hostname), with badges, features, keybindings reference, and
   generalized install instructions.
2. **MIT LICENSE** — copyright `2026 B.N.` (matches git author identity).
3. **Move `docs/superpowers/` out of the repo** — keep locally outside the
   repo, add to `.gitignore` so it never returns.
4. **CI validation workflow** — GitHub Actions validating sway config, waybar
   JSONC, and shell script syntax on push/PR.
5. **AGENTS.md** — unchanged (already GitHub-friendly).

## README structure

1. Title + badges row (MIT license badge; no misleading build badges)
2. Intro — "Sway desktop configuration for Fedora Sway Atomic (Sericea)",
   machine spec moved to a "Tested on" note
3. Features — tabbed workspaces, Nord theme, idle/lock cascade,
   quiet-by-default notifications, swayosd OSD, zram tuning, etc.
4. Layout — existing tree, kept as-is
5. Keybindings reference — table extracted from the sway config, grouped
   (window management, workspaces, media/volume, apps, system), `$mod` = Super
6. Install / apply on fresh install — generalized symlink instructions
   (relative/`$HOME` paths)
7. Design principles — keep "no news is good news" and "don't change the
   source code" sections
8. Helper scripts table — keep as-is
9. AGENTS.md pointer — keep

## License + hygiene

- `LICENSE` — MIT, `2026 B.N.`
- Move `docs/superpowers/` to sibling directory
  `/run/media/data0/Documents/Documents/Backup/System/Sway-planning/` (outside
  the repo), then `git rm -r docs/superpowers` and add `docs/superpowers/` to
  `.gitignore`
- `.gitignore` gains `docs/superpowers/` alongside `.worktrees/` and
  `.superpowers/`
- Git author already `B.N <b.n@example.com>` — no change

## CI workflow

`.github/workflows/validate.yml`, triggers: push + pull_request.

- Job on `ubuntu-latest`
- **Sway config**: run inside a Fedora container
  (`quay.io/fedora/fedora:latest`, `dnf install sway`) so validation uses the
  same sway version as the real environment (1.11), then
  `sway --validate -c config/sway/config`
- **Waybar JSONC**: run existing `./validate-waybar.sh`
- **Shell scripts**: `bash -n` on `config/sway/scripts/*.sh` and root scripts

## Out of scope

- Repo layout restructure / unified install script
- Making the sway config hardware-portable (auto-detect output)
- Screenshots
- Git history rewrite