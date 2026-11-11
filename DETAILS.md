> Older long-form README, kept for reference. The short guide is [README.md](README.md); where they differ, README.md is current.

# ArcheAge Chronicles on Linux: fix for the SystemTimeToTzSpecificLocalTimeEx launch error

## Start here

The short, current guide is [README.md](README.md). This page keeps the longer explanation of the same fix.

Valve's `bleeding-edge` beta of Proton Experimental also carries an earlier version of the upstream change: **gofman**
reworked a patch by **souzomain**
([`e893f50`](https://github.com/ValveSoftware/wine/commit/e893f50187da44b919c6655e880905242076e283), submitted to Wine as
[MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616), last reported open on 2026-11-10). It did not work on
our test machine, so we do not recommend it here, and earlier versions of this page that gave its steps were changed. A
permanent fix is waiting on that merge request.

---

## A patched copy of Proton Experimental

> **Scope: Proton Experimental `11.0-20261105c` (current) or `11.0-20261027b` (older; not tested since 2026-11-10).** The DLLs
> here are built for those exact builds, and the installer refuses anything else. They are **not** for GE-Proton, proton-cachyos, Proton 11.0, Proton Hotfix or any other Proton.
> For proton-cachyos 11.0-20261015, use [hiraethi's package](https://github.com/hiraethi/archeage-proton-tzfix).

The code change is **hiraethi's**: they wrote the patch and published the first Wine source patch
we found ([archeage-proton-tzfix](https://github.com/hiraethi/archeage-proton-tzfix), for proton-cachyos). This package is
the same patch, unmodified, built from Valve's Wine source for Proton Experimental, so Experimental users can use it
without prebuilt third-party binaries. See [Credits](#credits) and [NOTICE.md](NOTICE.md).

ArcheAge Chronicles stops at launch under Proton with a missing-function error. This is an unofficial
stopgap that gets it past that point, built so that anyone can check what it does. It is community work,
offered freely, until Valve or another Proton build ships a proper fix.

## The problem

The game (Steam appid 3218230) stops with this dialog:

> The procedure entry point SystemTimeToTzSpecificLocalTimeEx could not be located in the dynamic link library KERNEL32.dll.

Wine, and every stable Proton built on it (Proton Experimental's bleeding-edge beta excepted), only stubs `SystemTimeToTzSpecificLocalTimeEx` and
`TzSpecificLocalTimeToSystemTimeEx` in `kernelbase.dll` and does not export them from `kernel32.dll`; the game imports
them from `kernel32.dll`. We confirmed this on the Proton builds listed in [CHECKS.md](CHECKS.md), but it is described in
[hiraethi's README](https://github.com/hiraethi/archeage-proton-tzfix) and in the upstream report:
[ValveSoftware/Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337).

## What this is

An installer that makes a **copy of your own Proton Experimental** with four DLLs replaced
(`kernel32.dll` and `kernelbase.dll`, 64-bit and 32-bit). Your original Proton is not modified, and this
package does not contain or redistribute Proton.

The DLLs were built by us from Valve's Wine source plus hiraethi's patch, which implements the two missing functions.
The source commit, the patch, the toolchain and the build steps are all published here. The approach (a copy of
Proton with only the affected DLLs replaced, installed as a separate Steam compatibility tool) was also used by earlier
workarounds (see [NOTICE.md](NOTICE.md)); `install.sh` is adapted from hiraethi's installer (same flow: checksum check, copy of Proton, four DLLs swapped, cleanup on failure).
The README's structure (problem, requirements, install, uninstall, risks, build) also follows theirs.

### How this differs from hiraethi's package

| | hiraethi's | This package |
|---|---|---|
| Target Proton | proton-cachyos 11.0-20261015 | Proton Experimental 11.0-20261105c and 11.0-20261027b |
| Patch | `tzspecific-ex.patch` (theirs) | The same patch, unmodified (identical SHA-256) |
| Installer | Copies your proton-cachyos, swaps four DLLs | Adapted from theirs; adds exact-version matching against per-build folders, a check that the stock DLLs are unmodified, and a final hash check |
| DLLs | Prebuilt by them, shipped in their repo | Built by us from Valve's Wine source; steps, pinned commit and hashes published |
| Checks | Not covered here | Patch read in full; DLL exports, imports and strings compared with stock ([CHECKS.md](CHECKS.md)) |

Why we rebuilt instead of reusing their DLLs: a replacement `kernel32.dll` is hard to vet from the compiled file alone, and
the strongest check we have is source we have read. We could not match their DLLs to the source (different toolchain and target
Proton), so we built our own. That is a limit of what we could verify. We found nothing wrong with their patch, we only compared
their DLLs at header level ([CHECKS.md](CHECKS.md)), and this is not a claim that their package is unsafe. If you run proton-cachyos, theirs is the one built for it.

**Supported builds, exactly:** Proton Experimental `experimental-11.0-20261105c` (its `version` file reads
`1793987684 experimental-11.0-20261105c-x86_64`) and `experimental-11.0-20261027b` (`1793301796 experimental-11.0-20261027b-x86_64`).
The installer picks the matching folder in `builds/` and refuses any other build.
Do not edit version strings to force it. For a different build, rebuild the DLLs from the matching Wine commit;
see [build/README.md](build/README.md).

## Install

1. Install **Proton Experimental** from Steam (Library > Tools) and make sure it is the supported build.
2. Run:

   ```sh
   git clone https://github.com/Apolyth-Official/archeage-chronicles-linux-tzfix
   cd archeage-chronicles-linux-tzfix
   ./install.sh
   ```

3. Restart Steam. Open ArcheAge Chronicles > Properties > Compatibility, enable
   "Force the use of a specific Steam Play compatibility tool", and select
   the tool the installer names, for example **Proton Experimental 11.0-20261105c (self-built TZ fix)**.

The installer checks that the package DLLs match `SHA256SUMS`, that your Proton Experimental is the exact
supported build, and that the four stock DLLs it will replace match `STOCK-SHA256SUMS`. It makes no network
connections and removes its partial output if anything fails. `SHA256SUMS` ships with the DLLs, so it catches
corruption, not tampering. To avoid trusting our binaries, rebuild them yourself.

## Remove or roll back

Select a different compatibility tool for the game, then delete
`~/.local/share/Steam/compatibilitytools.d/proton-experimental-tzfix`. Proton refreshes the prefix DLLs on the
next launch. This tool does not receive Steam's Proton updates.

## What was checked

The patch is used unmodified. We built the DLLs ourselves from Valve's source and ran these checks: the patch was read in
full; the DLLs' exports and imports differ from stock Proton only by the two new functions; the strings that differ from
stock contain no URLs, addresses, shell commands or networking calls; the installer makes no network connections; and
Wine's own `kernel32` time test passes (2,368 tests, 0 failures, 0 skipped) where unpatched Proton fails it.

You can check the headers yourself with `python3 -I tools/verify-dlls.py`, or rebuild from source.

These are sanity checks by Apolyth with an AI assistant, **not an independent security audit**, and they cover only what we
added, not Wine or Proton as a whole. [CHECKS.md](CHECKS.md) lists what was and was not examined, other approaches seen,
and what could still be wrong.

## What has been tested

Tested on Fedora 44 (KDE Plasma, Wayland), NVIDIA RTX 5070, kernel 7.2.15 (the Wine test was run on 2026-11-06, on `20261027b`):

- Wine's `kernel32` time test in a throwaway prefix, patched tool and unpatched Proton, as described above.
- Apolyth reports that the game launches and works with the patched tool for `20261105c` (2026-11-11). The copy for `20261027b`
  worked until 2026-11-10 and has not been tested since.

**Not recorded:** what was played and for how long, and whether server login and character play were tried.
**Not tested:** other distributions, Steam Deck, other GPUs, long sessions.

## Risks

- **Anti-cheat.** The game uses XIGNCODE3. hiraethi reported in the Proton issue that with their build the game launches
  and XIGNCODE "starts up". Starting is not the same as not flagging, and nobody here has measured whether it reacts to a
  modified `kernel32.dll`; no statement from the developer on the subject was found. Stock Wine's DLLs already are not
  Microsoft's, but that is not evidence either way. Use at your own risk, and remember that any account you log in
  with is exposed to whatever it does.
- **Unsupported.** Linux and Steam Deck are not officially supported by the game. This project is not provided or
  endorsed by XLGAMES, Valve, or the Wine project.
- **Time-zone edge cases.** For unknown time-zone key names and `DynamicDaylightTimeDisabled`, the patch falls back
  to the static rules in the structure. Behaviour on real Windows for those inputs was not verified.
- **Stopgap.** When Valve, GE-Proton, or another build ships these functions, use that instead. A permanent fix is waiting on
  [Wine MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616). Proton Experimental's bleeding-edge beta carries
  an earlier version of it, which did not work on our test machine.

## Credits

- **souzomain** (Vinicius Morais) wrote the patch behind the bleeding-edge fix
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6641383405)).
- **gofman** (Paul Gofman) reworked it (added tests, simplified it), committed it to Valve's bleeding-edge Wine and
  submitted it to Wine ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6699601487)).
- **DeconWhite** confirmed that the bleeding-edge beta works and posted the bleeding-edge steps that earlier versions of this page gave
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6704008505)).

  None of their code is part of this package.
- **hiraethi** wrote the patch and published the first Wine source patch we found
  ([archeage-proton-tzfix](https://github.com/hiraethi/archeage-proton-tzfix), repository created 2026-11-04 09:50 UTC). The patch
  in this package is theirs, and `install.sh` is adapted from their installer. Without it there would be nothing here.
- **Online** (Steam forum, 2026-11-03 23:33 UTC), **Zerk**, **Hexvon**, **codecorsair** and **caostra** published earlier
  workarounds that copy Proton and patch `kernel32.dll`. None of their code or binaries is used here. See
  [README.md](README.md#credits) and [NOTICE.md](NOTICE.md).
- **The people on [ValveSoftware/Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337)** found and narrowed
  the cause: mateuscamp, pedmrs, Phototonic, Colten61, reshdesu, kevinkirchhof and others.
- **The Wine project and Valve** wrote everything these DLLs are built from.
- **Apolyth** built the DLLs from source for each supported Proton Experimental build with the patch unmodified (including the
  rebuild for `20261105c`), ran the checks listed in [CHECKS.md](CHECKS.md), adapted the installer to pick the matching build,
  wrote the rebuild script, and wrote the documentation. The source commits, build steps and hashes are published so anyone
  can repeat it.
- **Claude (Anthropic)** did much of the hands-on work under Apolyth's direction: research, building, checks and
  writing.

[NOTICE.md](NOTICE.md) has the full account: who did what, what was only consulted, and the licensing.

## License

`LICENSE` is the GNU LGPL 2.1 and covers the DLLs and the patch. `tools/` and the documentation are
(c) 2026 Apolyth, offered under the same LGPL-2.1-or-later. `install.sh` is adapted from hiraethi's installer, which has no
separate license statement; see [NOTICE.md](NOTICE.md).
