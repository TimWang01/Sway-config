# Webcam Privacy Widget Design

**Status:** Approved
**Date:** 2026-08-18

## Goal

Add a quiet-by-default Waybar indicator that appears only while an application is actively using a webcam. It must work with V4L2-direct applications, which are common on Fedora Sway because `xdg-desktop-portal-wlr` does not provide the Camera portal.

## Scope

### In scope

- Add a `webcam.sh` helper under the versioned Waybar configuration.
- Detect active webcam use by checking which processes have `/dev/video*` open with `fuser`.
- Add a hidden-by-default `custom/webcam` Waybar module.
- Show a Font Awesome camera icon and the tooltip `Webcam in use` only while active.
- Poll every two seconds.
- Match the existing privacy widget styling exactly: same padding, background, foreground, and Nord palette values.

### Out of scope

- No persistent idle webcam icon.
- No click action or camera-control UI.
- No changes to Waybar source code or custom builds.
- No replacement of the existing native `privacy` module.

## Design

### Detection

`webcam.sh` expands `/dev/video*` and calls `fuser` to obtain processes holding camera device nodes. It emits Waybar JSON only when at least one relevant process is using a device. Kernel and infrastructure holders such as WirePlumber are filtered so the widget represents application use rather than device management.

When no camera device exists, or no relevant process has one open, the script emits no output. Waybar therefore hides the custom module under the project's quiet-by-default convention.

### Waybar integration

Add `custom/webcam` to `modules-right` near the existing `privacy` module. Configure it with:

- `exec`: `$HOME/.config/waybar/webcam.sh`
- `interval`: `2`
- `return-type`: `json`
- `tooltip`: provided by the script while active

The active JSON payload contains the camera icon, an `active` class, and `Webcam in use` tooltip text.

### Styling

Add `#custom-webcam` to the existing Waybar module color and spacing groups as needed, then give it the same declarations as `#privacy`:

```css
padding: 0 5px;
background-color: @privacy-bg;
color: @privacy-fg;
```

No new colors or visual states are introduced.

## Error handling

- Missing `/dev/video*`: emit empty output without logging noise.
- `fuser` failure or inaccessible device: treat as inactive and emit empty output.
- Multiple camera devices or processes: show one indicator.
- Malformed or unavailable process metadata: ignore that process rather than failing the module.

## Verification

1. Run shell syntax validation on `webcam.sh`.
2. Test the inactive path with no `/dev/video*` device and confirm empty output.
3. If a webcam is available, open it with a camera application and confirm the active JSON output, icon, class, and tooltip.
4. Start/reload Waybar and confirm the configuration parses without errors.
5. Confirm the active module uses the same visual styling as `#privacy`.
