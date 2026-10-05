# Building riscos-torcs

Everything is cross-built on Linux (x86-64; Ubuntu 24.04 tested).

## What you need

- The **riscos-crossdev toolchain 1.3** (GCCSDK GCC 10.2, UnixLib 5.0.3.2,
  static only, `elf2aif`, `qemu-arm-aligntrap`), unpacked anywhere:
  `riscos-crossdev-toolchain-1.3-x86_64-linux.tar.xz`.
- The **riscos-mesa devkit** 12f or later (OSMesa, EGL, GLU, freeglut with the
  RISC OS back end, OpenAL, SDL 2, zlib, PThreadTicker).
- Host packages: `build-essential python3 python3-pil curl git`.
- For the tests: `g++-arm-linux-gnueabihf` (QEMU test); for profiling, see
  `tools/profile/README.md`.

```sh
export RISCOS_TOOLCHAIN=/opt/rcd/riscos-crossdev-toolchain-1.3-x86_64-linux
export RISCOS_DEVKIT=/opt/devkit/riscos-mesa-devkit-12f
build/fetch.sh            # sources from archive.ubuntu.com, checked, TORCS patched
build/build-deps.sh       # libpng, ogg, vorbis, freealut, plib -> work/stage
build/build-torcs.sh      # TORCS -> work/torcs/src/linux/torcs (ELF)
build/package.sh m1-2     # -> dist/TORCS-m1-2.zip
```

`WORK` (default `./work`) holds the sources, the staged libraries and the build;
`DL` (default `$WORK/dl`) the tarballs. A full build takes about five minutes on
two cores.

`package.sh` includes a few tracks (`TRACKS`, default a test set of nine);
`TRACKS=all` packs all 38 (about 435 MB of data).

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
