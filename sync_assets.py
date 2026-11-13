#!/usr/bin/env python3
"""Keep Rain World's StreamedAssets in sync with the web port's file manifest.

The WebGL build does not ship its data inside the .data bundle. It mounts
StreamingAssets/ as a virtual filesystem described by
StreamingAssets/webport-files.json and then fetches each file on demand with a
blocking request. A file that is missing, truncated, or a different length than
the manifest says makes the load stall (the game just sits on the loading art),
so this script makes every listed file present and exactly the right size.

Usage:
    python3 sync_assets.py              # repair whatever is missing or wrong
    python3 sync_assets.py --verify     # only report problems, download nothing
    python3 sync_assets.py --out StreamingAssets
    python3 sync_assets.py --limit 5    # small trial run

Files listed with an "encodedPath" are served as base64 text from
StreamingAssets/<encodedPath>; those are generated here when the source archive
does not already contain them.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import threading
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path, PurePosixPath

SOURCE_ZIP = "https://archive.org/download/rain-world_202611/Rain%20World.zip"
MANIFEST_NAME = "StreamingAssets/webport-files.json"
WORKERS = 12

_thread_state = threading.local()


def remote_zip():
    """One RemoteZip handle per worker thread."""
    from remotezip import RemoteZip

    handle = getattr(_thread_state, "zip", None)
    if handle is None:
        handle = RemoteZip(SOURCE_ZIP)
        _thread_state.zip = handle
    return handle


def pick_output_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    root = Path("StreamingAssets")
    legacy = Path("rain-world/StreamingAssets")
    if not root.exists() and legacy.exists():
        print(f"Using existing asset tree at {legacy}")
        return legacy
    return root


def load_manifest(output_root: Path) -> dict:
    from remotezip import RemoteZip

    print("Reading file manifest from the source archive...", flush=True)
    with RemoteZip(SOURCE_ZIP) as archive:
        raw = archive.read(MANIFEST_NAME)

    manifest = json.loads(raw)
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "webport-files.json").write_bytes(raw)
    print(f"Manifest: {len(manifest['files'])} files")
    return manifest


def build_index(names: set[str]) -> dict[str, list[str]]:
    by_name = defaultdict(list)
    for name in names:
        by_name[PurePosixPath(name).name].append(name)
    return by_name


def resolve_source(entry: dict, names: set[str], by_name: dict[str, list[str]]) -> tuple[str | None, str]:
    """Find the archive member that holds this manifest entry."""
    wanted = "StreamingAssets/" + entry["path"]
    if wanted in names:
        return wanted, ""

    encoded = entry.get("encodedPath")
    if encoded:
        candidate = "StreamingAssets/" + encoded
        if candidate in names:
            return candidate, "encoded"

    matches = by_name.get(PurePosixPath(entry["path"]).name, [])
    if len(matches) == 1:
        return matches[0], "renamed"
    if len(matches) > 1:
        return None, "ambiguous"
    return None, "absent"


def local_path_for(entry: dict, output_root: Path, encoded: bool) -> Path:
    relative = entry.get("encodedPath") if encoded else entry["path"]
    return output_root / PurePosixPath(relative)


def is_complete(entry: dict, output_root: Path, encoded: bool) -> bool:
    target = local_path_for(entry, output_root, encoded)
    if not target.is_file():
        return False
    if encoded:
        return target.stat().st_size >= (entry["size"] * 4) // 3
    return target.stat().st_size == entry["size"]


def write_payload(entry: dict, output_root: Path, encoded: bool, data: bytes) -> str:
    target = local_path_for(entry, output_root, encoded)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    return str(target)


def fetch_one(entry: dict, output_root: Path, names: set[str], by_name, verify_only: bool):
    source, how = resolve_source(entry, names, by_name)
    if source is None:
        return ("absent", entry, how)
    if how == "ambiguous":
        return ("ambiguous", entry, how)

    encoded = bool(entry.get("encodedPath"))
    if is_complete(entry, output_root, encoded):
        return ("ok", entry, how)
    if verify_only:
        return ("broken", entry, how)

    raw = remote_zip().read(source)

    if encoded and how != "encoded":
        payload = base64.b64encode(raw)
        expected = entry["size"]
        if len(base64.b64decode(payload)) != expected:
            return ("size", entry, how)
    elif how == "encoded":
        payload = raw
        try:
            if len(base64.b64decode(raw, validate=False)) != entry["size"]:
                return ("size", entry, how)
        except Exception:
            return ("size", entry, how)
    else:
        payload = raw
        if len(raw) != entry["size"]:
            return ("size", entry, how)

    write_payload(entry, output_root, encoded, payload)
    return ("fixed", entry, how)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", help="asset folder to write (default: StreamingAssets)")
    parser.add_argument("--verify", action="store_true", help="report problems without downloading")
    parser.add_argument("--limit", type=int, help="only process the first N files (trial run)")
    parser.add_argument("--filter", help="only process paths starting with this prefix")
    parser.add_argument("--workers", type=int, default=WORKERS, help="parallel downloads (default 12)")
    args = parser.parse_args()

    output_root = pick_output_root(args.out)
    manifest = load_manifest(output_root)
    entries = manifest["files"]

    if args.filter:
        entries = [e for e in entries if e["path"].startswith(args.filter)]

    # Entries with no bytes are used by the build as empty placeholders (audio is
    # streamed by the Web Audio layer instead), so they are never requested.
    stubs = [e for e in entries if e["size"] == 0]
    entries = [e for e in entries if e["size"] > 0]
    if args.limit:
        entries = entries[: args.limit]

    print(f"Checking {len(entries)} files ({len(stubs)} empty placeholders skipped)")
    if args.verify:
        print("Verify only: nothing will be downloaded")
    print(f"Target: {output_root.resolve()}")

    from remotezip import RemoteZip

    with RemoteZip(SOURCE_ZIP) as archive:
        names = set(archive.namelist())
    by_name = build_index(names)

    counts = defaultdict(int)
    problems = []
    fixed = 0
    total = len(entries)
    done = 0

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(fetch_one, entry, output_root, names, by_name, args.verify) for entry in entries]
        for future in as_completed(futures):
            status, entry, how = future.result()
            counts[status] += 1
            if status in ("absent", "ambiguous", "size", "broken"):
                problems.append((status, entry["path"], how))
            if status == "fixed":
                fixed += 1
            done += 1
            if done % 200 == 0 or done == total:
                print(f"{done}/{total}  ok={counts['ok']} fixed={counts['fixed']} problems={len(problems)}", flush=True)

    if problems:
        report = output_root.parent / "missing-assets.txt"
        with report.open("w", encoding="utf-8") as handle:
            for status, path, how in problems:
                handle.write(f"{status}\t{path}\t{how}\n")
        print(f"\n{len(problems)} file(s) could not be provided, listed in {report}")
        for status, path, how in problems[:15]:
            print(f"  {status:9s} {path} ({how})")
    else:
        stale = output_root.parent / "missing-assets.txt"
        if stale.exists():
            stale.unlink()

    print("\nSummary")
    print(f"  already correct : {counts['ok']}")
    print(f"  repaired        : {fixed}")
    print(f"  empty stubs     : {len(stubs)}")
    print(f"  unresolved      : {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
