# Notice: provenance, credits, and licensing

This file states what this package contains, where each part came from, and what was only consulted.
It is written to be checkable; each claim names its source.

## Who did what

| Part | Who | Basis |
|---|---|---|
| The code change (two new functions, spec exports, a test) | **hiraethi**, [archeage-proton-tzfix](https://github.com/hiraethi/archeage-proton-tzfix), file `tzspecific-ex.patch` | Their repository. Their README states that AI assistance was used for the patch, as ours states for this package |
| The first working package for this error, its install approach (copy of Proton with four DLLs replaced), and the description of the cause | **hiraethi** | Their repository, created 2026-11-04, before this one |
| Reading that patch line by line, applying it to Valve's Wine source, building the DLLs from source for Proton Experimental so they can be checked rather than trusted, verifying, testing | **Apolyth**, with Claude (Anthropic) as AI assistant | This package; steps in [build/README.md](build/README.md) and [CHECKS.md](CHECKS.md) |
| `install.sh` | **hiraethi**'s installer is the base; adapted and extended by **Apolyth**, with Claude (Anthropic) as AI assistant | Same flow as their `install.sh`. Added here: exact-version pin, stock-DLL hash check, final hash check, `version` and `compatibilitytool.vdf` handling for Experimental |
| `tools/verify-dlls.py`, the checksum files | **Apolyth**, with Claude (Anthropic) as AI assistant | This package |
| This documentation | **Apolyth**, with Claude (Anthropic) as AI assistant. Its structure and several passages (problem statement, install and uninstall flow, risks) follow hiraethi's README | Compare the two READMEs |
| Wine | The Wine project and its contributors | Source of everything the DLLs are built from |
| Valve's Wine fork and Proton | Valve Corporation and contributors | Source commit used: `ValveSoftware/wine` `7b3ceaf8644bb5d57140903e12897efac69be16a` |

Apolyth did **not** write the patch and this package does not claim so.

The binaries in `dlls/` were built by Apolyth's build from the patch above. They were not taken from
anyone else's repository. Other projects' prebuilt DLLs were examined for comparison only and are not included.
This is not a judgment on them; we could not match any prebuilt binary to its source, so we built our own.

## What was consulted but not used

Credit for diagnosis belongs to the people who reported and investigated the failure in
[ValveSoftware/Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337). No code from them is in this package.

- **mateuscamp** opened the issue and analysed a `PROTON_LOG=1` log, narrowing where the dialog originates.
- **pedmrs**, **Phototonic**, **Colten61**, **reshdesu** and **kevinkirchhof** reproduced it on other Proton builds and
  distributions, and several of them checked the export tables. reshdesu showed that forwarding the `kernel32` export to the
  `kernelbase` stub is not sufficient; Colten61 pointed out the commented-out `kernel32.spec` line and the `kernelbase` stub;
  kevinkirchhof checked the export tables of several Proton builds with `winedump`.
- **souzomain** (Vinicius Morais) posted a patch for Wine on the issue on 2026-11-04 20:31 UTC
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6641383405)), independent of hiraethi's
  (posted earlier that day). It is the basis of the upstream change below. Not used or examined here.
- **gofman** (Paul Gofman) reworked souzomain's patch. The commit is in Valve's bleeding-edge Wine branch:
  [`e893f50`](https://github.com/ValveSoftware/wine/commit/e893f50187da44b919c6655e880905242076e283), 2026-11-07 00:02 UTC,
  message "Based on a patch by Vinicius Morais (Souzomain)". It was also submitted to Wine as
  [MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616) (opened 2026-11-06, still open when checked), and
  announced on the issue ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6699601487)). Not used here.
- **DeconWhite** confirmed on 2026-11-07 07:38 UTC, about seven hours after gofman's comment, that Proton Experimental's
  bleeding-edge beta works, and posted the steps Method 1 in the README uses
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6704008505)). They did not write the patch.
  No code from them is in this package.
- **inhibitor181** pointed to a workaround. Not used or examined here.
- **hiraethi** posted in the issue that the patch gets the game past the dialog and that "XIGNCODE starts up too" on proton-cachyos, and linked their repository.
- **caostra**, [archeage-proton-tz-fix](https://github.com/caostra/archeage-proton-tz-fix): an independent approach that
  byte-patches `kernel32.dll` to forward the new exports to the non-Ex functions. It was read for comparison; no code,
  data or method from it is used.
- A Wine merge request, [MR 4851](https://gitlab.winehq.org/wine/wine/-/merge_requests/4851), was linked in the issue as an
  older attempt. It was not used.

## Licensing

- **Wine** is licensed under the GNU Lesser General Public License, version 2.1 or later. The DLLs here are built
  from Wine source and carry the same license. The full text is in `LICENSE` (the `COPYING.LIB` shipped in the Wine tree).
- **The patch** modifies Wine files, so it is a derivative of LGPL code. hiraethi's repository distributes it with the
  LGPL 2.1 text and states that the DLLs built from it are LGPL 2.1 or later. It does not separately state a license for
  the patch file itself. This is not legal advice.
- **Corresponding source** for the DLLs in `dlls/` is: Valve's Wine at commit
  `7b3ceaf8644bb5d57140903e12897efac69be16a`
  (<https://github.com/ValveSoftware/wine/tree/7b3ceaf8644bb5d57140903e12897efac69be16a>) plus
  `patch/tzspecific-ex.patch`, built as described in `build/README.md`.
- **Modification notice (LGPL):** these DLLs are modified versions of Wine's `kernel32.dll` and `kernelbase.dll`. The
  modifications are exactly the contents of `patch/tzspecific-ex.patch`.
- **Proton** is by Valve and is not redistributed here. The installer copies the Proton Experimental that is
  already on the user's machine. Proton ships under licenses specific to its components; see the `LICENSE` files in
  Valve's Proton repository and in the installed tool.
- **Build toolchain** (mingw-w64 GCC from Fedora packages) was used to compile; it is not part of this package.
- `tools/` and the documentation are (c) 2026 Apolyth, offered under LGPL-2.1-or-later. `install.sh` is adapted from hiraethi's installer. Their repository states a license for the DLLs (LGPL 2.1 or later) but not separately for the installer, and we have not asked them. This is not legal advice.
- "ArcheAge" is a trademark of its owners. This project is not provided or endorsed by XLGAMES, Valve, or the Wine project.

## Known limits of these claims

- The Wine commit pin is **inferred** from the Proton Experimental build timestamp and commit messages. No build manifest
  records it. Checks consistent with it are listed in `build/README.md`.
- GCC 16.2.1 was used to build; Valve's stock DLLs show GCC 14. The DLLs are therefore not byte-identical to what
  Valve would build from the same source, and are not claimed to be.
- hiraethi said in the Proton issue (not in their repository) that they could not verify behaviour for unknown time-zone names or
  `DynamicDaylightTimeDisabled` against real Windows. That remains unverified here.
