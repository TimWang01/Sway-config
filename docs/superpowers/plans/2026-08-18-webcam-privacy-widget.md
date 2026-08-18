# Webcam Privacy Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a quiet-by-default Waybar camera indicator that appears only while a user application has an active `/dev/video*` device open.

**Architecture:** A focused shell helper discovers video devices, uses `fuser` and `ps` to identify relevant holders, and emits one Waybar JSON payload only when camera use is active. A `custom/webcam` module polls that helper every two seconds; CSS copies the existing `#privacy` widget's exact visual treatment.

**Tech Stack:** Bash, `fuser` from `psmisc`, `ps`, Waybar 0.15.0 JSONC configuration, GTK CSS `@define-color` palette.

## Global Constraints

- Quiet by default: no output and no visible module when the webcam is idle or absent.
- Detection must use `/dev/video*` holders so V4L2-direct applications are covered.
- No Waybar source changes, custom builds, persistent idle icon, or click action.
- Active styling must match `#privacy`: `padding: 0 5px`, `background-color: @privacy-bg`, `color: @privacy-fg`.
- Poll interval is exactly 2 seconds.
- The existing native `privacy` module remains unchanged.

---

## File Map

- Create: `config/waybar/webcam.sh` — executable detector and Waybar JSON producer.
- Modify: `config/waybar/config.jsonc` — register and configure `custom/webcam`.
- Modify: `config/waybar/style.css` — include the custom module in shared groups and copy privacy styling.

## Task 1: Add the webcam activity detector

**Files:**
- Create: `config/waybar/webcam.sh`

**Interfaces:**
- Consumes: `/dev/video*`, `fuser`, and `ps` process metadata.
- Produces: empty stdout when inactive; one Waybar JSON object when active.

- [ ] **Step 1: Create the executable detector**

Create `config/waybar/webcam.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

devices=(/dev/video*)
if [[ ! -e ${devices[0]} ]]; then
    exit 0
fi

while read -r pid; do
    [[ $pid =~ ^[0-9]+$ ]] || continue
    command_name=$(ps -p "$pid" -o comm= 2>/dev/null || true)
    case "$command_name" in
        pipewire|wireplumber|fuser)
            continue
            ;;
    esac
    printf '{"text":"\\uf030","class":"active","tooltip":"Webcam in use"}\n'
    exit 0
done < <(
    fuser -v "${devices[@]}" 2>/dev/null \
        | awk '$3 ~ /^[0-9]+$/ {print $3}' \
        | sort -u
)
```

- [ ] **Step 2: Verify syntax and the inactive path**

Run `chmod +x config/waybar/webcam.sh`, `bash -n config/waybar/webcam.sh`, then `output=$(config/waybar/webcam.sh)` and `test -z "$output"`. Expected: syntax succeeds and output is empty because this machine currently has no `/dev/video*` device.

- [ ] **Step 3: Commit the detector**

Run `git add config/waybar/webcam.sh && git commit -m "waybar: add webcam activity detector"`.

## Task 2: Register the custom Waybar module

**Files:**
- Modify: `config/waybar/config.jsonc` in `modules-right` and near the native `privacy` definition.

**Interfaces:**
- Consumes: executable `$HOME/.config/waybar/webcam.sh` from Task 1.
- Produces: hidden-by-empty-output `custom/webcam` polled every two seconds.

- [ ] **Step 1: Add `custom/webcam` to `modules-right`**

Add `"custom/webcam"` beside the existing native `"privacy"` module. Keep the native privacy entry and all existing privacy module definitions unchanged.

- [ ] **Step 2: Add the module definition**

Add this JSONC definition:

```jsonc
"custom/webcam": {
    "exec": "$HOME/.config/waybar/webcam.sh",
    "interval": 2,
    "return-type": "json",
    "tooltip": true
},
```

The module has no click action and no persistent idle output.

- [ ] **Step 3: Restart Waybar and verify loading**

Run `pkill -x waybar || true; sleep 1; waybar >/tmp/waybar-webcam.log 2>&1 & disown; sleep 2; test "$(pgrep -c -x waybar)" -eq 1`. Then run `grep -n 'custom/webcam\\|webcam.sh' config/waybar/config.jsonc`. Expected: one Waybar process, both references present, and no JSON/config parse error in `/tmp/waybar-webcam.log`.

- [ ] **Step 4: Commit the module registration**

Run `git add config/waybar/config.jsonc && git commit -m "waybar: register webcam privacy module"`.

## Task 3: Match the existing privacy widget styling

**Files:**
- Modify: `config/waybar/style.css` shared color and spacing selectors plus the dedicated privacy-widget rules.

**Interfaces:**
- Consumes: the `#custom-webcam` module ID from Task 2 and existing `@privacy-bg`/`@privacy-fg` palette colors.
- Produces: an active webcam indicator visually identical to the existing `#privacy` widget.

- [ ] **Step 1: Add `#custom-webcam` to shared selectors**

Include `#custom-webcam` in the existing shared color selector and shared zero-padding selector where the other custom status modules are listed. Do not remove or reorder unrelated selectors.

- [ ] **Step 2: Add the exact privacy styling**

Add this rule near the existing `#privacy` rule:

```css
#custom-webcam {
    padding: 0 5px;
    background-color: @privacy-bg;
    color: @privacy-fg;
}
```

Do not add a separate red, critical, or inactive state. The module is hidden when inactive; when active it uses the same green Nord privacy treatment.

- [ ] **Step 3: Restart Waybar and validate diagnostics**

Run `pkill -x waybar || true; sleep 1; waybar >/tmp/waybar-webcam-style.log 2>&1 & disown; sleep 2; test "$(pgrep -c -x waybar)" -eq 1`. Then run `grep -n '#custom-webcam\\|custom-webcam' config/waybar/style.css`. Expected: one Waybar process and no CSS parse error in `/tmp/waybar-webcam-style.log`.

- [ ] **Step 4: Commit the styling**

Run `git add config/waybar/style.css && git commit -m "waybar: match webcam indicator to privacy widget"`.

## Task 4: Final verification

**Files:**
- Verify: `config/waybar/webcam.sh`, `config/waybar/config.jsonc`, and `config/waybar/style.css`.

- [ ] **Step 1: Verify repository and live process state**

Run:

```bash
git status --short
test "$(pgrep -c -x waybar)" -eq 1
grep -n 'custom/webcam\|webcam.sh' config/waybar/config.jsonc
grep -n '#custom-webcam\|custom-webcam' config/waybar/style.css
bash -n config/waybar/webcam.sh
```

Expected: no uncommitted changes, one Waybar process, both configuration references present, and valid shell syntax.

- [ ] **Step 2: Verify active and inactive runtime behavior when hardware is available**

If a `/dev/video*` device becomes available, start a known camera-using application and run `config/waybar/webcam.sh`. Expected active output is exactly:

```json
{"text":"\\uf030","class":"active","tooltip":"Webcam in use"}
```

After the camera application releases the device, run the script again and expect empty stdout. If no camera is available, record the inactive-path verification from Task 1 as the available runtime evidence; do not claim active-path verification.
