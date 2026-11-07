# ArcheAge Chronicles on Linux: fix for the SystemTimeToTzSpecificLocalTimeEx launch error

The game (Steam app 3218230) stops at launch with:

> The procedure entry point SystemTimeToTzSpecificLocalTimeEx could not be located in the dynamic link library KERNEL32.dll.

Wine does not export two time-zone functions from `kernel32.dll`. Upstream report:
[ValveSoftware/Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337).

## Method 1: Proton Experimental bleeding-edge beta (try this first)

No download, no terminal.

1. Steam > Library > filter **Tools** > **Proton Experimental** > Properties > Game Versions & Betas > **bleeding-edge**.
2. **ArcheAge Chronicles** > Properties > Compatibility > force **Proton Experimental**.
3. Launch.

Valve calls this branch ["automated and untested"](https://github.com/ValveSoftware/Proton/wiki/Proton-Versions#proton-bleeding-edge),
and it affects every game that uses Proton Experimental. To undo, set the beta back to **None**.

**Did not work for you?** Either the dialog is still there, or the game starts and then hangs on a black screen when you
enter a server. Use Method 2.

## Method 2: patched copy of Proton Experimental

Works on the same machine where Method 1 hung. Only for Proton Experimental `11.0-20261027b`; the installer refuses
anything else. On proton-cachyos, use [hiraethi's package](https://github.com/hiraethi/archeage-proton-tzfix).

1. Set the Proton Experimental beta to **None**. Wait for the update, then close the game.
2. Check the build. This must print `1793301796 experimental-11.0-20261027b-x86_64`:

   ```sh
   head -n1 "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/version"
   ```

3. Installed before, or coming from Method 1? Remove the old copy first (the installer will not overwrite it):

   ```sh
   rm -rf ~/.local/share/Steam/compatibilitytools.d/proton-experimental-tzfix
   ```

4. Download this repo and run the installer:

   ```sh
   git clone https://github.com/Apolyth-Official/archeage-chronicles-linux-tzfix
   cd archeage-chronicles-linux-tzfix
   ./install.sh
   ```

5. Restart Steam. **ArcheAge Chronicles** > Properties > Compatibility > force
   **Proton Experimental 11.0-20261027b (self-built TZ fix)**.

Check the install. Exactly four files should be listed (`kernel32.dll` and `kernelbase.dll`, 64-bit and 32-bit):

```sh
S=~/.local/share/Steam
for a in x86_64-windows i386-windows; do
  diff -rq "$S/compatibilitytools.d/proton-experimental-tzfix/files/lib/wine/$a" "$S/steamapps/common/Proton - Experimental/files/lib/wine/$a"
done
```

More than four means the copy is wrong. We saw 581 after switching between methods, and the game aborted with
`unimplemented function win32u.NtGdiDdDDIQueryFSEBlock`. Remove it and reinstall (step 3). We do not know what changed those files.

To remove: pick another tool for the game, then delete the folder in step 3.

## If Method 1 hung: what we saw

One machine: Fedora 44, KDE Plasma (Wayland), RTX 5070, NVIDIA driver 615.78.08.

- Black screen after entering a server, force quit needed.
- NVIDIA kernel log, 4 of 4 launches: `NVRM: Xid 109 ... CTX SWITCH TIMEOUT` from `GameThread`.
  Check yours with `journalctl -k | grep "NVRM: Xid"`.
- The in-game upscaler was already **TSR**, so TSR did not help.
- Cause unknown. One machine, no log captured. To capture one, set the launch option `PROTON_LOG=1 %command%`.

## Limits

- **Anti-cheat:** the game uses XIGNCODE3. Nobody here has measured how it reacts to a modified `kernel32.dll`. Use at your own risk.
- **Unofficial:** not provided or endorsed by XLGAMES, Valve, or the Wine project.
- **Tested:** one machine (above). Apolyth reports the game works with Method 2. Not tested: other distros, Steam Deck, other GPUs, long sessions.

## Credits

- **[hiraethi](https://github.com/hiraethi/archeage-proton-tzfix)** wrote the patch and published the first working fix.
  Method 2 is their patch, unmodified, and their install approach.
- **souzomain** (Vinicius Morais) wrote the patch behind the bleeding-edge fix
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6641383405)).
- **gofman** (Paul Gofman) reworked it and committed it to Valve's bleeding-edge Wine
  ([`e893f50`](https://github.com/ValveSoftware/wine/commit/e893f50187da44b919c6655e880905242076e283),
  [MR 12616](https://gitlab.winehq.org/wine/wine/-/merge_requests/12616)).
- **DeconWhite** confirmed the bleeding-edge beta works and posted the steps for Method 1
  ([comment](https://github.com/ValveSoftware/Proton/issues/10337#issuecomment-6704008505)).
- **mateuscamp, pedmrs, Phototonic, Colten61, reshdesu, kevinkirchhof** and others on
  [Proton#10337](https://github.com/ValveSoftware/Proton/issues/10337) found and narrowed the cause.
- **The Wine project and Valve** wrote everything the DLLs are built from.
- **Apolyth** built the DLLs from source, adapted the installer, and wrote this guide. **Claude (Anthropic)** did much of the hands-on work under Apolyth's direction.

None of souzomain's, gofman's or DeconWhite's code is in Method 2. Also consulted: caostra, inhibitor181. Full account in [NOTICE.md](NOTICE.md).

## More

[DETAILS.md](DETAILS.md) (old long README) · [CHECKS.md](CHECKS.md) (what was checked) · [build/README.md](build/README.md) (rebuild the DLLs) · `LICENSE`: GNU LGPL 2.1.
