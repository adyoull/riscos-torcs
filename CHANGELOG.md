# Changelog

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
