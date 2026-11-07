# Rebuilding the DLLs

This documents the steps that produced the DLLs in `../dlls/`. It was written from the session that built them;
it is a recipe, **not** a single script that has been re-run end to end, and the build is not claimed to be
bit-for-bit reproducible.

## Inputs

- Valve Wine commit `7b3ceaf8644bb5d57140903e12897efac69be16a`, the `wine` submodule pin of
  `ValveSoftware/Proton` commit `871b0bf140`. That commit was chosen because Proton Experimental
  `11.0-20261027b` has build timestamp 2026-10-29 19:23:16 UTC (first field of its `version` file),
  three minutes after it. This is an inference, not a recorded fact.
- `../patch/tzspecific-ex.patch` (sha256 `4fa6e4d1c38242463f0d3667d32cc78084de900db594aca4f97936fd9f24d716`).
  It applies to Valve's tree with line offsets only (no manual merge needed).

## Environment used

Rootless `podman`, image `registry.fedoraproject.org/fedora:44`, packages:
`gcc make bison flex patch tar gzip diffutils findutils which perl-interpreter python3 autoconf automake
mingw32-gcc mingw64-gcc mingw32-binutils mingw64-binutils` (mingw GCC 16.2.1). The `gettext` tools (`msgfmt`) must
be present and enabled.

Note: on a slow link, `dnf` can stall fetching zchunk metadata as tens of thousands of range requests.
Adding `--setopt=zchunk=false` fixed that.

## Steps

```sh
# 1. Fetch and unpack the source (any way that yields that exact commit)
tar -xzf wine-7b3ceaf.tar.gz --strip-components=1 -C src      # from https://github.com/ValveSoftware/wine, commit above

# 2. Apply the patch
cd src && git apply -p1 ../patch/tzspecific-ex.patch          # or: patch -p1 < ...

# 3. Valve's tree does not include the generated configure script
./autogen.sh

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

## Checks that were run on the result

- `.rsrc` section sizes equal stock for all four DLLs (this is what exposed the missing-translations mistake).
- Exports: `kernel32` = stock plus `SystemTimeToTzSpecificLocalTimeEx` and `TzSpecificLocalTimeToSystemTimeEx`;
  `kernelbase` = stock. Imports: only `kernelbase.dll` and `ntdll.dll`; `kernel32` gains the two matching imports.
- Function-by-function comparison against stock (64-bit only) is noisy: about 86% of `kernel32` and 66% of `kernelbase`
  functions are identical after normalization, because stock was built with GCC 14 and this with GCC 16.2.1.
  Functions present only in stock are either Wine-generated stubs and relay entries (their numbering shifts with the
  two added exports) or static functions that exist in the source and that this compiler inlined.
- Wine's `kernel32_test.exe time`, run under a copy of Proton Experimental with these DLLs in a new prefix, in both
  architectures: 2,368 tests, 0 failures, 0 skipped. The same binary against unpatched Proton Experimental:
  1 failure ("... not available"). Console output of Windows programs is dropped by `proton run`, so the test was
  run as `proton run cmd /c "kernel32_test64.exe time > out.txt 2>&1"` with `WINETEST_DEBUG=2 WINETEST_REPORT_SUCCESS=1`.

## For a different Proton build

1. Find the Wine commit: in `ValveSoftware/Proton`, read the `wine` submodule pin at the commit the build came from.
   Bleeding-edge builds name it in the version string (for example `w7b3cea`); regular Experimental does not.
2. Repeat the steps above on that commit. If the patch does not apply cleanly, do not force it; the surrounding
   code has changed and the patch needs review.
3. Compare section sizes, exports and imports against that build's stock DLLs before using the result.
