# Agent Instructions (AGENTS.md)

Operational rules for AI agents editing this repository. Read
[README.md](README.md) for the human-facing description of the setup.

## Live edits

`~/.config/{sway,waybar,foot,swaylock,dunst,swayosd}` are **symlinks into `config/`**
in this repo. There is **no sync step**: editing a live config edits the repo
file directly, and changes apply to the running desktop immediately (after a
`swaymsg reload` where needed). Never copy files between the repo and
`~/.config/`.

## Committing

- Commit after any change.
- Stage **only the files you changed** — never `git add -A`, which can sweep
  in unrelated edits.
- Use lowercase conventional prefixes: `sway:`, `waybar:`, `foot:`, `fix:`,
  `docs:`.
- Example:
  ```sh
  git add config/sway/config && git commit -m "sway: <what changed>"
  ```

## Local-only custom palette (skip-worktree)

The user's desktop uses a custom wallpaper palette (waybar, dunst, swayosd)
while the public branch stays Nord. The custom versions are kept local via
git's skip-worktree bit on four files:

- `README.md`
- `config/dunst/dunstrc`
- `config/swayosd/style.css`
- `config/waybar/palette.css`

Consequences and rules:

- `git status` shows these as clean even though the working-tree content
  differs from HEAD. That is intentional; do not "fix" it.
- Never `git update-index --no-skip-worktree` on them except for the merge
  procedure below.
- Current commit prefixes stay valid, but add `docs:` for doc-only edits.
- Backup copies live in `local-overrides-backup/` (untracked, listed in
  `.git/info/exclude`). If a working-tree file is ever lost or clobbered,
  restore with `cp local-overrides-backup/<name> <path>` (README.md maps to
  `README.md`, others to their `config/` locations), then re-apply
  skip-worktree if it was unset.
- Refresh the backups after any intentional edit to one of these four files.

If a future branch/checkout/rebase refuses because one of these files would
be overwritten, or the upstream file changed and must be picked up:

```sh
git update-index --no-skip-worktree <file>
# merge upstream changes into the working-tree version (desktop palette wins)
git update-index --skip-worktree <file>
cp <file> local-overrides-backup/<name>
```

Confirm flags with `git ls-files -v | grep ^S` (expect exactly the four
files above).

## Validating configs

- Sway: `sway --validate -c config/sway/config`
- Waybar: `./validate-waybar.sh` (strips `//` and `/* */` comments, then
  checks the JSON — plain `jq`/`python -m json.tool` can't parse JSONC)

## Change hygiene

- **Verify current state before changing**: check `git log`/`git diff` for
  recent user edits and confirm the requested behavior isn't already in place —
  the user may be working from a stale mental model of the config.
- **Keep README in sync**: update the keybindings, helper-scripts, and features
  tables in the same commit as the script/binding change.
- **Persist research-only findings**: when a research-only topic closes with no
  implementation, write the findings to `docs/<topic>.md` (symptom/question,
  findings, caveats, status) so they survive session boundaries.

## Playbooks

- Adding a keyboard-toggled waybar state module (keep-awake, dnd): see
  [docs/waybar-toggle-module.md](docs/waybar-toggle-module.md).

## Design principles (constrain behavior)

- **No news is good news**: the desktop is quiet by default. Do not add
  notifications, icons, banners, or status indicators for routine or expected
  events. Indicators only appear when a state is worth knowing about, and
  disappear when it isn't.
- **Don't change the source code**: never patch, rebuild, or recompile Sway or
  its components (waybar, foot, swaylock, dunst, ...). Shape behavior only
  through their documented configuration. If a feature isn't reachable via
  config, accept it as-is.

## Environment

- Fedora Sway Atomic (Sericea) — **rpm-ostree based, no dnf/dnf5**. Package
  installs use `rpm-ostree install` (layered) or a toolbox/distrobox container
  for ad-hoc builds.
- Sway 1.11, swaylock 1.8.5, swayidle 1.9.0, waybar, foot, dunst.
- `$mod` = Mod4 (Super); `workspace_layout tabbed`.
- swaylock has no pass-through option; to allow shortcuts while locked, use
  sway's `bindsym --locked` flag.