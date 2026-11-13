# Rain World (web)

Browser port of Rain World 1.11.8, published with GitHub Pages:
**https://everyonesim.github.io/yum-file-stealing/**

## How the port loads its data

`Build/WebGLUnity6Build.data` is only about 29 MB, so the game does **not** ship
its content inside the Unity bundle. Instead the build mounts the
`StreamingAssets` folder as a virtual filesystem at `/rainworld` and streams each
file on demand:

1. `index.html` starts Unity with `streamingAssetsUrl` pointing at the asset tree.
2. The native webport patch inside `framework.js` performs a **blocking** request
   for `<streamingAssetsUrl>/webport-files.json`.
3. Every entry in that manifest becomes a file node; the bytes are fetched with a
   blocking request the first time the game opens it.
4. Two consequences matter for debugging:
   - A missing or wrong-length file throws while the game is inside a read, so the
     load stops and the screen keeps the loading art. It looks like a freeze.
   - Because the requests block, a region load holds the page for a while. The
     launcher shows a live "assets … MB / N files" readout so that is visible.
5. Entries with an `encodedPath` are served as **base64 text** from
   `StreamingAssets/WebPortBytes/...`. Those are generated locally; the source
   archive only carries the plain files.
6. Entries whose manifest size is `0` are empty placeholders (audio is played
   through the Web Audio layer), so they are never requested.

`sync_assets.py` rebuilds the tree so every manifest entry exists at the exact
size the build expects, including the base64 mirrors.

## Layout

```
index.html              launcher (Pages entry point)
.nojekyll               publish files as-is, no Jekyll processing
sync_assets.py          builds/repairs the StreamingAssets tree
Build/                  Unity build, committed and served by Pages (~87 MB)
```

`StreamingAssets/` is about 1.4 GB, which is beyond a Pages site, so it lives on
the **`game-assets`** branch:

```
https://raw.githubusercontent.com/everyonesim/yum-file-stealing/game-assets/StreamingAssets/
```

`index.html` checks its own folder first, then `rain-world/`, then that branch, so
the same file works locally, on Pages, and with assets on the branch.

## Setup

```bash
pip install remotezip
python3 sync_assets.py                       # download/repair StreamingAssets
python3 sync_assets.py --verify              # report only, downloads nothing
python3 sync_assets.py --out rain-world/StreamingAssets   # old layout
python3 -m http.server 8000                  # then open http://localhost:8000/
```

Run it from the repo root so `StreamingAssets/` sits next to `index.html`.

## Asset delivery

`index.html` picks the first asset base that answers with a *complete* tree: this
folder, then `rain-world/`, then the `game-assets` branch. A folder that has the
manifest but not the data (the usual sign of an extractor that skipped the
`WebPortBytes` mirrors) is skipped rather than streamed half-broken, and every
base it rejected is handed to the build as a fallback.

jsDelivr and selcdn were both tried as a faster host for the assets and neither
will serve this branch: the tree is over their package limits, so they answer 403.
The raw branch is the remote source.

The mount lowercases every path, but 324 of the real files have capitals in their
names (all of `shaders/`, `GameVersion.txt`, the `WebPortBytes` mirrors), so those
reads missed and each one fell through to the network. Directory lookups are now
case-insensitive and keep the real name for the request, so a capitalised path
resolves from the mount without a single extra request.

The stock port reads files one at a time with blocking requests, which makes a
region load crawl when the data comes over the network. The patch prefetches
about 100 MB ahead of the file the game last opened, eight requests at a time, so
the blocking reads mostly hit memory. The launcher also shows the file being read
in the corner of the screen, so a slow load never looks stuck.

## Build patches

`Build/WebGLUnity6Build.framework.js` is patched from the stock export by
`patch_build.py`. Its file layer used to throw out of the middle of a read when a
file 404'd or did not match its manifest length, which stalled the game on the
loading art. Now a failed file is retried against every other asset base
(`window.rainWorldAssetFallbacks`) and, if it still fails, the load logs it, the
launcher shows the path, and the game continues with an empty placeholder. A path
that is missing from `webport-files.json` entirely is fetched on demand, and files
are prefetched in parallel ahead of the game's reads.

Re-apply after replacing `Build/` with a fresh export:

```bash
python3 patch_build.py           # apply
python3 patch_build.py --check   # is it applied?
```

## Troubleshooting

A red banner inside the game names the file that failed and where it came from.
Typical messages:

| Banner text | Meaning | Fix |
| --- | --- | --- |
| `Rain World file request failed: 404 …` | file not on the host, or the path case differs | run `sync_assets.py` |
| `Rain World file size mismatch: … 12345 67890` | truncated or stale copy | run `sync_assets.py`, it re-downloads |
| `Rain World file manifest request failed` | `webport-files.json` unreachable from the asset folder | check the folder / branch name |
| `IndexedDB is not available` | private window, so saves will not persist | use a normal window |

The "assets … MB" readout in the corner of the canvas is the port streaming its
data files. If the number stops moving during a region load, that is a stalled
file request rather than a game crash.
