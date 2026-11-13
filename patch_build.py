#!/usr/bin/env python3
"""Patch the WebGL build's file layer so one bad asset cannot hang the game.

The stock port mounts StreamingAssets/ as a virtual filesystem and pulls each
file with a blocking request. If a file is missing (404) or its length differs
from webport-files.json, the stock code throws out of the middle of a file read.
The game then sits on the loading art forever, which reads as a freeze.

This patch keeps the same mount, but:

  * a failed file is retried against a fallback asset base (window
    .rainWorldAssetFallback, set by index.html) before giving up,
  * a file that still cannot be fetched or does not match its documented length
    is logged, reported on screen, and replaced with an empty buffer of the
    right length instead of throwing, so the load continues.

Run from the repo root after replacing Build/ from a fresh export:

    python3 patch_build.py            # apply
    python3 patch_build.py --check    # report whether it is applied
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

FRAMEWORK = Path("Build/WebGLUnity6Build.framework.js")
MARKER = "rainWorldAssetFallback"

OLD_ADD = (
    'node.webUrl=source+"/"+(entry.encodedPath||entry.path).split("/").map(encodeURIComponent).join("/");'
)

NEW_ADD = (
    'node.webPath=(entry.encodedPath||entry.path).split("/").map(encodeURIComponent).join("/");'
    'node.webUrl=source+"/"+node.webPath;'
)

OLD_LOAD = (
    'load:function(node){if(node.contents!==null)return;'
    'if(node.webDirty||node.usedBytes===0){node.contents=new Uint8Array(node.usedBytes);return}'
    'var request=new XMLHttpRequest;request.open("GET",node.webUrl,false);'
    'request.overrideMimeType("text/plain; charset=x-user-defined");'
    'try{request.send(null)}catch(error){console.error("Rain World file network error:",node.webUrl,String(error));throw new FS.ErrnoError(29)}'
    'if(request.status<200||request.status>=300){console.error("Rain World file request failed:",request.status,node.webUrl);throw new FS.ErrnoError(29)}'
    'var text=request.responseText;if(node.webBase64)text=atob(text);'
    'var bytes=new Uint8Array(text.length);for(var i=0;i<text.length;i++)bytes[i]=text.charCodeAt(i)&255;'
    'if(bytes.length!==node.usedBytes){console.error("Rain World file size mismatch:",node.webUrl,bytes.length,node.usedBytes);throw new FS.ErrnoError(29)}'
    'node.contents=bytes;node.webCachedSize=bytes.length;RWWebFiles.downloads++;'
    'RWWebFiles.downloadedBytes+=bytes.length;RWWebFiles.cachedBytes+=bytes.length;RWWebFiles.cache.push(node)},'
)

NEW_LOAD = (
    'load:function(node){if(node.contents!==null)return;'
    'if(node.webDirty||node.usedBytes===0){node.contents=new Uint8Array(node.usedBytes);return}'
    'var bytes=RWWebFiles.fetchBytes(node);'
    'if(bytes===null){console.error("Rain World file unavailable, loading an empty placeholder:",node.webUrl);'
    'node.webFailed=true;bytes=new Uint8Array(node.usedBytes)}'
    'node.contents=bytes;node.webCachedSize=bytes.length;RWWebFiles.downloads++;'
    'RWWebFiles.downloadedBytes+=bytes.length;RWWebFiles.cachedBytes+=bytes.length;RWWebFiles.cache.push(node)},'
    'fetchBytes:function(node){'
    'var sources=[node.webUrl];'
    'var fallback=typeof window!=="undefined"?window["' + MARKER + '"]:"";'
    'if(fallback&&node.webPath)sources.push(String(fallback).replace(/\\/+$/,"")+"/"+node.webPath);'
    'for(var index=0;index<sources.length;index++){'
    'var url=sources[index];'
    'var request=new XMLHttpRequest;request.open("GET",url,false);'
    'request.overrideMimeType("text/plain; charset=x-user-defined");'
    'try{request.send(null)}catch(error){console.error("Rain World file network error:",url,String(error));continue}'
    'if(request.status<200||request.status>=300){console.error("Rain World file request failed:",request.status,url);continue}'
    'var text=request.responseText;'
    'if(node.webBase64){try{text=atob(text)}catch(error){console.error("Rain World file decode failed:",url,String(error));continue}}'
    'if(text.length!==node.usedBytes){console.error("Rain World file size mismatch:",url,text.length,node.usedBytes);continue}'
    'var bytes=new Uint8Array(text.length);'
    'for(var i=0;i<text.length;i++)bytes[i]=text.charCodeAt(i)&255;'
    'return bytes}'
    'return null},'
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="only report the patch state")
    args = parser.parse_args()

    if not FRAMEWORK.is_file():
        print(f"missing {FRAMEWORK}")
        return 2

    source = FRAMEWORK.read_text(encoding="utf-8", errors="surrogateescape")
    patched = MARKER in source

    if args.check:
        print("patched" if patched else "stock (no resilience patch)")
        return 0 if patched else 1

    if patched:
        print("already patched")
        return 0

    missing = [name for name, chunk in (("add", OLD_ADD), ("load", OLD_LOAD)) if chunk not in source]
    if missing:
        print(f"could not find the stock {', '.join(missing)} block; build may differ")
        return 3

    source = source.replace(OLD_ADD, NEW_ADD, 1).replace(OLD_LOAD, NEW_LOAD, 1)
    FRAMEWORK.write_text(source, encoding="utf-8", errors="surrogateescape")
    print(f"patched {FRAMEWORK}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
