#!/usr/bin/env python3
"""Check the packaged DLLs against your own, unmodified Proton Experimental.

It picks the folder in builds/ whose VERSION matches your Proton Experimental's `version` file.

What it checks (all by reading PE headers with `objdump -p`; nothing is loaded or executed):
  1. SHA-256 of the packaged DLLs and of your stock DLLs, against that build's SHA256SUMS / STOCK-SHA256SUMS.
  2. Exported names: the packaged kernel32 must add exactly the two new functions, and nothing else
     may be added or removed anywhere.
  3. Imported DLLs: only kernelbase.dll and ntdll.dll may appear. No network, process or registry DLLs.
  4. Imported functions: the only new imports allowed are the two new functions in kernel32.

Usage:  python3 -I tools/verify-dlls.py [path to Proton Experimental]
Needs:  python3 and objdump (binutils). Exit status 0 only if every check passes.
"""
import hashlib
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SRC = os.path.expanduser("~/.local/share/Steam/steamapps/common/Proton - Experimental")
SRC = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
NEW = {"SystemTimeToTzSpecificLocalTimeEx", "TzSpecificLocalTimeToSystemTimeEx"}
ALLOWED_IMPORT_DLLS = {"kernelbase.dll", "ntdll.dll"}
fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_sums(path, prefix_strip=""):
    out = {}
    with open(path) as fh:
        for line in fh:
            digest, name = line.split(None, 1)
            out[name.strip().replace(prefix_strip, "", 1)] = digest
    return out


def objdump(path):
    return subprocess.run(["objdump", "-p", path], capture_output=True, text=True, check=True).stdout


def exports(text):
    names, inside = set(), False
    for line in text.splitlines():
        if "[Ordinal/Name Pointer] Table" in line:
            inside = True
            continue
        if inside:
            m = re.match(r"^\t\[\s*\d+\]\s+\+base\[\s*\d+\]\s+[0-9a-f]{4}\s+(\S+)$", line)
            if m:
                names.add(m.group(1))
            elif not line.strip():
                inside = False
    if len(names) < 100:  # a parse that finds (almost) nothing must never count as a pass
        sys.exit(f"parse error: only {len(names)} exported names found; objdump output format changed?")
    return names


def imports(text):
    dll, found = None, set()
    for line in text.splitlines():
        m = re.match(r"^\tDLL Name:\s+(\S+)", line)
        if m:
            dll = m.group(1).lower()
            continue
        m = re.match(r"^\t[0-9a-f]{8,16}\s+(?:<none>|\d+)\s+[0-9a-f]{4}\s+(\S+)$", line)
        if m and dll:
            found.add((dll, m.group(1)))
    if len(found) < 50:
        sys.exit(f"parse error: only {len(found)} imports found; objdump output format changed?")
    return found


def find_build():
    have = open(os.path.join(SRC, "version")).readline().strip()
    root = os.path.join(HERE, "builds")
    known = []
    for name in sorted(os.listdir(root)):
        vfile = os.path.join(root, name, "VERSION")
        if os.path.isfile(vfile):
            want = open(vfile).readline().strip()
            known.append(want)
            if want == have:
                return os.path.join(root, name)
    sys.exit(f"unsupported Proton Experimental build: {have}\nsupported: {known}")


def main():
    if subprocess.run(["objdump", "--version"], capture_output=True).returncode != 0:
        sys.exit("objdump not found (install binutils)")
    stock_dir = os.path.join(SRC, "files", "lib", "wine")
    if not os.path.isdir(stock_dir):
        sys.exit(f"Proton Experimental not found at {SRC}")
    build = find_build()
    print(f"Build: {os.path.basename(build)}")

    print("1. Checksums")
    ours = read_sums(os.path.join(build, "SHA256SUMS"), "dlls/")
    stock = read_sums(os.path.join(build, "STOCK-SHA256SUMS"))
    for rel, want in sorted(ours.items()):
        check(sha(os.path.join(build, "dlls", rel)) == want, f"packaged {rel} matches SHA256SUMS")
    for rel, want in sorted(stock.items()):
        check(sha(os.path.join(stock_dir, rel)) == want, f"your stock {rel} matches STOCK-SHA256SUMS (unmodified)")

    for arch in ("x86_64", "i386"):
        for dll in ("kernel32", "kernelbase"):
            rel = f"{arch}-windows/{dll}.dll"
            print(f"\n2-4. {rel}")
            s_txt = objdump(os.path.join(stock_dir, rel))
            o_txt = objdump(os.path.join(build, "dlls", rel))
            added, removed = exports(o_txt) - exports(s_txt), exports(s_txt) - exports(o_txt)
            want_added = NEW if dll == "kernel32" else set()
            check(added == want_added and not removed,
                  f"exports: added={sorted(added) or 'none'} removed={sorted(removed) or 'none'}")
            s_imp, o_imp = imports(s_txt), imports(o_txt)
            o_dlls = {d for d, _ in o_imp}
            check(o_dlls <= ALLOWED_IMPORT_DLLS, f"imports only from {sorted(o_dlls)}")
            new_imp = {f for _, f in o_imp - s_imp}
            check(new_imp == want_added and not (s_imp - o_imp),
                  f"new imports={sorted(new_imp) or 'none'} dropped imports={len(s_imp - o_imp)}")

    print()
    if fails:
        print(f"{len(fails)} check(s) FAILED")
        sys.exit(1)
    print("All checks passed. These checks read headers only; they cannot prove what the code does."
          " To verify that, rebuild from source (build/README.md) and compare.")


main()
