# Changelog

## Unreleased (1.3.7-riscos7)

- **No more abort at the start of a race with some Joystick modules**
  (plib patch 11). TORCS looks for joysticks when a race starts. On a
  user's Pi 4 a Joystick module answered USBJoystick's newer
  Joystick_AxisInfo call with an address that wasn't there, and TORCS
  aborted in memcpy (&31AF50 in riscos6). Every record a Joystick module
  returns is now checked (sizes, counts, and OS_ValidateAddress) before
  it's read; if any answer can't be used, stick 0 is read with the
  standard Joystick_Read instead. `*Set TORCS$Joystick off` ignores
  joysticks, `*Set TORCS$Joystick stable` uses Joystick_Read only.
- `tests/joystick/run.sh`: plib's RISC OS joystick code against a
  pretend Joystick module (good answers, a bad address, no module, a
  huge count, both settings), in the GitHub build.

## 1.3.7-riscos6 (2026-11-16)

- **Released as a "mixed" program only:** `TORCS,e1f` (4 MB, an ELF run
  by !SharedLibs) has UnixLib and TORCS's own libraries linked in and
  loads OpenGL, EGL, GLU, freeglut, SDL 2 and OpenAL from riscos-mesa's
  !MesaLibs (20.3.5-20 or later) in !Boot.Resources. The static build is
  still made and checked by the GitHub build, but not released.
