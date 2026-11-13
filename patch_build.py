#!/usr/bin/env python3
"""Patch the WebGL build's file layer.

The port mounts StreamingAssets/ as a virtual filesystem and pulls each file the
game opens with a blocking request, one after another. Two consequences:

  * a missing file (404) or a length mismatch throws out of the middle of a read,
    and the game sits on the loading screen with nothing to go on,
  * because every request waits for a full round trip, a region load that needs
    a few hundred files crawls when the assets are served over the network.

This patch keeps the same mount and adds four things to it:

  * a failed file is retried against the other asset bases before giving up,
    then logged, reported on screen, and replaced with a placeholder so the load
    finishes,
  * files are prefetched in parallel a window ahead of the game's last read, so
    the blocking reads mostly hit memory instead of the network,
  * a path that is missing from webport-files.json is fetched on demand instead
    of failing the read,
  * the launcher gets a callback for the file currently being read.

Run from the repo root after replacing Build/ from a fresh export:

    python3 patch_build.py            # apply
    python3 patch_build.py --check    # report whether it is applied
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

FRAMEWORK = Path("Build/WebGLUnity6Build.framework.js")
MARKER = "RWWebFiles.install"

NEW_RW_WEB_FILES = r"""
var RWWebFiles={
cachedBytes:0,limit:33554432,cache:[],downloads:0,downloadedBytes:0,syncing:false,pendingSync:false,
queue:[],spots:Object.create(null),exact:Object.create(null),missing:Object.create(null),cursor:0,readIndex:0,windowEnd:0,windowBytes:33554432,
active:0,maxActive:2,installed:false,base:"",
memory:Object.create(null),memoryOrder:[],memoryBytes:0,memoryLimit:67108864,
statusTimer:0,
fillers:{"GameVersion.txt":"1.11.8\n","whitelist.txt":"\n","dlcminver.json":"{}                                             ","worldversion.txt":"2"},
flush:function(){if(RWWebFiles.syncing){RWWebFiles.pendingSync=true;return}RWWebFiles.syncing=true;var settled=false;var timer=setTimeout(function(){if(settled)return;settled=true;RWWebFiles.syncing=false;Module["rainWorldSaveSync"]="timeout";console.warn("Rain World save sync did not answer, continuing.");if(RWWebFiles.pendingSync){RWWebFiles.pendingSync=false;RWWebFiles.flush()}},4000);FS.syncfs(false,function(error){if(settled)return;settled=true;clearTimeout(timer);RWWebFiles.syncing=false;Module["rainWorldSaveSync"]=error?String(error):"saved";if(error)console.error("Rain World save sync failed:",error);if(RWWebFiles.pendingSync){RWWebFiles.pendingSync=false;RWWebFiles.flush()}})},
sources:function(node){var list=[node.webUrl];var extra=typeof window!=="undefined"?window["rainWorldAssetFallbacks"]:null;if(extra){for(var i=0;i<extra.length;i++){var base=String(extra[i]||"").replace(/\/+$/,"");if(base)list.push(base+"/"+node.webPath)}}return list},
candidates:function(node){var list=RWWebFiles.sources(node),out=[];for(var i=0;i<list.length;i++){if(node.usedBytes>20971520&&list.length>1&&list[i].indexOf("jsdelivr.net")>=0)continue;if(out.indexOf(list[i])<0)out.push(list[i])}return out.length?out:list},
report:function(node){var now=Date.now();if(now-RWWebFiles.statusTimer<200)return;RWWebFiles.statusTimer=now;var status=typeof window!=="undefined"?window["rainWorldFileStatus"]:null;if(typeof status!=="function")return;try{status({path:node.webPath,bytes:RWWebFiles.memoryBytes,downloaded:RWWebFiles.downloadedBytes,files:RWWebFiles.downloads})}catch(error){}},
remember:function(path,bytes){if(RWWebFiles.memory[path])return;RWWebFiles.memory[path]=bytes;RWWebFiles.memoryOrder.push(path);RWWebFiles.memoryBytes+=bytes.length;while(RWWebFiles.memoryBytes>RWWebFiles.memoryLimit&&RWWebFiles.memoryOrder.length>0){var old=RWWebFiles.memoryOrder.shift();var held=RWWebFiles.memory[old];if(held){delete RWWebFiles.memory[old];RWWebFiles.memoryBytes-=held.length}}},
fetchBytes:function(node){var ready=RWWebFiles.memory[node.webPath];if(ready){delete RWWebFiles.memory[node.webPath];RWWebFiles.memoryBytes-=ready.length;return ready}var urls=RWWebFiles.candidates(node);for(var index=0;index<urls.length;index++){var url=urls[index];var started=Date.now();var request=new XMLHttpRequest;request.open("GET",url,false);request.overrideMimeType("text/plain; charset=x-user-defined");try{request.send(null)}catch(error){console.error("Rain World file network error:",url,String(error));continue}if(request.status<200||request.status>=300){console.error("Rain World file request failed:",request.status,url);continue}var text=request.responseText;if(node.webBase64){try{text=atob(text)}catch(error){console.error("Rain World file decode failed:",url,String(error));continue}}if(text.length!==node.usedBytes){console.error("Rain World file size mismatch:",url,text.length,node.usedBytes);continue}var bytes=new Uint8Array(text.length);for(var i=0;i<text.length;i++)bytes[i]=text.charCodeAt(i)&255;var elapsed=Date.now()-started;if(elapsed>3000)console.warn("Rain World slow read ("+elapsed+"ms):",url);return bytes}return null},
prefetchBytes:function(node){var urls=RWWebFiles.candidates(node);function attempt(index){if(index>=urls.length)return Promise.resolve(null);var url=urls[index];return fetch(url,{credentials:"omit",cache:"default"}).then(function(response){if(!response.ok)throw new Error("HTTP "+response.status);return node.webBase64?response.text():response.arrayBuffer()}).then(function(payload){var bytes;if(node.webBase64){var decoded=atob(payload);bytes=new Uint8Array(decoded.length);for(var i=0;i<decoded.length;i++)bytes[i]=decoded.charCodeAt(i)&255}else{bytes=new Uint8Array(payload)}if(bytes.length!==node.usedBytes)throw new Error("length "+bytes.length+" != "+node.usedBytes);return bytes}).catch(function(error){console.warn("Rain World prefetch skipped:",url,String(error));return attempt(index+1)})}try{return attempt(0)}catch(error){return Promise.resolve(null)}},
pump:function(){if(!RWWebFiles.installed)return;if(!RWWebFiles.remote||RWWebFiles.downloads<120)return;if(RWWebFiles.cursor<RWWebFiles.readIndex)RWWebFiles.cursor=RWWebFiles.readIndex;var edge=RWWebFiles.windowEnd>RWWebFiles.readIndex?RWWebFiles.windowEnd:RWWebFiles.readIndex,ahead=0;while(edge<RWWebFiles.queue.length&&ahead<RWWebFiles.windowBytes){var wanted=RWWebFiles.queue[edge];if(wanted&&wanted.usedBytes>0&&wanted.usedBytes<=8388608&&wanted.contents===null&&!RWWebFiles.memory[wanted.webPath])ahead+=wanted.usedBytes;edge++}RWWebFiles.windowEnd=edge;while(RWWebFiles.active<RWWebFiles.maxActive&&RWWebFiles.cursor<RWWebFiles.windowEnd){var node=RWWebFiles.queue[RWWebFiles.cursor];RWWebFiles.cursor++;if(!node||node.usedBytes<=0||node.usedBytes>8388608||node.contents!==null||RWWebFiles.memory[node.webPath])continue;RWWebFiles.active++;(function(target){RWWebFiles.prefetchBytes(target).then(function(bytes){RWWebFiles.active--;if(bytes&&bytes.length===target.usedBytes)RWWebFiles.remember(target.webPath,bytes);RWWebFiles.pump()},function(error){RWWebFiles.active--;console.warn("Rain World prefetch error:",String(error));RWWebFiles.pump()})})(node)}},
install:function(source){RWWebFiles.base=source;RWWebFiles.installed=true;RWWebFiles.remote=!!(typeof window!=="undefined"&&window["rainWorldRemote"]);RWWebFiles.cursor=0;RWWebFiles.readIndex=0;RWWebFiles.windowEnd=0;setTimeout(function(){RWWebFiles.pump()},0)},
load:function(node){if(node.contents!==null)return;if(node.webDirty||node.usedBytes===0){node.contents=new Uint8Array(node.usedBytes);RWWebFiles.report(node);return}var spot=RWWebFiles.spots[node.webPath];if(spot!==undefined&&spot>RWWebFiles.readIndex)RWWebFiles.readIndex=spot;var bytes=RWWebFiles.fetchBytes(node);if(bytes===null){var name=node.webPath.split("/").pop();var filler=RWWebFiles.fillers[name];if(filler&&filler.length===node.usedBytes){bytes=new Uint8Array(filler.length);for(var index=0;index<filler.length;index++)bytes[index]=filler.charCodeAt(index)&255;console.warn("Rain World file missing from every source, used a stand-in:",node.webPath)}else{console.error("Rain World file unavailable, loading an empty placeholder:",node.webUrl);node.webFailed=true;bytes=new Uint8Array(node.usedBytes)}}node.contents=bytes;node.webCachedSize=bytes.length;RWWebFiles.downloads++;RWWebFiles.downloadedBytes+=bytes.length;RWWebFiles.cachedBytes+=bytes.length;RWWebFiles.cache.push(node);RWWebFiles.report(node);RWWebFiles.pump()},
trim:function(){var attempts=RWWebFiles.cache.length;while(RWWebFiles.cachedBytes>RWWebFiles.limit&&attempts-- >0){var node=RWWebFiles.cache.shift();if(node.webOpen>0){RWWebFiles.cache.push(node);continue}RWWebFiles.cachedBytes-=node.webCachedSize;node.webCachedSize=0;if(!node.webDirty)node.contents=null}},
attach:function(node,source){var original=node.stream_ops;var operations={};Object.keys(original).forEach(function(key){operations[key]=original[key]});operations.open=function(stream){node.webOpen++};operations.close=function(stream){node.webOpen--;RWWebFiles.trim()};["read","mmap","write","allocate","msync"].forEach(function(key){if(!original[key])return;operations[key]=function(){RWWebFiles.load(node);if(key==="write"||key==="allocate"||key==="msync")node.webDirty=true;return original[key].apply(null,arguments)}});node.stream_ops=operations;var originalNode=node.node_ops;node.node_ops={getattr:originalNode.getattr,setattr:function(target,attributes){if(attributes.size!==undefined){if(attributes.size>0)RWWebFiles.load(target);target.webDirty=true}return originalNode.setattr(target,attributes)}}},
add:function(root,entry,source){var relative=entry.path.toLowerCase();var slash=relative.lastIndexOf("/");var directory=slash<0?root:root+"/"+relative.substring(0,slash);FS.mkdirTree(directory);RWWebFiles.guardTree(directory);var name=relative.substring(slash+1);var node=FS.create(directory+"/"+name,438);node.usedBytes=entry.size;node.contents=null;node.webBase64=!!entry.encodedPath;node.webPath=(entry.encodedPath||entry.path).split("/").map(encodeURIComponent).join("/");node.webUrl=source+"/"+node.webPath;node.webDirty=false;node.webOpen=0;node.webCachedSize=0;node.webFailed=false;RWWebFiles.attach(node,source);RWWebFiles.spots[node.webPath]=RWWebFiles.queue.length;RWWebFiles.exact[entry.path.toLowerCase()]=entry.path;RWWebFiles.queue.push(node)},
guardTree:function(path){var parts=String(path).split("/");for(var i=2;i<=parts.length;i++)RWWebFiles.guard(parts.slice(0,i).join("/"))},
guard:function(path){try{var node=FS.lookupPath(path).node;if(!node||node._webGuarded)return;node._webGuarded=true;var original=node.node_ops;var copy={};Object.keys(original).forEach(function(key){copy[key]=original[key]});var base=original.lookup;copy.lookup=function(parent,name){var found=base(parent,name);if(found)return found;var children=parent?parent.contents:null;if(children&&children.length){var wanted=String(name).toLowerCase();for(var i=0;i<children.length;i++){var child=children[i];if(child&&child.name&&String(child.name).toLowerCase()===wanted)return child}}return RWWebFiles.fetchThrough(parent,name)};node.node_ops=copy}catch(error){console.error("Rain World directory guard failed:",path,String(error))}},
fetchThrough:function(parent,name){try{if(!name||name.indexOf(".")<0)return null;RWWebFiles.onDemand=(RWWebFiles.onDemand||0)+1;if(RWWebFiles.onDemand>20000)return null;var directory=FS.getPath(parent);if(directory.indexOf("/rainworld")!==0)return null;var path=directory.replace(/\/+$/,"")+"/"+name;var key=path.substring("/rainworld/".length).toLowerCase();var missAt=RWWebFiles.missing[key];if(missAt&&Date.now()-missAt<4000)return null;var relative=RWWebFiles.exact[key]||path.substring("/rainworld/".length);var encoded=relative.split("/").map(encodeURIComponent).join("/");var node={webUrl:RWWebFiles.base+"/"+encoded,webPath:encoded,usedBytes:-1,webBase64:false};var urls=RWWebFiles.candidates(node);for(var index=0;index<urls.length;index++){var url=urls[index];var request=new XMLHttpRequest;request.open("GET",url,false);request.overrideMimeType("text/plain; charset=x-user-defined");try{request.send(null)}catch(error){continue}if(request.status<200||request.status>=300)continue;var text=request.responseText;var bytes=new Uint8Array(text.length);for(var i=0;i<text.length;i++)bytes[i]=text.charCodeAt(i)&255;console.warn("Rain World file was missing from the manifest, fetched on demand:",path,bytes.length);FS.mkdirTree(directory);var created=FS.create(directory.replace(/\/+$/,"")+"/"+name,438);created.usedBytes=bytes.length;created.contents=bytes;created.webBase64=false;created.webPath=encoded;created.webUrl=url;created.webDirty=false;created.webOpen=0;created.webCachedSize=bytes.length;created.webFailed=false;RWWebFiles.attach(created,url);return created}RWWebFiles.missing[key]=Date.now();console.warn("Rain World file is not in the manifest and no source has it:",relative)}catch(error){console.error("Rain World on-demand file fetch failed:",String(error))}return null}
};
"""

NEW_MOUNT = r"""
function _WebPortMountFiles(sourcePointer){var source=UTF8ToString(sourcePointer).replace(/\/$/,"");var request=new XMLHttpRequest;request.open("GET",source+"/webport-files.json?webport="+Date.now(),false);request.send(null);if(request.status<200||request.status>=300){throw new Error("Rain World file manifest request failed: "+request.status)}var entries=JSON.parse(request.responseText).files;FS.mkdirTree("/rainworld");for(var i=0;i<entries.length;i++)RWWebFiles.add("/rainworld",entries[i],source);RWWebFiles.guard("/rainworld");Module["rainWorldFiles"]=RWWebFiles;Module["rainWorldFS"]=FS;window["rainWorldFiles"]=RWWebFiles;window["rainWorldFS"]=FS;RWWebFiles.install(source);return entries.length}
"""


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
        print("patched" if patched else "stock (no resilient file layer)")
        return 0 if patched else 1

    if patched:
        print("already patched")
        return 0

    start = source.find("var RWWebFiles={")
    stop = source.find("function _WebPortFlushFiles(){")
    if start < 0 or stop < 0 or stop < start:
        print("could not find the RWWebFiles block; build may differ")
        return 3

    source = source[:start] + NEW_RW_WEB_FILES.strip() + "\n" + source[stop:]

    mount_start = source.find("function _WebPortMountFiles(sourcePointer){")
    mount_stop = source.find("var RWWebSpectrum={")
    if mount_start < 0 or mount_stop < 0 or mount_stop < mount_start:
        print("could not find the mount function; build may differ")
        return 4

    source = source[:mount_start] + NEW_MOUNT.strip() + "\n" + source[mount_stop:]

    FRAMEWORK.write_text(source, encoding="utf-8", errors="surrogateescape")
    print(f"patched {FRAMEWORK}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
