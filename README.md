# termux-prefix

Build [Termux](https://github.com/termux/termux-packages) packages for a **custom
prefix** (default `/data/adb/termux`) with GitHub Actions, and publish them as an
apt repository on GitHub Pages.

This exists because the official Termux debs hardcode `/data/data/com.termux/files/usr`.
To run a fully self-contained Termux environment outside the Termux app (e.g. at
`/data/adb/termux`), every package has to be rebuilt with a different
`TERMUX__ROOTFS`.

## How it works

1. Clone `termux-packages` at the latest commit.
2. Apply `scripts/apply-patches.sh`:
   - `TERMUX__ROOTFS=/data/adb/termux` in `scripts/properties.sh`
   - `bzip2` → `libbz2` (it became a subpackage)
   - `apr-util` 1.6.5 → 1.6.6 (1.6.5 was removed from Apache mirrors)
   - `htop` declares its `libcap` dependency
3. Run the official builder image (`ghcr.io/termux/package-builder`) with
   `--privileged` and add NDK r30 (the published image ships r29).
4. Build the requested packages, regenerate the apt index and push it to the
   `gh-pages` branch.

## Usage

Actions → **build-packages** → *Run workflow*:

| input | example |
|---|---|
| `packages` | `htop` or `jq htop git` |
| `arch` | `aarch64` |
| `rootfs` | `/data/adb/termux` |
| `keep` | keep previously published debs |

The result is available at:

```
https://<owner>.github.io/termux-prefix/
```

## On the device

```bash
echo 'deb [trusted=yes] https://<owner>.github.io/termux-prefix ./' \
  > $PREFIX/etc/apt/sources.list.d/github.list
apt update
apt install htop
```

Dependencies are resolved from the published index like any apt repository.

## Notes

- Building is per-package on demand. There is no full mirror: request the
  packages you need.
- A job is capped at 6 hours; large packages (llvm, etc.) may need to be built
  locally instead.
- First run also needs GitHub Pages enabled once
  (Settings → Pages → Branch: `gh-pages`).
- The same patches work for local builds; see `scripts/apply-patches.sh`.
