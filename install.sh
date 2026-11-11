#!/bin/sh
# Installs "proton-experimental-tzfix": a copy of YOUR Proton Experimental with four DLLs replaced
# (kernel32 and kernelbase, 64-bit and 32-bit). Your original Proton is not modified.
#
# Adapted from hiraethi's install.sh (https://github.com/hiraethi/archeage-proton-tzfix), which does the same job for
# proton-cachyos. Same flow; the exact-version match, stock-DLL check, final hash check and the per-build folders
# (builds/<build>/) are additions here.
#
# It refuses to run unless your Proton Experimental is exactly one of the builds in builds/ (each holds the DLLs made
# for that build). It makes no network connections.
set -eu

NAME="proton-experimental-tzfix"
HERE=$(cd "$(dirname "$0")" && pwd)
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
SRC="${PROTON_EXPERIMENTAL:-$STEAM_ROOT/steamapps/common/Proton - Experimental}"
DEST_ROOT="${STEAM_COMPAT_TOOLS:-$STEAM_ROOT/compatibilitytools.d}"
DEST="$DEST_ROOT/$NAME"

die() { echo "error: $*" >&2; exit 1; }

command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found"

# 1. Your Proton Experimental is a build these DLLs were made for. Find its folder in builds/.
[ -f "$SRC/version" ] || die "Proton Experimental not found at: $SRC
       Install it from Steam (Library > Tools > Proton Experimental), or set PROTON_EXPERIMENTAL=/path"
HAVE_VERSION=$(head -n 1 "$SRC/version")
BUILD=""
SUPPORTED=""
for dir in "$HERE"/builds/*/; do
    [ -f "${dir}VERSION" ] || continue
    want=$(head -n 1 "${dir}VERSION")
    SUPPORTED="$SUPPORTED
         $want"
    if [ "$want" = "$HAVE_VERSION" ]; then BUILD="${dir%/}"; fi
done
if [ -z "$BUILD" ]; then
    die "unsupported Proton Experimental build.
       found:     $HAVE_VERSION
       supported:$SUPPORTED
       These DLLs only match those exact builds. Do not edit the version string to force it;
       rebuild for your build instead (see build/README.md)."
fi
BUILD_ID=$(basename "$BUILD")
echo "Proton Experimental build: $HAVE_VERSION (using builds/$BUILD_ID)"

# 2. The DLLs in this package are intact.
(cd "$BUILD" && sha256sum -c --quiet SHA256SUMS) || die "package DLLs do not match SHA256SUMS (corrupt download?)"

# 3. The four DLLs about to be replaced are the stock ones (nothing already modified).
(cd "$SRC/files/lib/wine" && sha256sum -c --quiet "$BUILD/STOCK-SHA256SUMS") \
    || die "the stock DLLs in your Proton Experimental do not match builds/$BUILD_ID/STOCK-SHA256SUMS; refusing"

# 4. Destination is free and there is room (a reflink copy on btrfs/xfs needs far less).
[ -e "$DEST" ] && die "$DEST already exists. Remove it first to reinstall."
NEED_KB=$(du -sk "$SRC" | cut -f1)
mkdir -p "$DEST_ROOT"
HAVE_KB=$(df -Pk "$DEST_ROOT" | awk 'NR==2{print $4}')
[ "$HAVE_KB" -gt $((NEED_KB + 262144)) ] || echo "warning: free space ($HAVE_KB KB) is close to the copy size ($NEED_KB KB)" >&2

# 5. Build the tool. Clean up on any failure so no half-installed tool is left behind.
trap 'rm -rf "$DEST"' EXIT
echo "Copying $SRC"
echo "     to $DEST"
cp -a --reflink=auto "$SRC" "$DEST"
chmod -R u+w "$DEST"
for arch in x86_64 i386; do
    for dll in kernel32 kernelbase; do
        cp "$BUILD/dlls/$arch-windows/$dll.dll" "$DEST/files/lib/wine/$arch-windows/$dll.dll"
    done
done

DISPLAY_NAME="Proton Experimental 11.0-$BUILD_ID (self-built TZ fix)"
cat > "$DEST/compatibilitytool.vdf" <<EOF
"compatibilitytools"
{
  "compat_tools"
  {
    "$NAME" // Internal name of this tool
    {
      "install_path" "."
      "display_name" "$DISPLAY_NAME"
      "from_oslist"  "windows"
      "to_oslist"    "linux"
    }
  }
}
EOF
# Mark the tool as modified in Proton's log header; Proton reads this file only for logging.
echo "$(echo "$HAVE_VERSION" | cut -d' ' -f1) experimental-11.0-$BUILD_ID-tzfix-x86_64" > "$DEST/version"
cp "$HERE/patch/tzspecific-ex.patch" "$DEST/tzspecific-ex.patch"

# 6. Final check of what was installed.
(cd "$DEST/files/lib/wine" && sed 's#  dlls/#  #' "$BUILD/SHA256SUMS" | sha256sum -c --quiet) \
    || die "installed DLLs do not match SHA256SUMS"
trap - EXIT

echo
echo "Done: $DEST"
echo "Next: fully quit and restart Steam (it reads installed tools at startup), then"
echo "      ArcheAge Chronicles > Properties > Compatibility >"
echo "      'Force the use of a specific Steam Play compatibility tool' >"
echo "      '$DISPLAY_NAME'."
echo "To remove: select another tool for the game, then delete $DEST"