- **The GPU, where RISC3D can use it:** linked with riscos-mesa 20.3.5-20
  and `-lMesaGPU`, so with !RISC3D installed TORCS draws on the GPU of a
  Pi 4, natively (through !MesaLibs' libMesaGPU) and under RISC OS on
  Linux. RISC3D chooses the backend; TORCS names no driver. `!Run` loads
  RISC3D from !RISC3D when it's installed, and needs nothing else for it.
  `MESAGPU=0 build/build-torcs.sh` links without libMesaGPU.
- **Built with UnixLib 5.0.3.10** (linked in with `RISCOS_UNIXLIB`; was
  5.0.3.6): a bad file descriptor no longer costs a SWI. TORCS's XML
  reader (sscanf) tried one about 13,500 times a second, and under RISC
  OS on Linux, where each SWI traps, loading a track took minutes; it now
  takes about 4 seconds.
- Under RISC OS on Linux with RISC3D on a Pi 4, the race runs at about
  24-30 fps (about 10 fps in software).

- Starting a race can no longer hang in the texture size check (patch
  0015): it halved each texture until OpenGL's proxy texture reported a
  width, and looped for ever if that, or `GL_MAX_TEXTURE_SIZE`, came back
  0. riscos6test1 locked up at the start of a race under RISC OS on Linux
  with RISC3D; this is the first suspect, and the trace says if it
  happens.
- For reports (patch 0014): `*Set TORCS$Trace 1` writes each start-up
  stage, the first frames and every hundredth, menu screens and sound to
  the log, and a watchdog thread writes where TORCS was if it stops
  making progress for 5 seconds. `*Set TORCS$NoSound 1` starts no sound
  at all (OpenAL isn't started). Both are off unless set. Patch 0016 adds
  the race loading: each loading-screen message, the scene's steps and
  each texture. `TRACE=1 build/package.sh` makes a test zip with the
  trace on.
- `GLCOUNT=1 build/build-torcs.sh` (diagnosis only) wraps every GL
  function TORCS and plib call with a counter (`tools/glcount-gen.sh`),
  and the trace writes the counts after the background, after the track
  model and every 100 frames, marking the calls that wait for an answer
  (patch 0017).
- The trace also logs OpenGL errors from the first 40 texture uploads,
  and `*Set TORCS$NoMipmaps 1` loads textures without mipmaps, for
  finding faults (patch 0018).
- `FDTRACE=1 build/build-torcs.sh` (diagnosis only) logs calls on file
  descriptors that fail with EBADF, with their callers
  (`tools/fdtrace.c`, `ld --wrap`): ROL found TORCS's track loading on the
  Pi spending its time in about 13,500 such calls a second.
- The test builds were linked with riscos-mesa 20.3.5-19 (was 20.3.5-18),
  the first with RISC3D: where it has a driver, OpenGL is drawn by the
  GPU; `LIBGL_ALWAYS_SOFTWARE` keeps it in software.
- A mixed build as well as the static one: `MIXED=1 build/build-torcs.sh`
  links `src/linux/torcs-mixed` (UnixLib, libstdc++, plib, freealut,
  libpng, Ogg Vorbis and zlib linked in; OpenGL, EGL, GLU, freeglut, SDL 2
  and OpenAL from !MesaLibs), and `MIXED=1 build/package.sh` makes
  `TORCS-<version>-mixed.zip`, with `TORCS,e1f` and the `!Run` ending in
  `riscos/mixed-run`. The program is 4 MB against 13.5 MB.
- Built with riscos-crossdev 1.11's toolchain, and with PThreadTicker 0.04 (`!Run` loads 0.04 or
  later, and stops with an error if an older one is already loaded).
- The GitHub build makes and checks both (`check-mixed-package.sh` against
  the devkit's !MesaLibs).

## 1.3.7-riscos5 (2026-11-04)

- Steadier sound, with the RISC OS OpenTTD port's fixes:
  - OpenAL mixes in pieces of 2048 samples (was 1024), so SDL's RISC OS
    driver keeps about 140 ms queued (was about 70 ms; OpenTTD uses 4096,
    about 280 ms). The setting is in
    `!TORCS.alsoft/conf`, which TORCS names in `ALSOFT_CONF` unless it's
    already set (patch 0013).
  - The sound thread is given a turn after every frame with
    `sched_yield()` (patch 0013): TORCS never waits between frames.
- Built with riscos-crossdev 1.10's toolchain, so UnixLib 5.0.3.6 (was
  5.0.3.3). Its semaphores now sleep: OpenAL's event thread used to spin in
  `sem_wait` for the whole race, taking CPU time from it; now it waits
  until there's an event.
- Linked with riscos-mesa 20.3.5-18 (was 20.3.5-17): SDL 2.32.10, which
  TORCS uses only for OpenAL's sound output, and OpenAL mixing with NEON.
  Drawing is the same as 20.3.5-17.
- Builds on GitHub (riscos-crossdev's workflows): every push is built,
  checked and tested in the riscos-crossdev image, and a pull request comes
  when riscos-crossdev or riscos-mesa makes a release. `.riscos-deps` names
  the versions; `build/fetch.sh` downloads the riscos-mesa devkit it names.
  UnixLib comes from the toolchain, so `RISCOS_UNIXLIB` isn't needed.
  The QEMU test build no longer needs X11 or GLX headers (the image has
  none).
- No changes to TORCS itself.

## 1.3.7-riscos4 (2026-10-22)

- Linked with riscos-mesa 20.3.5-17 (was 20.3.5-16). In full screen the
  pointer now stops two pixels above the bottom of the screen, so the icon
  bar no longer pops up over the game when the desktop brings it forward
  automatically (`*Set FreeGLUT$PointerMargin 0` turns this off). Drawing
  is the same as 20.3.5-16.
- No changes to TORCS itself.

## 1.3.7-riscos3 (2026-10-10)

- Linked with riscos-mesa 20.3.5-16 (was 20.3.5-14). From 20.3.5-15:
  TORCS's scene now takes Mesa's fast route (plib's alpha test on every
  state had kept it off), pixels hidden by the depth test aren't textured
  (a third of TORCS's scene), and the bilinear filtering and the scene
  stretch are quicker. From 20.3.5-16: on high-resolution (EX0 EY0)
  desktops the window is shown at twice the size instead of half size
  (`*Set EGL$WindowScale 1` for full resolution).
- No changes to TORCS itself.

## 1.3.7-riscos2 (2026-10-07)

- Fix: every race type except Quick Race (Non-Championship, Endurance,
  Championship, Challenge, Practice) was set up for tracks that aren't in
  the download, and starting it crashed (forum report: "it quits after a
  few clicks"). A race set up for a track that isn't installed now runs on
  an installed track instead, and says so.
- New: a tracks pack, `TORCS-tracks-1.3.7.zip`, with the other 29 tracks
  (all 38 of Debian's TORCS 1.3.7 together with the 9 in the main
  download). Copied over `!TORCS`, it gives every race type its usual
  tracks.
- A crash now shows an error box (pointing to the log) instead of the
  program just disappearing.

## 1.3.7-riscos1 (2026-10-07): first release

- The first public release, the same as test build m2-6, relinked with the
  released riscos-mesa devkit 20.3.5-14: its NEON texturing and blending make
  TORCS about 30% faster on a Pi 4 (10.3 fps against 7.9 with 20.3.5-13 in
  the Pi A/B test of 14rc1, the same Mesa code).
- Linked with UnixLib 5.0.3.3.

## m2-6 (2026-10-06)

- Linked with UnixLib 5.0.3.3 (was the toolchain's 5.0.3.2): fixes from a
  code audit, among them threads waiting in write()/read()/stdio and the
  /dev/dsp path. No change to PThreadTicker (0.03).
- Linked with the released riscos-mesa devkit 20.3.5-13 (was 20.3.5-12; the
  same speed for TORCS's drawing: 7.9 fps in the Pi A/B test).
- Pi A/B test of riscos-mesa 20.3.5-14rc1: 10.3 fps against 7.9 with
  20.3.5-13 (960x540 window, scene 50%); TORCS moves to 20.3.5-14 when it's
  released.

## m2-5 (2026-10-05)

- Pi test of m2-4: 7.8 fps full screen (5 in m2-3).
- TORCS now opens in a desktop window by default instead of full screen:
  540 pixels high in the screen's shape (960x540 on a 16:9 screen), near
  the centre of the screen. Full screen is still in Options > Display.
  Settings are reset to the new defaults once, on the first start.
- Linked with the released riscos-mesa devkit 20.3.5-12 (was the 12h test
  devkit): the same game mode, plus faster fog.

## m2-4 (2026-10-05)

- Pi test of m2-3: sharp writing at 960x540, but 5 fps. The 3D scene is now
  drawn at a lower resolution (Graphic Configuration, "Scene resolution",
  default 50%: 480x270 on a 960x540 screen) and stretched, while the
  writing, the race display and the menus stay at the full 540-line size.

## m2-3 (2026-10-05)

- Pi test of m2-2: full screen fills the screen now, but the writing was
  too pixelated at 360 pixels high. The draw size is now 540 high (960x540
  on 16:9, 864x540 on 16:10, 720x540 on 4:3); Options > Display has 480-
  and 720-high sizes too. It's slower than 360: pick a smaller size there
  for speed.

## m2-2 (2026-10-05)

- Pi test of m2-1: full screen showed the picture small in the middle of
  the screen, and switching to window mode didn't stick.
- Linked with riscos-mesa devkit 12h, whose GLUT game mode draws at the
  size asked for and stretches it over the screen (12f's drew at the
  desktop size, so TORCS's view sat in the middle). 12h also has faster
  clears, 2D textures, colour material and fog.
- Settings: replaced only when the application's version changes (a Version
  file), not by comparing file dates, which a Pi with a wrong clock got
  wrong at every start.

## m2-1 (2026-10-05): speed

- Pi result of m1-1: runs; 4.8 fps in a 640x480 window.
- The first run (or the first after an update) sets full screen, drawn at
  a size in the screen's shape 360 pixels high (640x360 on 16:9) and
  stretched over the screen by freeglut's game mode (VideoOverlay where
  loaded). Display sizes in 16:10 and 16:9 shapes.
- "Sky background" in Graphic Configuration; off by default on RISC OS.
- Font textures RGBA (Mesa fast path).
- Host profile: 428M -> 276M instructions per frame.

## m1-1 (2026-10-05): first test build

- TORCS 1.3.7+dfsg cross-built for RISC OS: all modules (ssggraph, simuv2,
  track, telemetry and the 12 robots) linked statically, found through a table
  instead of `dlopen`.
- Window and OpenGL through riscos-mesa's freeglut (native RISC OS back end)
  and EGL; sound through OpenAL; joysticks through the Joystick SWIs
  (USBJoystick's slot API, else `Joystick_Read`).
- Software OpenGL speed: multitexturing off by default (`-M` turns it on),
  `GL_FASTEST`, `GL_CLAMP_TO_EDGE`, luminance textures as RGB, single-colour
  lighting.
- RISC OS defaults: a quick race with only you on the track; less smoke and
  fewer skid marks, shorter view distance, simple wheels.
- Settings in `<Choices$Write>.TORCS`; log in `<Wimp$ScrapDir>.TORCSLog`.
- Nine tracks in the test zip.
