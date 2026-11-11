# Rebuilding the DLLs

The DLLs in `../builds/<build>/dlls/` are built from Valve's Wine source plus `../patch/tzspecific-ex.patch`
(hiraethi's patch, unmodified). `build.sh` in this folder runs the whole recipe in a container.

## Builds

| Proton Experimental | Proton commit (inferred) | Valve Wine commit | Folder |
|---|---|---|---|
| `11.0-20261027b` | `871b0bf140` | `7b3ceaf8644bb5d57140903e12897efac69be16a` | `builds/20261027b` |
| `11.0-20261105c` | `0764d2920a` | `e8ca5806eec488f5916e83d655ffc5349b6b1702` | `builds/20261105c` |

The Proton commit is **inferred**, not recorded anywhere. The first field of the `version` file is the build time:
`20261027b` is 2026-10-29 19:23:16 UTC, three minutes after its commit; `20261105c` is 2026-11-06 17:54:44 UTC,
two and a half minutes after `0764d2920a` (committed 17:52:09 UTC). For `20261105c`, the previous Proton commit
(`9e870b9b7d`, "update wine") pins the same Wine commit, so the choice between them does not matter there.

The patch (sha256 `4fa6e4d1c38242463f0d3667d32cc78084de900db594aca4f97936fd9f24d716`) applied to both Wine commits with
line offsets only and no manual merge. For `20261105c` the offsets were between -4 and -62 lines depending on the file.

## For a new Proton Experimental build

Steam updates Experimental on its own, and the installer refuses a build that has no folder in `builds/`.

1. Read your build's timestamp: `head -n1 "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/version"`.
   Convert the first field: `date -u -d @<number>`.
2. In `ValveSoftware/Proton`, find the last commit on the Experimental branch (`experimental_11.0` for these builds)
   before that time, a few minutes earlier. With the GitHub CLI:
   `gh api 'repos/ValveSoftware/Proton/commits?sha=experimental_11.0&since=<ISO time>&until=<ISO time>'`
3. Read the Wine pin at that commit: `gh api 'repos/ValveSoftware/Proton/contents/wine?ref=<proton-commit>' --jq .sha`
4. Build: `build/build.sh <wine-commit> <new-empty-output-dir>`. If the patch does not apply cleanly, stop. The surrounding
   code has changed and the patch needs review; do not force it.
5. Add `builds/<build>/` with `VERSION` (your `version` file's first line), `dlls/` from the output, `SHA256SUMS` (the
   output's `SHA256SUMS`), and `STOCK-SHA256SUMS`:

   ```sh
   cd "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/files/lib/wine"
   sha256sum i386-windows/kernel32.dll i386-windows/kernelbase.dll x86_64-windows/kernel32.dll x86_64-windows/kernelbase.dll > STOCK-SHA256SUMS
   ```

6. Run `python3 -I tools/verify-dlls.py`, install with `./install.sh`, and launch the game before publishing the build.

## Environment used

Rootless `podman`, image `registry.fedoraproject.org/fedora:44`, packages:
`gcc make bison flex patch tar gzip diffutils findutils which perl-interpreter python3 autoconf automake
mingw32-gcc mingw64-gcc mingw32-binutils mingw64-binutils gettext` (mingw GCC 16.2.1). The `gettext` tools (`msgfmt`)
must be present and enabled.

Note: on a slow link, `dnf` can stall fetching zchunk metadata as tens of thousands of range requests.
`build.sh` passes `--setopt=zchunk=false`, which fixed that.

## Steps (what `build.sh` does)

```sh
# 1. Fetch and unpack the source at that exact commit
tar -xzf wine-<commit>.tar.gz --strip-components=1 -C src     # from https://github.com/ValveSoftware/wine

# 2. Apply the patch
patch -p1 -d src -i patch/tzspecific-ex.patch

# 3. Valve's tree does not include the generated configure script
cd src && ./autogen.sh

# 4. Configure for both PE architectures; the optional host libraries are not needed for these DLLs.
#    Do NOT pass --without-gettext: the resource sections then lack translations (a fraction of stock size).
mkdir ../build && cd ../build
../src/configure --enable-archs=i386,x86_64 \
  --without-x --without-freetype --without-fontconfig --without-wayland --without-vulkan --without-opengl \
  --without-sdl --without-pulse --without-alsa --without-oss --without-cups --without-dbus --without-gnutls \
  --without-gstreamer --without-krb5 --without-gssapi --without-pcsclite --without-udev --without-usb \
  --without-v4l2 --without-ffmpeg --without-capi --without-opencl --without-pcap --without-sane \
  --without-gphoto --without-unwind --without-inotify --without-netapi --without-coreaudio

# 5. Build only the four DLLs (and, optionally, the kernel32 test binaries)
make -j"$(nproc)" \
  dlls/kernelbase/x86_64-windows/kernelbase.dll dlls/kernel32/x86_64-windows/kernel32.dll \
  dlls/kernelbase/i386-windows/kernelbase.dll   dlls/kernel32/i386-windows/kernel32.dll \
  dlls/kernel32/tests/x86_64-windows/kernel32_test.exe dlls/kernel32/tests/i386-windows/kernel32_test.exe

# 6. Strip debug info only. Stock Proton keeps the COFF symbol table, so do not use a full strip.
x86_64-w64-mingw32-strip --strip-debug dlls/*/x86_64-windows/kernel32.dll dlls/*/x86_64-windows/kernelbase.dll
i686-w64-mingw32-strip   --strip-debug dlls/*/i386-windows/kernel32.dll   dlls/*/i386-windows/kernelbase.dll
```

## Reproducibility

The `20261027b` DLLs were built in the session these steps were first written from; the steps were not re-run end to end
afterwards. The `20261105c` DLLs were built with the same commands in a script, and then `build.sh` was run from scratch on
the same commit as a check. The two results are the same size, and differ in four bytes
per DLL: the PE header's `TimeDateStamp` and `CheckSum` fields (verified by parsing the headers). Exports, imports and
section sizes are identical. That is one comparison on one machine with one container image; it is not a guarantee that
other machines or toolchain versions produce the same bytes.

## Checks that were run on the result

- `.rsrc` section sizes equal stock for all four DLLs (this is what exposed the missing-translations mistake; `20261027b`).
- Exports: `kernel32` = stock plus `SystemTimeToTzSpecificLocalTimeEx` and `TzSpecificLocalTimeToSystemTimeEx`;
  `kernelbase` = stock. Imports: only `kernelbase.dll` and `ntdll.dll`; `kernel32` gains the two matching imports.
  `tools/verify-dlls.py` runs this for whichever build matches your Proton (all checks passed for both).
- Function-by-function comparison against stock (64-bit only, `20261027b`) is noisy: about 86% of `kernel32` and 66% of
  `kernelbase` functions are identical after normalization, because stock was built with GCC 14 and this with GCC 16.2.1.
  Functions present only in stock are either Wine-generated stubs and relay entries (their numbering shifts with the
  two added exports) or static functions that exist in the source and that this compiler inlined.
- Wine's `kernel32_test.exe time`, run under a copy of Proton Experimental `20261027b` with these DLLs in a new prefix, in
  both architectures: 2,368 tests, 0 failures, 0 skipped. The same binary against unpatched Proton Experimental:
  1 failure ("... not available"). Console output of Windows programs is dropped by `proton run`, so the test was
  run as `proton run cmd /c "kernel32_test64.exe time > out.txt 2>&1"` with `WINETEST_DEBUG=2 WINETEST_REPORT_SUCCESS=1`.
  **Not re-run for `20261105c`.**
