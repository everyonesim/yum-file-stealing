from remotezip import RemoteZip
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import PurePosixPath
from collections import defaultdict
import json, os, threading

URL = "https://archive.org/download/rain-world_202611/Rain%20World.zip"
WORKERS = 12

with open("rain-world/StreamingAssets/webport-files.json") as f:
    files = json.load(f)["files"]

print("Connecting to ZIP and matching files...", flush=True)

with RemoteZip(URL) as z:
    names = z.namelist()

by_basename = defaultdict(list)
name_set = set(names)

for name in names:
    by_basename[PurePosixPath(name).name].append(name)

jobs = []
missing = []

for item in files:
    path = item["path"]
    expected = "StreamingAssets/" + path

    if expected in name_set:
        source = expected
    else:
        matches = by_basename.get(PurePosixPath(path).name, [])
        if len(matches) == 1:
            source = matches[0]
        else:
            missing.append(path)
            continue

    destination = os.path.join("rain-world/StreamingAssets", path)
    jobs.append((source, destination))

print(f"Ready: {len(jobs)} files. Missing: {len(missing)}", flush=True)

local = threading.local()
counter = 0
lock = threading.Lock()

def get_zip():
    if not hasattr(local, "zip"):
        local.zip = RemoteZip(URL)
    return local.zip

def extract(job):
    source, destination = job
    os.makedirs(os.path.dirname(destination), exist_ok=True)

    if os.path.isfile(destination):
        return "skipped"

    data = get_zip().read(source)

    with open(destination, "wb") as f:
        f.write(data)

    return "downloaded"

downloaded = 0
skipped = 0
failed = []

with ThreadPoolExecutor(max_workers=WORKERS) as pool:
    futures = {pool.submit(extract, job): job for job in jobs}

    for future in as_completed(futures):
        try:
            result = future.result()
            if result == "downloaded":
                downloaded += 1
            else:
                skipped += 1
        except Exception as e:
            failed.append((futures[future][0], str(e)))

        completed = downloaded + skipped + len(failed)
        if completed % 100 == 0 or completed == len(jobs):
            print(f"{completed}/{len(jobs)} processed | {downloaded} downloaded | {len(failed)} failed", flush=True)

print("\nEXTRACTION FINISHED")
print("Downloaded:", downloaded)
print("Already present:", skipped)
print("Missing from ZIP:", len(missing))
print("Download failures:", len(failed))

with open("missing-assets.txt", "w") as f:
    f.write("\n".join(missing))

with open("failed-assets.txt", "w") as f:
    for path, error in failed:
        f.write(f"{path}: {error}\n")

print("Missing and failed file lists saved.", flush=True)
