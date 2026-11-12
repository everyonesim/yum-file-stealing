from remotezip import RemoteZip
from pathlib import Path
import json
import sys

url = "https://archive.org/download/rain-world_202611/Rain%20World.zip"

manifest_path = Path("rain-world/StreamingAssets/webport-files.json")
output_root = Path("rain-world/StreamingAssets")

with open(manifest_path, encoding="utf-8") as f:
    files = json.load(f)["files"]

print(f"Preparing to extract {len(files)} files...")

with RemoteZip(url) as remote:
    names = set(remote.namelist())

    manifest_name = next(
        n for n in names
        if n.endswith("StreamingAssets/webport-files.json")
    )
    prefix = manifest_name.rsplit("/", 1)[0] + "/"

    missing = [
        item["path"] for item in files
        if prefix + item["path"] not in names
    ]

    if missing:
        print("ERROR: Some files were not found:")
        print("\n".join(missing[:30]))
        sys.exit(1)

    print("All files found. Starting extraction...")

    completed = 0
    skipped = 0

    for item in files:
        relative = item["path"]
        destination = output_root / relative
        expected_size = item["size"]

        if destination.exists() and destination.stat().st_size == expected_size:
            skipped += 1
            continue

        destination.parent.mkdir(parents=True, exist_ok=True)

        data = remote.read(prefix + relative)
        destination.write_bytes(data)

        completed += 1

        if completed % 25 == 0:
            print(
                f"Downloaded {completed} files "
                f"({completed + skipped}/{len(files)} checked)"
            )

print("\nEXTRACTION COMPLETE!")
print("Newly downloaded:", completed)
print("Already present:", skipped)
print("Total assets:", len(files))
