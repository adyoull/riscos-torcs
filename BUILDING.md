# Building riscos-torcs

Everything is cross-built on Linux (x86-64; Ubuntu 24.04 tested).

## What you need

The easy way is riscos-crossdev's container image, which has everything
(the version is the `riscos-crossdev` line of `.riscos-deps`):

```sh
docker run --rm -v "$PWD":/src ghcr.io/adyoull/riscos-crossdev:1.10 sh -c \
  'build/fetch.sh && build/build-deps.sh && build/build-torcs.sh && build/package.sh test'
```

Without Docker:

- **riscos-crossdev's toolchain** (GCCSDK GCC 10.2, UnixLib 5.0.3.3, static
  only, `elf2aif`, `qemu-arm-aligntrap`): the release named in
  `.riscos-deps` (its `toolchain/PREBUILT` names the tarball), installed
  with its `make prebuilt` or unpacked anywhere; set `RISCOS_TOOLCHAIN` to
  it. (Unpacked by hand, run its `toolchain/relocate.sh` once.)
- **The riscos-mesa devkit** named in `.riscos-deps`: OSMesa, EGL, GLU,
  freeglut with the RISC OS back end, OpenAL, SDL 2, zlib, PThreadTicker.
  `build/fetch.sh` downloads it from the riscos-mesa GitHub release, checks
  it against `build/SHA256SUMS` and unpacks it into `$WORK`, unless
  `RISCOS_DEVKIT` already points at that version.
- `RISCOS_UNIXLIB` (optional): a directory with a `libunixlib.a` to link
  instead of the toolchain's.
- Host packages: `build-essential python3 curl git`.
- For the tests: `g++-arm-linux-gnueabihf` (QEMU test); for profiling, see
  `tools/profile/README.md`.

```sh
export RISCOS_TOOLCHAIN=/opt/riscos-crossdev/toolchain/env
build/fetch.sh            # sources from archive.ubuntu.com and the devkit, checked; TORCS patched
build/build-deps.sh       # libpng, ogg, vorbis, freealut, plib -> work/stage
build/build-torcs.sh      # TORCS -> work/torcs/src/linux/torcs (ELF)
TRACKS_PACK=TORCS-tracks-1.3.7 build/package.sh 1.3.7-riscosN   # -> dist/TORCS-1.3.7-riscosN.zip
```

`WORK` (default `./work`) holds the sources, the staged libraries and the build;
`DL` (default `$WORK/dl`) the tarballs. A full build takes about five minutes on
two cores.

`package.sh` includes a few tracks (`TRACKS`, default a set of nine);
`TRACKS=all` packs all 38 (about 435 MB of data). `TRACKS_PACK=NAME` also
makes `dist/NAME.zip`, the tracks pack: every other track, in a
`TORCS-tracks/!TORCS/tracks` tree to copy over the application, with
`riscos/TracksPack-ReadMe`. The release uses
`TRACKS_PACK=TORCS-tracks-1.3.7 build/package.sh 1.3.7-riscosN`.

## The patch series

`build/fetch.sh` unpacks TORCS into `work/torcs`, makes it a git repository
(tag `upstream`; the game data is excluded) and applies `patches/torcs/series`
as commits. To change a patch, edit in `work/torcs`, commit with
`git commit --fixup=<commit>`, then

```sh
GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash --autostash upstream
rm patches/torcs/*.patch
git -C work/torcs format-patch --zero-commit --no-numbered --no-signature \
    -o ../../patches/torcs upstream..HEAD | sed 's|.*/||' > patches/torcs/series
```

`Make-config` and `config.h` in `work/torcs` show as changed: `build-torcs.sh`
copies `Make-config.riscos` and `config.h.riscos` over them (there is no
configure step for the cross build).

## Checks

- `build-torcs.sh` runs the stack probe check (every frame of 4 KB or more must
  probe: the ELF stack grows a page at a time behind a guard page).
- `package.sh` refuses a program that contains build paths.
- **QEMU alignment test** (`tests/qemu`): TORCS built for ARM Linux with the
  RISC OS code settings (`-mno-unaligned-access`, VFPv3) runs a console race
  (all robots, no graphics) under `qemu-arm-aligntrap`, which stops on an
  unaligned access as RISC OS does:

  ```sh
  tests/qemu/build.sh && tests/qemu/run.sh forza road 1
  ```

  Exit status 0 and a results file = pass; 135 = unaligned access.

## RISC OS rules followed

- Static linking only; the program is converted to AIF (`elf2aif`) so it needs
  no ELF loader and runs from `!Run` with a fixed WimpSlot.
- `-fstack-clash-protection` everywhere (toolchain and devkit too).
- `-fno-delete-null-pointer-checks` (old C++ that tests `this == NULL`).
- No `popen`, `system`, `fork` or `exec`: TORCS's restart after changing the
  screen settings becomes "settings saved, start again"; telemetry doesn't run
  its plot script.
- stdout and stderr go to one file (`TORCS$Log`), opened once and shared with
  `dup2` (a RISC OS file can be open for writing only once).
- Threads only where the libraries need them (OpenAL's mixer); PThreadTicker is
  loaded by `!Run`.

## Commits

Author Andrew Youll <andrewyoull86@gmail.com>, no tool attribution lines.

## Building on GitHub

`.github/workflows/` has riscos-crossdev's two workflows (its `docs/CI.md`):

- `riscos-build.yml` builds, checks and tests every push and pull request in
  the riscos-crossdev image named in `.riscos-deps`, and keeps the zip as a
  download on the run's page.
- `riscos-deps-update.yml` looks every day for newer releases of what
  `.riscos-deps` names (riscos-crossdev, riscos-mesa). When there is one, it
  moves the pin (and, through `ci/riscos-deps-hook.sh`, the devkit's line in
  `build/SHA256SUMS`), builds and tests with it, and opens a pull request
  saying whether that passed. Nothing is merged or released by itself: merge,
  test on a Pi, then release.

The build they run: `build/fetch.sh`, `build/build-deps.sh`,
`build/build-torcs.sh`, riscos-crossdev's `checks/check-all.sh` on the program,
`build/package.sh ci`, then the QEMU alignment test (`tests/qemu`, a console
race on forza).
