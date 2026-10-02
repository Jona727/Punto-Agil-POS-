"""Parche para flutter_bluetooth_serial 0.4.0 (librería abandonada).

Con Gradle/AGP modernos esa librería falla al compilar porque:
  1. no declara `namespace` en su build.gradle
  2. declara `package=...` en su AndroidManifest.xml (ya no permitido)

(El compileSdk viejo de los plugins se corrige en android/build.gradle.kts.)

Uso (una vez después de `flutter pub get`, en Windows, macOS o Linux):
    python scripts/patch_bluetooth_serial.py
Es seguro ejecutarlo varias veces.
"""
import glob
import os
import re

NAMESPACE = "io.github.edufolly.flutterbluetoothserial"


def pub_cache_dirs():
    dirs = []
    if os.environ.get("PUB_CACHE"):
        dirs.append(os.path.join(os.environ["PUB_CACHE"], "hosted", "pub.dev"))
    if os.environ.get("LOCALAPPDATA"):  # Windows
        dirs.append(os.path.join(os.environ["LOCALAPPDATA"], "Pub", "Cache", "hosted", "pub.dev"))
    dirs.append(os.path.join(os.path.expanduser("~"), ".pub-cache", "hosted", "pub.dev"))  # macOS/Linux
    return [d for d in dirs if os.path.isdir(d)]


def patch_package(package_dir):
    gradle_file = os.path.join(package_dir, "android", "build.gradle")
    manifest_file = os.path.join(package_dir, "android", "src", "main", "AndroidManifest.xml")

    with open(gradle_file, encoding="utf-8") as f:
        content = f.read()
    if "namespace" not in content:
        content = re.sub(r"android\s*{", 'android {\n    namespace "%s"' % NAMESPACE, content, count=1)
        with open(gradle_file, "w", encoding="utf-8") as f:
            f.write(content)
        print("  namespace agregado en build.gradle")

    with open(manifest_file, encoding="utf-8") as f:
        manifest = f.read()
    cleaned = re.sub(r'\s+package="[^"]*"', "", manifest, count=1)
    if cleaned != manifest:
        with open(manifest_file, "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("  package quitado de AndroidManifest.xml")


def main():
    found = False
    for cache in pub_cache_dirs():
        for package_dir in glob.glob(os.path.join(cache, "flutter_bluetooth_serial-*")):
            found = True
            print("Parcheando", package_dir)
            patch_package(package_dir)
    if not found:
        print("No se encontró flutter_bluetooth_serial. ¿Ejecutaste `flutter pub get`?")


if __name__ == "__main__":
    main()
