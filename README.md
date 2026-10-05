# riscos-torcs

TORCS, The Open Racing Car Simulator, for RISC OS (Raspberry Pi 4).

This repository holds the RISC OS port as a patch series against Debian's
free-software TORCS 1.3.7 source (`torcs_1.3.7+dfsg`), plus the scripts that
cross-build it and the RISC OS application files. It doesn't contain TORCS
itself: `build/fetch.sh` downloads the sources and checks them.

Status: **test builds**. m1-1 runs on a Pi 4 (4.8 fps in a 640x480
window); m2-4 draws the 3D scene at half size under full-size writing
(7.8 fps full screen on a Pi 4); m2-5 opens in a 960x540 desktop window.

## How it fits together

- **Graphics:** TORCS draws with fixed-function OpenGL 1.x through GLUT and
  plib's ssg. On RISC OS that's riscos-mesa's freeglut with its native RISC OS
  back end, which draws through riscos-mesa's EGL into a Wimp window (software
  OpenGL: classic OSMesa). There is no X11 or GLX.
- **Sound:** OpenAL (riscos-mesa devkit) → SDL 2 audio → SharedSoundBuffer.
  Engine and tyre sounds load through freealut. Menu music is Ogg Vorbis.
- **Modules:** TORCS loads its graphics engine, physics, track loader and every
  robot driver as shared objects with `dlopen`, which UnixLib doesn't have.
  Here each module is partly linked on its own (`ld -r`), only its entry points
  are left global (`objcopy --keep-global-symbol`), so robots that reuse each
  other's global names can share one program, and a table made at link time
  replaces `dlopen` (`src/linux/riscosspec.cpp`).
- **Speed:** with software OpenGL, the defaults are chosen to keep textured
  triangles on Mesa's fast path (one texture unit, `GL_FASTEST`,
  `GL_CLAMP_TO_EDGE`, single-colour lighting) and to draw less (see
  `docs/PORTING-NOTES.md`).

## Repository layout

| Path | What |
|---|---|
| `patches/torcs/` | the TORCS patch series (`git format-patch`), applied by `build/fetch.sh` |
| `patches/plib/` | Debian's plib security fixes and the RISC OS platform patch (joystick SWIs, no dlopen, EGL) |
| `build/` | `env.sh`, `fetch.sh`, `build-deps.sh`, `build-torcs.sh`, `package.sh`, `SHA256SUMS` |
| `app/!TORCS/` | `!Run`, `!Boot`, `!Help`, `!Sprites`, PThreadTicker |
| `riscos/defaults.py` | the RISC OS default settings written into the packaged data |
| `riscos/licences/` | the licences shipped in the application |
| `tests/qemu/` | the ARM alignment test (a console race under QEMU with RISC OS's alignment rules) |
| `tools/profile/` | host profiling of a race frame on riscos-mesa's software renderer |

See `BUILDING.md` to build, `docs/PORTING-NOTES.md` for what the patches do and
why.

## Licence

TORCS is under the GNU GPL version 2 or later, and so is this port (the patches,
the new source files and the scripts). The game data and the libraries keep
their own licences: see `riscos/licences/ReadMe` and `docs/LICENSING.md`.
