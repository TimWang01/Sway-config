#!/usr/bin/python3
# reboot-update.py — waybar indicator: reboot to finish a staged rpm-ostree
# deployment that carries Important/Critical security fixes.
#
# Prints nothing (module hidden) unless BOTH hold:
#   - a deployment is staged (rpm-ostree status --json, staged:true), and
#   - its package diff against the booted deployment contains a package
#     (name + version-release) that a security advisory of severity Important
#     or Critical fixes. Advisories come from the updateinfo.xml that rpm-ostree
#     caches in /var/cache/rpm-ostree/repomd (refreshed by upgrade/auto-stage).
# Any Critical match -> class "critical" (style.css); Important only -> plain.
#
# Why not `rpm-ostree db diff -a`: Fedora's commits carry no
# rpmostree.advisories metadata, so that command reports nothing for them.
#
# updateinfo is zchunk (concatenated zstd frames) and ~48 MB uncompressed, so
# the matched list is cached in $XDG_RUNTIME_DIR, keyed on the booted/staged
# checksums and the updateinfo file's mtime+size; it is rebuilt only on change.
# Errors go to stderr (journal) and the module stays hidden.
#
# Test hooks: REBOOT_UPDATE_RPM_OSTREE (binary), REBOOT_UPDATE_REPOMD_DIR.

import glob
import html
import io
import json
import os
import platform
import subprocess
import sys
import xml.etree.ElementTree as ET

ICON = "\uf021"  # Font Awesome 6 arrows-rotate (update)
RPM_OSTREE = os.environ.get("REBOOT_UPDATE_RPM_OSTREE", "rpm-ostree")
REPOMD_DIR = os.environ.get("REBOOT_UPDATE_REPOMD_DIR", "/var/cache/rpm-ostree/repomd")
CACHE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp",
                     f"reboot-update-{os.getuid()}.json")
SEVERITIES = ("Critical", "Important")
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"
MAX_TOOLTIP_ADVISORIES = 10


def run_json(args):
    out = subprocess.run([RPM_OSTREE, *args], capture_output=True, text=True,
                         timeout=120, check=True).stdout
    return json.loads(out)


def staged_and_booted():
    status = run_json(["status", "--json"])
    staged = booted = None
    for dep in status.get("deployments", []):
        if dep.get("staged"):
            staged = dep
        if dep.get("booted"):
            booted = dep
    return staged, booted


def staged_packages(booted, staged):
    """(name, version-release) of every package the staged deployment adds or upgrades."""
    diff = run_json(["db", "diff", "-F", "json", booted["checksum"], staged["checksum"]])
    pkgs = set()
    for _name, _kind, change in diff.get("pkgdiff", []):
        new = change.get("NewPackage")
        if new:
            pkgs.add((new[0], new[1]))
    return pkgs


def release_version():
    with open("/etc/os-release") as f:
        for line in f:
            if line.startswith("VERSION_ID="):
                return line.split("=", 1)[1].strip().strip('"')
    raise RuntimeError("no VERSION_ID in /etc/os-release")


def updateinfo_path():
    # rpm-ostree names cached files by their own checksum, not the repomd href,
    # so take the newest updateinfo file in the repo's cache directory.
    repodata = os.path.join(REPOMD_DIR, f"updates-{release_version()}-{platform.machine()}", "repodata")
    candidates = glob.glob(os.path.join(repodata, "*-updateinfo.xml.zck")) \
        + glob.glob(os.path.join(repodata, "*-updateinfo.xml.zst"))
    if not candidates:
        raise RuntimeError(f"no cached updateinfo in {repodata}")
    return max(candidates, key=os.path.getmtime)


def zchunk_to_xml(path):
    """zchunk files are a header followed by independent zstd frames; concatenate the frames."""
    from compression.zstd import ZstdDecompressor
    with open(path, "rb") as f:
        raw = f.read()
    view = memoryview(raw)
    out = []
    pos = 0
    while (i := raw.find(ZSTD_MAGIC, pos)) >= 0:
        dec = ZstdDecompressor()
        try:
            chunk = dec.decompress(view[i:])
        except Exception:
            chunk = None
        if chunk is None or not dec.eof:
            pos = i + 1  # magic bytes inside the header, not a frame
            continue
        out.append(chunk)
        pos = len(raw) - len(dec.unused_data)
    return b"".join(out)


def matched_advisories(xml_bytes, staged_pkgs):
    """Security advisories (Important/Critical) that fix a package the staged deployment contains."""
    matches = []
    for _, el in ET.iterparse(io.BytesIO(xml_bytes)):
        if el.tag != "update":
            continue
        severity = (el.findtext("severity") or "").strip()
        if el.get("type") == "security" and severity in SEVERITIES:
            fixed = {(p.get("name"), f"{p.get('version')}-{p.get('release')}")
                     for p in el.iter("package")}
            if fixed & staged_pkgs:
                matches.append({"id": el.findtext("id") or "",
                                "severity": severity,
                                "title": el.findtext("title") or ""})
        el.clear()
    return matches


def load_cache():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(obj):
    tmp = CACHE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, CACHE)


def find_matches(staged, booted):
    upd = updateinfo_path()
    st = os.stat(upd)
    key = {"booted": booted["checksum"], "staged": staged["checksum"],
           "updateinfo": [upd, st.st_mtime_ns, st.st_size]}
    cache = load_cache()
    if cache.get("key") == key:
        return cache["matches"]
    matches = matched_advisories(zchunk_to_xml(upd), staged_packages(booted, staged))
    save_cache({"key": key, "matches": matches})
    return matches


def render(staged, matches):
    critical = [m for m in matches if m["severity"] == "Critical"]
    important = [m for m in matches if m["severity"] == "Important"]
    lines = [f"Reboot to apply staged {staged.get('version', '')}",
             f"{len(critical)} critical, {len(important)} important security advisories"]
    ordered = sorted(matches, key=lambda m: (m["severity"] != "Critical", m["title"]))
    for m in ordered[:MAX_TOOLTIP_ADVISORIES]:
        lines.append(f"{m['severity']}: {m['title']}")
    if len(ordered) > MAX_TOOLTIP_ADVISORIES:
        lines.append(f"...and {len(ordered) - MAX_TOOLTIP_ADVISORIES} more")
    out = {"text": ICON, "tooltip": html.escape("\n".join(lines))}
    if critical:
        out["class"] = "critical"
    print(json.dumps(out, ensure_ascii=False))


def main():
    staged, booted = staged_and_booted()
    if not staged or not booted:
        return
    matches = find_matches(staged, booted)
    if matches:
        render(staged, matches)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # stay hidden; keep the reason in the journal
        print(f"reboot-update: {e}", file=sys.stderr)
