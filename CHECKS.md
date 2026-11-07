# Build checks

This page lists the checks run on the DLLs in this package, what they found, and what was **not** checked.
The DLLs are hiraethi's patch, unmodified, built from Valve's Wine source for Proton Experimental. The checks were run
by Apolyth with an AI assistant (Claude, Anthropic). They are sanity checks on the build, not an independent security
audit, and nobody outside this project has looked at them yet. Please check them, and tell us where they are wrong.

## What was looked at

Everything this package adds or changes:

| Item | How it was checked |
|---|---|
| `patch/tzspecific-ex.patch` (196 lines, four files) | Read in full, line by line, before anything was built. Applies to Valve's tree with line offsets only. |
| `dlls/` (four DLLs) | Built by us from that source. Then compared to stock Proton, scanned, disassembled where new, and run under Wine's own tests. Details below. |
| `install.sh` | Written for this package, read back, and run, including its refusal paths. |
| `tools/verify-dlls.py` | Tested on the real Proton and with deliberately wrong inputs to confirm it fails when it should. |

## What was not checked

- Wine and Proton as a whole. Valve's tree at that commit was not examined beyond the files the patch touches.
- The Fedora container image and the mingw compiler packages used to build.
- The game, the XIGNCODE3 anti-cheat, and Steam.

## Specific checks

These are the specific, checkable statements. Each names how it was established.

1. **The only change to Valve's source is the patch.** It adds two exports and two functions that convert
   times between time zones, plus a test. The functions call `GetTimeZoneInformationForYear`,
   `RtlQueryTimeZoneInformation` and the existing non-Ex conversion functions. They open no files, sockets or
   processes. *(Source read in full.)*
2. **The binaries are ours.** They were compiled by us from public source plus that patch. No third party's
   binaries are included. *(Build steps in `build/README.md`.)*
3. **The compiled new functions match the source.** In both our 64-bit and 32-bit `kernelbase.dll`, the two new
   functions are 172 and 88 instructions (64-bit) and 138 and 96 (32-bit). They call only the time-zone routines
   above and Wine's debug logger (the patch's `TRACE`), and contain no `syscall`, `sysenter` or `int` instructions.
   *(`objdump -d`, run on our DLLs.)*
4. **Exports.** `kernel32.dll` gains exactly `SystemTimeToTzSpecificLocalTimeEx` and
   `TzSpecificLocalTimeToSystemTimeEx`. `kernelbase.dll` exports are unchanged. *(Header comparison, all four DLLs.)*
5. **Imports.** Only `kernelbase.dll` and `ntdll.dll` appear. The only new imports are the two new functions in
   `kernel32.dll`. No networking, process or registry libraries are imported. *(Header comparison.)*
6. **Strings.** Our DLLs contain 447, 575, 561 and 1,106 strings (x86_64 kernel32, x86_64 kernelbase, i386 kernel32,
   i386 kernelbase) that stock does not. None matches patterns for URLs, IP addresses, domains, shell commands,
   networking, remote-thread or process-memory APIs, or any reference to the game or its anti-cheat. *(Scan with `strings`.)*
7. **The installer.** It makes no network connections. It checks hashes, copies your Proton, replaces four DLLs,
   and writes three small files. It refuses unsupported builds and cleans up after a failure. *(Run, including a
   wrong version, tampered stock DLLs, a missing Proton, and a repeat install.)*
8. **Behaviour.** Wine's own `kernel32` time test, run under the patched tool in a fresh prefix, passes:
   2,368 tests, 0 failures, 0 skipped, in both architectures. The same test fails on unpatched Proton with
   `... not available`. *(Ten assertions cover the new functions.)*

## What this cannot show

- **Static checks read headers and strings. They cannot prove what millions of bytes of compiled code never do.**
  Our strongest control is that the DLLs were built from source we read. That covers the patch. The remaining
  code is Wine's and Valve's own, which we did not re-examine.
- **Not every function was compared.** About 86% of `kernel32` and 66% of `kernelbase` functions (64-bit) are
  identical to stock after normalising addresses. The rest differ in instruction count because stock was built with
  GCC 14 and we used GCC 16.2.1. The functions present only in stock were traced to Wine-generated entries or to
  static functions the compiler inlined. We did not verify each differing function one by one.
- **No network capture.** We did not record network traffic from the game or from Proton running these DLLs.
- **The Wine commit is inferred** from the Proton build time and commit messages, not from a build record.
- **The compiler and container are trusted.** If they were compromised, our checks might not notice.
- **The game.** Beyond launching, and the one reported launch, nothing about gameplay, login or stability is verified.

## Other approaches seen

We looked for a way to avoid replacing `kernel32.dll` and found none. The function is missing from the Proton builds
we could check: Proton Experimental, Proton 11.0, Proton Hotfix, GE-Proton11-11 and DW-Proton 11.0-14 (checked
directly), plus Proton 10.0, 11.0-2e and GE-Proton11-12 (reported in the upstream issue).

- *"Switch to Experimental or GE-Proton 9-16+"* (advice on a fan wiki): contradicted by the issue thread and by our checks.
- *Forwarding the `kernel32` export to the `kernelbase` stub*: reported by reshdesu in the issue as insufficient.
- *caostra's byte patch to one bleeding-edge build*: forwards to the non-Ex functions and states it is not a full
  implementation. Not used.
- *hiraethi's prebuilt DLLs*: not used. They target proton-cachyos, a different Proton, and we could not match any
  prebuilt binary to its source (different toolchain), so we used their patch text only and built our own.
- *Waiting for an official fix*: always the lowest-risk choice. This package is a stopgap for people who cannot wait.

We do not claim this is the best possible fix. We claim it is the one we could build ourselves and check.

## Comparison with hiraethi's package (header level, 2026-11-06)

After the fact, we compared their prebuilt DLLs with ours using the same header-only tools: exports, imported DLLs, and a scan
for URLs, IP addresses and shell command strings. Their DLLs import only `kernelbase.dll` and `ntdll.dll`, and the scan found
nothing. Their `kernel32.dll` exports one name ours does not, `IsNativeVhdBoot`, most likely because proton-cachyos's Wine is
a different tree from Valve's; we did not confirm that. This is not a check of their binaries beyond that: it has the same limits as
the checks above, and we did not disassemble them.

## Check it yourself

```sh
python3 -I tools/verify-dlls.py        # header-level checks against your own Proton Experimental
less patch/tzspecific-ex.patch         # the entire code change, 196 lines
```

Or rebuild the DLLs from source (`build/README.md`) and compare them with `dlls/`. The build is not claimed to be
bit-for-bit reproducible, so compare exports, imports and test results, not hashes.

## Risks

- **Anti-cheat.** The game uses XIGNCODE3. Whether it reacts to a modified `kernel32.dll` has not been measured.
- **Unsupported.** Linux and Steam Deck are not officially supported by the game.
- **Edge cases.** Unknown time-zone key names and `DynamicDaylightTimeDisabled` fall back to static rules in the
  structure; behaviour on real Windows for those inputs was not verified.
- **One build only.** The DLLs match one exact Proton Experimental build and the installer enforces that.
- **Stopgap.** This tool will not receive Steam's Proton updates. Prefer an official fix once one exists.

## Corrections

If you find an error in this page, the patch, the build or the claims, please open an issue. A correction is worth more
here than a compliment.
