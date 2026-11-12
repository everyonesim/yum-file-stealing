from remotezip import RemoteZip
import json
from collections import Counter, defaultdict
from pathlib import PurePosixPath

url = "https://archive.org/download/rain-world_202611/Rain%20World.zip"

with open("rain-world/StreamingAssets/webport-files.json") as f:
    files = json.load(f)["files"]

with RemoteZip(url) as z:
    names = set(z.namelist())

    by_basename = defaultdict(list)
    for name in names:
        by_basename[PurePosixPath(name).name].append(name)

    exact = 0
    unique = 0
    ambiguous = 0
    absent = []
    categories = Counter()

    for item in files:
        path = item["path"]
        expected = "StreamingAssets/" + path

        if expected in names:
            exact += 1
            continue

        matches = by_basename.get(PurePosixPath(path).name, [])

        if len(matches) == 1:
            unique += 1
        elif len(matches) > 1:
            ambiguous += 1
        else:
            absent.append(path)
            categories[path.split("/")[0]] += 1

    print("EXACT:", exact)
    print("UNIQUE FILENAME MATCH:", unique)
    print("AMBIGUOUS FILENAME:", ambiguous)
    print("NO FILENAME MATCH:", len(absent))

    print("\nMISSING FILES BY FOLDER:")
    for folder, count in categories.most_common(30):
        print(count, folder)

    print("\nFIRST 40 WITH NO FILENAME MATCH:")
    for path in absent[:40]:
        print(path)
