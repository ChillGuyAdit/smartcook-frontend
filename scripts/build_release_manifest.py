#!/usr/bin/env python3
"""Build latest.json from release-notes/*.md.

Each note file is the source of truth for one release. The manifest `build` IS
the Android versionCode IS the `+N` in pubspec.yaml - one number, no second
numbering scheme. The generator refuses to run if the newest note disagrees
with pubspec.yaml, so the update check cannot drift again.

Frontmatter of release-notes/<NNNN>-<version>.md:

  ---
  version: 1.0.14
  build: 15
  date: 2026-10-08
  type: patch              # patch | minor | big | major | rollback
  mandatory: false         # true => minBuild is raised to this build
  blocks: []               # builds that must update (rollback of a bad build)
  headlineId: ...
  headlineEn: ...
  notesId: ...
  notesEn: ...
  sections: [{"kind":"new","items":["..."]},{"kind":"fix","items":["..."]}]
  ---
  Free-form body (fallback when notesId/notesEn are empty).

Usage:
  build_release_manifest.py --apk-dir DIR --out FILE
         [--notes-dir release-notes] [--pubspec pubspec.yaml]
"""
import argparse
import hashlib
import json
import os
import re
import sys

ABIS = ("arm64", "arm32")
TYPES = ("patch", "minor", "big", "major", "rollback")


def front(s):
    m = re.search(r"\A---\r?\n(.+?)\r?\n---", s, re.S)
    out = {}
    if not m:
        return out
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def body(s):
    m = re.search(r"\A---\r?\n.+?\r?\n---\r?\n(.*)\Z", s, re.S)
    return m.group(1).strip() if m else ""


def int_list(raw):
    m = re.search(r"\[(.*)\]", raw or "")
    return [int(x) for x in m.group(1).split(",") if x.strip()] if m else []


def load_notes(notes_dir):
    out = []
    for name in sorted(os.listdir(notes_dir)):
        if not name.endswith(".md"):
            continue
        text = open(os.path.join(notes_dir, name), encoding="utf-8").read()
        info = front(text)
        if "version" not in info or "build" not in info:
            sys.exit(f"{name}: frontmatter needs version and build")
        build = int(info["build"])
        if not name.startswith(f"{build:04d}-"):
            sys.exit(f"{name}: file name must start with {build:04d}- (build {build})")
        rtype = info.get("type", "patch")
        if rtype not in TYPES:
            sys.exit(f"{name}: type must be one of {TYPES}")
        try:
            sections = json.loads(info.get("sections", "[]"))
        except ValueError:
            sys.exit(f"{name}: sections is not valid JSON")
        nid, nen = info.get("notesId", ""), info.get("notesEn", "")
        out.append({
            "version": info["version"],
            "build": build,
            # Same number as build; kept because shipped clients read it.
            "androidVersionCode": build,
            "date": info.get("date", ""),
            "type": rtype,
            "mandatory": info.get("mandatory", "false").lower() == "true",
            "blocks": int_list(info.get("blocks")),
            "headlineId": info.get("headlineId", ""),
            "headlineEn": info.get("headlineEn", ""),
            "notesId": nid,
            "notesEn": nen,
            "notes": nid or nen or body(text),
            "sections": sections,
        })
    builds = [n["build"] for n in out]
    if len(builds) != len(set(builds)):
        sys.exit("duplicate build number in release notes")
    return sorted(out, key=lambda n: -n["build"])


def pubspec_build(path):
    m = re.search(r"^version:\s*[\d.]+\+(\d+)", open(path, encoding="utf-8").read(), re.M)
    if not m:
        sys.exit("pubspec.yaml has no version: X.Y.Z+N")
    return int(m.group(1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--notes-dir", default="release-notes")
    ap.add_argument("--apk-dir", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--pubspec", default="pubspec.yaml")
    a = ap.parse_args()

    history = load_notes(a.notes_dir)
    if not history:
        sys.exit("no release notes found")
    latest = history[0]

    expected = pubspec_build(a.pubspec)
    if latest["build"] != expected:
        sys.exit(f"newest note is build {latest['build']} but pubspec is +{expected}; "
                 "they must be the same number")

    apks = []
    for abi in ABIS:
        fn = f"smartcook-{latest['version']}-{abi}.apk"
        p = os.path.join(a.apk_dir, fn)
        if not os.path.exists(p):
            sys.exit(f"missing APK: {p}")
        apks.append({"abi": abi, "file": fn,
                     "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest(),
                     "sizeBytes": os.path.getsize(p)})

    mandatory = [n["build"] for n in history if n["mandatory"]]
    min_build = max(mandatory) if mandatory else 1
    blocked = sorted({b for n in history for b in n["blocks"]})

    manifest = {
        "version": latest["version"],
        "build": latest["build"],
        "minBuild": min_build,
        "blockedBuilds": blocked,
        "releaseType": latest["type"],
        "date": latest["date"],
        "notes": latest["notesId"] or latest["notesEn"] or latest["notes"],
        "headlineId": latest["headlineId"],
        "headlineEn": latest["headlineEn"],
        "notesId": latest["notesId"],
        "notesEn": latest["notesEn"],
        "sections": latest["sections"],
        "apks": apks,
        "history": [{k: v for k, v in n.items() if k not in ("mandatory", "blocks")}
                    for n in history],
    }
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"wrote {a.out}: {manifest['version']}+{manifest['build']} "
          f"minBuild={min_build} blocked={blocked} history={len(history)}")


if __name__ == "__main__":
    main()
