#!/usr/bin/env python3
"""Build latest.json from release-notes/*.md.

Run on the VPS after uploading the release notes directory. Each MD file is
the source of truth for one release; this script renders them into the
server's manifest, computes the per-ABI SHA-256 from the APK files in the
same directory, and writes latest.json.

Schema in each MD file (frontmatter):

  ---
  version: 1.0.12
  build: 27
  date: 2026-10-07
  type: minor
  mandatory: false
  headlineId: Per-release title in Indonesian
  headlineEn: Per-release title in English
  notesId: ...
  notesEn: ...
  sections:
    - kind: new
      items: [...]
    - kind: fix
      items: [...]
  ---

  Body of release notes (free form).
"""
import glob
import hashlib
import json
import os
import re
import sys

RELEASES_DIR = "/root/smartcook-releases"
NOTES_DIR = "/root/smartcook-frontend/release-notes"


def md_front(s):
    """Frontmatter is YAML-flavoured but `sections:` carries a JSON array. We
    treat it as a single-line value per file because the alternative - parsing
    YAML in pure Python - is more code than this whole script."""
    m = re.search(r"^---\n(.+?)\n---", s, re.S)
    if not m:
        return {}
    out = {}
    for line in m.group(1).split("\n"):
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        out[k.strip()] = v.strip()
    return out


def md_body(s):
    m = re.search(r"^---\n.+?\n---\n(.+)$", s, re.S)
    return m.group(1).strip() if m else ""


def sections_of(info):
    try:
        return json.loads(info.get("sections", "[]"))
    except Exception:
        return []


def load_notes():
    out = []
    for path in sorted(glob.glob(os.path.join(NOTES_DIR, "*.md"))):
        with open(path) as f:
            info = md_front(f.read())
        if "version" not in info or "build" not in info:
            continue
        try:
            build = int(info["build"])
        except ValueError:
            continue
        # `build` is the manifest's own monotonic version counter (what
        # history[i].build is sorted by). `androidVersionCode` is what an
        # Android device actually reports through PackageInfo / the
        # build.gradle versionCode field; they are the same for builds made
        # by `scripts/build_android_release.ps1`, but the very first release
        # (1.0.0) used 17 as its Android versionCode while the manifest build
        # was 17 too, so the older history entries need both numbers made
        # explicit. Without `androidVersionCode`, a v1.0.12 device
        # (Android versionCode=13) would treat every history entry as newer
        # and report "jumping 9 versions at once" because the Android
        # numbering and the manifest build are out of sync.
        # The release notes file's frontmatter should carry it explicitly:
        # "androidVersionCode: 13". When it's missing - old release notes or
        # an in-progress PR - fall back to the manifest `build`, which is the
        # right answer for every release that follows the rule.
        raw_android = info.get("androidVersionCode")
        if raw_android is None or raw_android == "":
            android_version_code = build
        else:
            try:
                android_version_code = int(raw_android)
            except ValueError:
                android_version_code = build
        body = md_body(open(path).read())
        # Read all four localised fields straight from the frontmatter so the
        # client gets a properly translated copy for each. The bare `notes`
        # field (when present) is used as a last-ditch fallback if the per-
        # language copies are empty for both English and Indonesian.
        headline_id = info.get("headlineId", "")
        headline_en = info.get("headlineEn", "")
        notes_id = info.get("notesId", "")
        notes_en = info.get("notesEn", "")
        notes_fallback = info.get("notes", "")
        if not notes_id and not notes_en:
            notes_fallback = body
        out.append({
            "version": info["version"],
            "build": build,
            "androidVersionCode": android_version_code,
            "date": info.get("date", ""),
            "type": info.get("type", "patch"),
            "mandatory": info.get("mandatory", "false").lower() == "true",
            "headlineId": headline_id,
            "headlineEn": headline_en,
            "notesId": notes_id,
            "notesEn": notes_en,
            "notes": notes_id or notes_en or notes_fallback,
            "sections": sections_of(info),
        })
    return sorted(out, key=lambda h: -h["build"])


def hash_size(filename):
    path = os.path.join(RELEASES_DIR, filename)
    data = open(path, "rb").read()
    return hashlib.sha256(data).hexdigest(), os.path.getsize(path)


def main():
    history = load_notes()
    if not history:
        sys.exit("no release notes found in " + NOTES_DIR)
    latest = history[0]
    apks = []
    for abi in ("arm64", "arm32"):
        filename = f"smartcook-{latest['version']}-{abi}.apk"
        path = os.path.join(RELEASES_DIR, filename)
        if not os.path.exists(path):
            sys.exit(f"missing APK: {filename}")
        sha, size = hash_size(filename)
        apks.append({
            "abi": abi,
            "file": filename,
            "sha256": sha,
            "sizeBytes": size,
        })

    body_id = latest.get("notesId") or ""
    body_en = latest.get("notesEn") or ""
    fallback = body_id or body_en

    manifest = {
        "version": latest["version"],
        "build": latest["build"],
        "minBuild": latest["build"],
        "blockedBuilds": [],
        "releaseType": latest["type"],
        "date": latest["date"],
        # Schema requires a `notes` field at the top level. Use the English
        # copy as fallback; the localised picker on the server re-writes
        # this for each client based on X-Smartcook-Locale.
        "notes": fallback,
        "headlineId": latest.get("headlineId", ""),
        "headlineEn": latest.get("headlineEn", ""),
        "notesId": body_id,
        "notesEn": body_en,
        "sections": latest.get("sections", []),
        "apks": apks,
        "history": history,
    }
    out = os.path.join(RELEASES_DIR, "latest.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"wrote {out}")
    print(f"version={manifest['version']} build={manifest['build']} history={len(history)}")
    for apks_entry in apks:
        print(f"  {apks_entry['abi']} {apks_entry['file']} {apks_entry['sizeBytes']} bytes")


if __name__ == "__main__":
    main()