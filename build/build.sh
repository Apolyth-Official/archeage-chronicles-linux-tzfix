#!/bin/sh
# Builds the four patched DLLs (kernel32 and kernelbase, 64-bit and 32-bit) for one Valve Wine commit.
#
# Usage:  build/build.sh <valve-wine-commit> <output-dir>
#   <valve-wine-commit>  the `wine` submodule pin of the Proton commit your Experimental build came from
#                        (see build/README.md, "For a new Proton Experimental build")
#   <output-dir>         must not exist yet; receives src/, build/ and the finished dlls/
#
# Needs: podman, curl, tar, patch, sha256sum, and network access (source download, container image, dnf packages).
# This is the recipe from build/README.md as one script. It does not install anything on your system.
set -eu

COMMIT=${1:?usage: build/build.sh <valve-wine-commit> <output-dir>}
OUT=${2:?usage: build/build.sh <valve-wine-commit> <output-dir>}
HERE=$(cd "$(dirname "$0")/.." && pwd)
PATCH="$HERE/patch/tzspecific-ex.patch"
IMAGE=registry.fedoraproject.org/fedora:44

case "$COMMIT" in *[!0-9a-f]*|"") echo "error: commit must be a full lowercase hex SHA" >&2; exit 1 ;; esac
[ ${#COMMIT} -eq 40 ] || { echo "error: commit must be the full 40-character SHA" >&2; exit 1; }
[ ! -e "$OUT" ] || { echo "error: $OUT already exists" >&2; exit 1; }
for tool in podman curl tar patch sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found" >&2; exit 1; }
done

mkdir -p "$OUT/src" "$OUT/build"
OUT=$(cd "$OUT" && pwd)

echo "1. Fetching ValveSoftware/wine @ $COMMIT"
curl -fL --proto '=https' --proto-redir '=https' -o "$OUT/wine.tar.gz" "https://codeload.github.com/ValveSoftware/wine/tar.gz/$COMMIT"
tar -xzf "$OUT/wine.tar.gz" --strip-components=1 -C "$OUT/src"

echo "2. Applying the patch (a failure here means the surrounding code changed: do not force it)"
patch -p1 -d "$OUT/src" -i "$PATCH"

echo "3. Building in a $IMAGE container"
podman run --rm --security-opt label=disable -v "$OUT/src":/src -v "$OUT/build":/build "$IMAGE" sh -ec '
  dnf -y --setopt=zchunk=false install gcc make bison flex patch tar gzip diffutils findutils which perl-interpreter \
      python3 autoconf automake mingw32-gcc mingw64-gcc mingw32-binutils mingw64-binutils gettext >/dev/null
  cd /src && ./autogen.sh
  cd /build && /src/configure --enable-archs=i386,x86_64 \
    --without-x --without-freetype --without-fontconfig --without-wayland --without-vulkan --without-opengl \
    --without-sdl --without-pulse --without-alsa --without-oss --without-cups --without-dbus --without-gnutls \
    --without-gstreamer --without-krb5 --without-gssapi --without-pcsclite --without-udev --without-usb \
    --without-v4l2 --without-ffmpeg --without-capi --without-opencl --without-pcap --without-sane \
    --without-gphoto --without-unwind --without-inotify --without-netapi --without-coreaudio
  make -j"$(nproc)" \
    dlls/kernelbase/x86_64-windows/kernelbase.dll dlls/kernel32/x86_64-windows/kernel32.dll \
    dlls/kernelbase/i386-windows/kernelbase.dll   dlls/kernel32/i386-windows/kernel32.dll \
    dlls/kernel32/tests/x86_64-windows/kernel32_test.exe dlls/kernel32/tests/i386-windows/kernel32_test.exe
  # Strip debug info only. Stock Proton keeps the COFF symbol table, so do not use a full strip.
  x86_64-w64-mingw32-strip --strip-debug dlls/*/x86_64-windows/kernel32.dll dlls/*/x86_64-windows/kernelbase.dll
  i686-w64-mingw32-strip   --strip-debug dlls/*/i386-windows/kernel32.dll   dlls/*/i386-windows/kernelbase.dll
'

echo "4. Collecting the DLLs into $OUT/dlls"
for arch in x86_64 i386; do
    mkdir -p "$OUT/dlls/$arch-windows"
    for dll in kernel32 kernelbase; do
        cp "$OUT/build/dlls/$dll/$arch-windows/$dll.dll" "$OUT/dlls/$arch-windows/$dll.dll"
    done
done
(cd "$OUT" && sha256sum dlls/i386-windows/kernel32.dll dlls/i386-windows/kernelbase.dll \
    dlls/x86_64-windows/kernel32.dll dlls/x86_64-windows/kernelbase.dll | tee SHA256SUMS)
echo "Done. Compare exports and imports against your stock Proton before using the result (tools/verify-dlls.py)."
