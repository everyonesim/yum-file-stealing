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
