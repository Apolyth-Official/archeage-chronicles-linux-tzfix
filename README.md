# ArcheAge Chronicles on Linux: fix for the SystemTimeToTzSpecificLocalTimeEx launch error

The game (Steam app 3218230) stops at launch with:

> The procedure entry point SystemTimeToTzSpecificLocalTimeEx could not be located in the dynamic link library KERNEL32.dll.

Wine does not export two time-zone functions from `kernel32.dll`. Upstream report:
[ValveSoftware/Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337).

## Status

- **This is a workaround, not a permanent fix.** We are waiting for a permanent solution to ship from
  [Wine MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616). The last comment on Proton#10337
  (2026-11-10) says the same. We could not load the merge request page to check its current state. Once a fix reaches Proton,
  this package is no longer needed.
- **The DLLs match exact Proton Experimental builds.** Steam updates Experimental on its own, and the installer refuses any
  build it has no DLLs for. Supported builds:

  | Proton Experimental build | Folder | Status |
  |---|---|---|
  | `11.0-20261105c` (current as of 2026-11-11) | `builds/20261105c` | Apolyth reports the game launches and works with it (2026-11-11) |
  | `11.0-20261027b` | `builds/20261027b` | Older. The copy made for it worked for Apolyth until 2026-11-10, then stopped (its files had been overwritten; see below). Not tested since. Steam has since updated Experimental, so most people can no longer use it. |

  When Experimental moves to a newer build, an already installed copy keeps working (it is a copy). Only a new install
  is refused until DLLs for that build are added. [build/README.md](build/README.md) shows how to make them.
- **Valve's `bleeding-edge` beta of Proton Experimental also carries an earlier version of the upstream change.** It did not work
  on our test machine, so this guide does not use it.

## Install: patched copy of Proton Experimental

