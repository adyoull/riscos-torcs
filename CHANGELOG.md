# Changelog

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
