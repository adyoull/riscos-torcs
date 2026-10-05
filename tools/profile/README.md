# Profiling TORCS's drawing on a Linux host

The Pi draws with riscos-mesa's patched classic Mesa (software OpenGL). The
same Mesa built for Linux as an xlib libGL gives the same rasteriser code
paths, so where a frame's time goes can be measured on a host with callgrind
(instruction counts; wall-clock time in a shared container is useless). This
is the method the Warzone 2100 and YSFlight ports used.

1. **Mesa:** Mesa 20.3.5 (sha256 `adabbe01…`) with riscos-mesa's
   `patches/mesa`, in the order of its `build/build-mesa.sh`, built with
   `meson setup build -Dosmesa=classic -Dglx=xlib -Dgallium-drivers=
   -Ddri-drivers= -Dvulkan-drivers= -Degl=disabled -Dgbm=disabled
   -Dplatforms=x11 -Dgles1=disabled -Dgles2=disabled -Dllvm=disabled
   -Dshared-glapi=enabled` (meson 0.63, mako). Put `libGL.so.1` (from
   `build/src/mesa/drivers/x11`) and `libglapi.so.0` in a directory: `GLDIR`.
2. **TORCS:** `TORCS_SRC=work/torcs HOSTDIR=/tmp/torcs-host build-host.sh`
   builds the patched tree for Linux with the static modules and the
   software-OpenGL changes (`-DTORCS_STATIC_MODULES -DTORCS_SOFTWARE_GL`).
   The game data: a normal Linux `make install datainstall` of the same
   tree, or `work/inst/riscos/share/games/torcs` after `build/package.sh`.
3. **Run:** `TORCS_BIN=... TORCS_DATA=... GLDIR=... run.sh NAME [Section:attr=value ...]`
   starts Xvfb, runs TORCS under callgrind (instrumentation off), clicks
   Race > Quick Race > New Race, waits `PROF_WAIT` seconds, measures
   `PROF_SECS` seconds and prints instructions per frame (frames = calls to
   `glutSwapBuffers`). Settings: `PROF_TRACK`/`PROF_CAT`, `PROF_ROBOTS`
   (empty = alone), `PROF_TEXSIZE`, `PROF_MULTITEX=1`. Each run takes about
   eight minutes. `callgrind_annotate --inclusive=yes /tmp/torcsprof/NAME.cg.1`.

Results: `docs/PORTING-NOTES.md`, "Speed".
