#!/usr/bin/env bash
# Apply the patches needed to build Termux packages for a custom prefix.
#
#   ./apply-patches.sh <termux-packages-dir> [rootfs]
#
# rootfs defaults to /data/adb/termux, so the install prefix becomes
#   <rootfs>/usr  and  HOME becomes <rootfs>/home
set -euo pipefail

REPO="${1:?usage: apply-patches.sh <termux-packages-dir> [rootfs]}"
ROOTFS="${2:-/data/adb/termux}"
cd "$REPO"

python3 - "$ROOTFS" <<'PY'
import re, sys
rootfs = sys.argv[1]

def read(p):
    with open(p) as f: return f.read()

def write(p, s):
    with open(p, 'w') as f: f.write(s)

def patch(path, old, new, marker):
    s = read(path)
    if marker in s:
        print(f"  = {path}: already patched")
        return
    if old not in s:
        print(f"  ! {path}: pattern not found")
        return
    write(path, s.replace(old, new, 1))
    print(f"  + {path}")

# 1) Custom rootfs / prefix
props = "scripts/properties.sh"
old = 'TERMUX__ROOTFS="$TERMUX_APP__DATA_DIR/$TERMUX__ROOTFS_SUBDIR"'
new = f'# [custom-prefix] build for {rootfs}\nTERMUX__ROOTFS="{rootfs}"\n# {old}'
patch(props, old, new, '[custom-prefix]')

# 2) bzip2 is a subpackage of libbz2 now (bootstrap builds)
bb = "scripts/build-bootstraps.sh"
s = read(bb)
if 'PACKAGES+=("bzip2")' in s:
    write(bb, s.replace('PACKAGES+=("bzip2")', 'PACKAGES+=("libbz2") # [custom-prefix]'))
    print(f"  + {bb}: bzip2 -> libbz2")
else:
    print(f"  = {bb}")

# 3) apr-util 1.6.5 was removed from the Apache mirrors
au = "packages/apr-util/build.sh"
s = read(au)
if 'TERMUX_PKG_VERSION="1.6.5"' in s:
    s = s.replace('TERMUX_PKG_VERSION="1.6.5"', 'TERMUX_PKG_VERSION="1.6.6"')
    s = re.sub(r'TERMUX_PKG_SHA256=[0-9a-f]{64}',
               'TERMUX_PKG_SHA256=acd5f38440eda830e40c4fe35c2a6b8119493cfdba9c9d73d985c317beb4e4f8', s)
    write(au, s)
    print(f"  + {au}: 1.6.5 -> 1.6.6")
else:
    print(f"  = {au}")

# 4) htop links libcap when it is present in the build prefix
ht = "packages/htop/build.sh"
s = read(ht)
if 'TERMUX_PKG_DEPENDS="libandroid-support, ncurses"' in s:
    write(ht, s.replace('TERMUX_PKG_DEPENDS="libandroid-support, ncurses"',
                        'TERMUX_PKG_DEPENDS="libandroid-support, ncurses, libcap"'))
    print(f"  + {ht}: libcap dependency")
else:
    print(f"  = {ht}")
PY

echo "patches applied to $REPO (rootfs=$ROOTFS)"