Your own Proton is not modified. On proton-cachyos, use [hiraethi's package](https://github.com/hiraethi/archeage-proton-tzfix).

1. Proton Experimental must be on its default branch (Steam > Library > Tools > Proton Experimental > Properties >
   Game Versions & Betas > **None**). Close the game.
2. Check your build. The output must be one of the two supported `version` lines in the table above
   (`1793987684 experimental-11.0-20261105c-x86_64` or `1793301796 experimental-11.0-20261027b-x86_64`):

   ```sh
   head -n1 "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/version"
   ```

3. Installed before? Remove the old copy first (the installer will not overwrite it):

   ```sh
   rm -rf ~/.local/share/Steam/compatibilitytools.d/proton-experimental-tzfix
   ```

4. Download this repo and run the installer. It picks the folder in `builds/` that matches your build:

   ```sh
   git clone https://github.com/Apolyth-Official/archeage-chronicles-linux-tzfix
   cd archeage-chronicles-linux-tzfix
   ./install.sh
   ```

5. Fully quit and restart Steam (it only reads installed tools at startup). **ArcheAge Chronicles** > Properties >
   Compatibility > force the tool the installer names, for example
   **Proton Experimental 11.0-20261105c (self-built TZ fix)**.

Check the install. Exactly four files should be listed (`kernel32.dll` and `kernelbase.dll`, 64-bit and 32-bit):

```sh
S=~/.local/share/Steam
for a in x86_64-windows i386-windows; do
  diff -rq "$S/compatibilitytools.d/proton-experimental-tzfix/files/lib/wine/$a" "$S/steamapps/common/Proton - Experimental/files/lib/wine/$a"
done
```

More than four means the copy was changed after installation. Run this check again if the game stops launching.

- **What we saw:** on our machine the installed copy for `20261027b` was modified twice. On 2026-11-10 at 19:05, 197 of its
  Wine DLLs were replaced with files byte-identical to ones in GE-Proton10-34. On 2026-11-11 at 09:21, another 144 were
  replaced with files byte-identical to ones in GE-Proton11-11. Both are installed on the same machine, and the patched
  `kernel32.dll` and `kernelbase.dll` were among the replaced files. After the first change the game exited at once with
  `unimplemented function KERNEL32.dll.RegisterWaitForInputIdle`. An earlier copy (a different incident) showed 581
  differing files and the abort `unimplemented function win32u.NtGdiDdDDIQueryFSEBlock`; we have no timing for that one.
- **What we do not know:** what writes those files. Each of the two overwrites above happened within seconds of a Steam
  start. After reinstalling (for `20261105c`), one Steam restart and one game launch left all 5,604 files of the copy unchanged (checked by hash), even though Steam again
  ran several different Proton builds against the shared `compatdata/0` prefix. That is one cycle, not proof that it cannot
  happen again.
- **If it happens to you:** remove the copy and reinstall (step 3, then step 4).

To remove: pick another tool for the game, then delete the folder in step 3.

## Limits

- **Anti-cheat:** the game uses XIGNCODE3. Nobody here has measured how it reacts to a modified `kernel32.dll`. Use at your own risk.
- **Unofficial:** not provided or endorsed by XLGAMES, Valve, or the Wine project.
- **Tested:** one machine (Fedora 44, KDE Plasma on Wayland, RTX 5070, NVIDIA driver 615.78.08). Not tested: other distros,
  Steam Deck, other GPUs, long sessions.

## Credits

- **[hiraethi](https://github.com/hiraethi/archeage-proton-tzfix)** wrote the Wine source patch used here and published it as the
  first Wine source patch we found (repository created 2026-11-04 09:50 UTC). `install.sh` is adapted from their installer.
- **Apolyth** (with Claude, Anthropic, as AI assistant) built the DLLs from hiraethi's unmodified patch against Valve's Wine
  source for each supported Proton Experimental build, including the rebuild for `20261105c` after Experimental updated
  (the patch applied with line offsets only). Apolyth also adapted the installer to pick the matching build, wrote the rebuild
  script and the checks, found and documented the overwritten-DLL problem above, and wrote this guide.
- **Earlier workarounds**, none of whose code or binaries is used here. We read Online's post and the codecorsair and caostra
  repositories; each copies Proton and patches `kernel32.dll`. We could not read Hexvon's.
  - **Online**, on the [Steam forum](https://steamcommunity.com/app/3218230/discussions/0/571553910742845620/), 2026-11-03 23:33 UTC,
    the earliest we found. **Zerk** reported it working on a patched GE-Proton11-12 about three minutes later.
  - **Hexvon** states that the Discord message linked by inhibitor181 on Proton#10337 (2026-11-03 23:44 UTC) is their GE-Proton
    workaround. We could check the time from the message ID; the server is private, so we could not check who wrote it or what it says.
  - **[codecorsair](https://github.com/codecorsair/archeage-proton-fix)** (repository created 2026-11-04 00:47 UTC) and
    **[caostra](https://github.com/caostra/archeage-proton-tz-fix)** (repository created 2026-11-04 08:26 UTC).
- **souzomain** (Vinicius Morais) wrote the patch behind the upstream change
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6641383405)).
- **gofman** (Paul Gofman) reworked it and committed it to Valve's bleeding-edge Wine
  ([`e893f50`](https://github.com/ValveSoftware/wine/commit/e893f50187da44b919c6655e880905242076e283),
  [MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616)).
- **mateuscamp, pedmrs, Phototonic, Colten61, reshdesu, kevinkirchhof** and others on
  [Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337) found and narrowed the cause.
- **The Wine project and Valve** wrote everything the DLLs are built from.

None of souzomain's or gofman's code is used here. Full account in [NOTICE.md](NOTICE.md).

## More

[DETAILS.md](DETAILS.md) (old long README) · [CHECKS.md](CHECKS.md) (what was checked) · [build/README.md](build/README.md) (rebuild the DLLs) · `LICENSE`: GNU LGPL 2.1.
