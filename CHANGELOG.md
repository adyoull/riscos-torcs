# Changelog

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
