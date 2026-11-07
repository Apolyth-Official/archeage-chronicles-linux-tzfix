#!/bin/sh
# Installs "proton-experimental-tzfix": a copy of YOUR Proton Experimental with four DLLs replaced
# (kernel32 and kernelbase, 64-bit and 32-bit). Your original Proton is not modified.
#
# Adapted from hiraethi's install.sh (https://github.com/hiraethi/archeage-proton-tzfix), which does the same job for
# proton-cachyos. Same flow; the exact-version pin, stock-DLL check and final hash check are additions here.
#
# It refuses to run unless your Proton Experimental is exactly the build these DLLs were made for.
# It makes no network connections.
set -eu

WANT_VERSION="1793301796 experimental-11.0-20261027b-x86_64"
NAME="proton-experimental-tzfix"
HERE=$(cd "$(dirname "$0")" && pwd)
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
SRC="${PROTON_EXPERIMENTAL:-$STEAM_ROOT/steamapps/common/Proton - Experimental}"
DEST_ROOT="${STEAM_COMPAT_TOOLS:-$STEAM_ROOT/compatibilitytools.d}"
DEST="$DEST_ROOT/$NAME"

die() { echo "error: $*" >&2; exit 1; }

command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found"

# 1. The DLLs in this package are intact.
(cd "$HERE" && sha256sum -c --quiet SHA256SUMS) || die "package DLLs do not match SHA256SUMS (corrupt download?)"

# 2. Your Proton Experimental is the exact build these DLLs were made for.
[ -f "$SRC/version" ] || die "Proton Experimental not found at: $SRC
       Install it from Steam (Library > Tools > Proton Experimental), or set PROTON_EXPERIMENTAL=/path"
HAVE_VERSION=$(head -n 1 "$SRC/version")
if [ "$HAVE_VERSION" != "$WANT_VERSION" ]; then
    die "unsupported Proton Experimental build.
       found:    $HAVE_VERSION
       expected: $WANT_VERSION
       These DLLs only match that exact build. Do not edit the version string to force it;
       rebuild for your build instead (see build/README.md)."
fi

# 3. The four DLLs about to be replaced are the stock ones (nothing already modified).
(cd "$SRC/files/lib/wine" && sha256sum -c --quiet "$HERE/STOCK-SHA256SUMS") \
    || die "the stock DLLs in your Proton Experimental do not match STOCK-SHA256SUMS; refusing"

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
        cp "$HERE/dlls/$arch-windows/$dll.dll" "$DEST/files/lib/wine/$arch-windows/$dll.dll"
    done
done

cat > "$DEST/compatibilitytool.vdf" <<EOF
"compatibilitytools"
{
  "compat_tools"
  {
    "$NAME" // Internal name of this tool
    {
      "install_path" "."
      "display_name" "Proton Experimental 11.0-20261027b (self-built TZ fix)"
      "from_oslist"  "windows"
      "to_oslist"    "linux"
    }
  }
}
EOF
# Mark the tool as modified in Proton's log header; Proton reads this file only for logging.
echo "$(echo "$WANT_VERSION" | cut -d' ' -f1) experimental-11.0-20261027b-tzfix-x86_64" > "$DEST/version"
cp "$HERE/patch/tzspecific-ex.patch" "$DEST/tzspecific-ex.patch"

# 6. Final check of what was installed.
(cd "$DEST/files/lib/wine" && sed 's#  dlls/#  #' "$HERE/SHA256SUMS" | sha256sum -c --quiet) \
    || die "installed DLLs do not match SHA256SUMS"
trap - EXIT

echo
echo "Done: $DEST"
echo "Next: restart Steam, then ArcheAge Chronicles > Properties > Compatibility >"
echo "      'Force the use of a specific Steam Play compatibility tool' >"
echo "      'Proton Experimental 11.0-20261027b (self-built TZ fix)'."
echo "To remove: select another tool for the game, then delete $DEST"
