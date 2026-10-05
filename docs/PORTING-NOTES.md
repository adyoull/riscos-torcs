# Porting notes

## Choice of version

TORCS 1.3.7 as Debian packages it (`torcs_1.3.7+dfsg`), not 1.3.8 (2020) and
not Speed Dreams:

- 1.3.8 is a small bug-fix release on the same engine; neither the cloud build
  machine nor the Mac can reach SourceForge, while Debian's source comes from
  archive.ubuntu.com with checksums.
- Debian's `+dfsg` repack has already taken out the data that isn't free
  software, and its patches fix building with modern GCC.
- Speed Dreams moved to OpenSceneGraph and shaders, which software OpenGL runs
  about twenty times slower (YSFlight's gl2 build: 0.18 fps).

TORCS draws with fixed-function OpenGL 1.x through GLUT and plib's ssg: the
case riscos-mesa's software renderer handles best.

## The patches

| Patch | What |
|---|---|
| 0001–0004 | Debian's: isnan with GCC 6, glibc default source, format strings, GCC 7 |
| 0005 static cross build | `Make-config.riscos` / `config.h.riscos` instead of configure; with `RISCOS_STATIC`, libraries become static archives and modules partly-linked objects with only `<name>` and `<name>Shut` global; host tools not built |
| 0006 modules linked in | `riscosspec.cpp`: the module functions over a table (`RiscosModules[]`, written by `build-torcs.sh`); `CLOCK_MONOTONIC` clock; ssggraph's `grContext` state is set again once there is an OpenGL context |
| 0007 desktop start-up | `riscosplatform.cpp` (log file, crash report, `<TORCS$Dir>` / `<Choices$Write>.TORCS`, first-run copy of the settings, run in the data directory); multitexturing off unless `-M`; no X11 game mode; no `execlp` (screen settings: save and quit); no `sh` for telemetry; small window sizes in the Display menu |
| 0008 fast textured triangles | `GL_FASTEST`, `GL_CLAMP` → `GL_CLAMP_TO_EDGE`, luminance textures expanded to RGB(A), `GL_SINGLE_COLOR` lighting |
| 0009 speed | first run: a desktop window in the screen's shape, 540 high, opened near the centre (full screen, in Options > Display, is freeglut game mode: render size + overlay); 16:10 and 16:9 Display sizes; "Sky background" option in Graphic Configuration (RISC OS default off); RGBA font textures |

The plib patch (`patches/plib/10-riscos-platform.patch`) adds `UL_RISCOS`: no
`dlopen`, the ssg context check through EGL, a joystick back end on the
Joystick SWIs (`jsRISCOS.cxx`: USBJoystick's slot API, else `Joystick_Read`
stick 0; the SWI use follows riscos-ysflight's joystick reader) and a silent
`slDSP` (plib's own sound has no RISC OS device; TORCS's default sound is
OpenAL).

### Static modules

TORCS's graphics engine, physics, track loader and robots are shared objects
loaded with `dlopen`. Linking them all into one program has two problems:

1. **Clashing global names.** The robots were written as separate shared
   objects and many define the same globals. Each module is linked on its own
   with `ld -r --force-group-allocation` (the C++ COMDAT groups are resolved
   inside the module, so each keeps its own copies of inline functions) and
   `objcopy --keep-global-symbol=<name> --keep-global-symbol=<name>Shut` makes
   everything else local. The 16 modules link without a clash.
2. **Static constructors run at program start**, not when the module is
   loaded. ssggraph's global `ssgContext grContext` sets OpenGL state in its
   constructor: on Linux that happens after the window exists; linked in, it
   happens before there is a context. Patch 0006 applies that state again in
   `initTrack`. (Found by the QEMU test, where the OpenGL stubs are absent and
   the call crashed.)

Behaviour that may differ from Linux, not yet seen:
- Linux unloads a robot after a race and loads it fresh for the next one, so
  its globals start again from their initial values. Linked in, a robot's
  globals keep their values from the previous race. Watch the second race of a
  session (and championships).

The same code builds on Linux with `-DTORCS_STATIC_MODULES`
(`tools/profile/build-host.sh`): a full quick race with four robots runs.

### Files and directories

- The game data and the robots' data are in `!TORCS` (`TORCS$Dir`), read
  through UnixLib as `/<TORCS$Dir>/...`; the program runs with the data
  directory as the current directory, as the Linux launcher runs it (UnixLib's
  `chdir` sets the RISC OS current directory).
- Settings and results are in `<Choices$Write>.TORCS`. On the first run the
  14 settings files the Linux launcher copies (`setup_linux.sh`) are copied
  there; a newer copy in the application replaces an old one, which is kept as
  `.old`.
- The zip stores names like `car.xml`; RISC OS unzippers turn them into
  `car/xml`, which UnixLib maps back. None of the data's suffixes are in
  UnixLib's suffix list, and no two names differ only in case.

## Speed

Host profile (`tools/profile`): callgrind instruction counts per frame of
the quick race at its start (forza, 640x480, the camera behind the player's
car, four robots), the host build drawing with riscos-mesa's patched Mesa as
an xlib libGL. YSFlight measured about 175M instructions per frame for about
20 fps on a Pi 4, which gives a rough scale.

| Build | M instr/frame | Notes |
|---|---|---|
| upstream rendering, single texture | 1256 | every textured triangle on Mesa's general path: `fetch_texel_2d_R8G8B8A8` + bilinear + per-pixel mipmap lambda (`log2f`) |
| + `GL_FASTEST`, `GL_CLAMP_TO_EDGE`, RGB luminance | 1236 | still general: TORCS turns on `GL_SEPARATE_SPECULAR_COLOR` |
| + `GL_SINGLE_COLOR` (patch 0008) | 486 | `persp_textured_triangle`; `fast_persp_span` is now 38% |
| + RISC OS graph defaults, textures ≤ 512 | 428 | the shipped defaults |
| same, alone on the track, textures ≤ 256 | 424 | the robots are far ahead by then; 256 saves little more |

**Pi 4, m1-1: 4.8 fps** (640x480 window, alone on forza). That is slower
than the YSFlight scale suggested (textures cost more in cache misses than
instruction counts show), so m2-1 cuts pixels:

| Build (m2-1 settings) | M instr/frame | Notes |
|---|---|---|
| RGBA fonts, 640x480 | 432 | no change (text is a small area) |
| + no sky background | 336 | the panorama was 18–22% of a frame |
| + drawn at 640x360 (full screen, stretched) | 276 | 64% of m1-1's 428 |

TORCS's full screen is GLUT's game mode, and riscos-mesa's freeglut draws a
game-mode window at the size asked for and stretches it over the screen
(through VideoOverlay where it's loaded, which also saves the plot), with the
pointer scaled to match. So TORCS needed no window code: the first run sets
full screen at a size in the screen's shape. What remains is Mesa's
`fast_persp_span` (34% self) plus fog (6%) and depth (3%): Mesa-side work
(a riscos-mesa handoff, e.g. NEON) or fewer pixels still (480x270).

The texture size limit also saves memory: software OpenGL keeps every texture
in RAM, and many track textures are 1024x1024.

## Tests

- `tests/qemu`: console races (no graphics) with every robot on forza, the
  a-speedway oval, dirt-4 and e-track-4 under `qemu-arm-aligntrap`: no
  unaligned accesses, races finish, results written.
- Robots that report "Bad Car category" use cars Debian removed; they aren't
  started (as on Linux with the same data).

## To do

- Pi test (M1): frame rate alone on the track, the menus, keyboard, sound.
- Render size and overlay (M2), then AI cars and their cost.
- FontManager is not needed (TORCS draws its own fonts).
- A data pack with all tracks (`TRACKS=all`, about 435 MB).
