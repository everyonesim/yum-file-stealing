from remotezip import RemoteZip
from zipfile import ZipFile, ZIP_DEFLATED

url = "https://archive.org/download/rain-world_202611/Rain%20World.zip"

wanted = [
    "Build/WebGLUnity6Build.data",
    "Build/WebGLUnity6Build.framework.js",
    "Build/WebGLUnity6Build.loader.js",
    "Build/WebGLUnity6Build.wasm",
]

with RemoteZip(url) as remote:
    with ZipFile("RainWorld-WebGL.zip", "w", ZIP_DEFLATED) as output:
        for name in wanted:
            print("Extracting:", name)
            output.writestr(name, remote.read(name))

print("Finished: RainWorld-WebGL.zip")
