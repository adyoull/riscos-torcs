/* fdtrace.c: find calls on file descriptors that fail with EBADF.
 * Diagnosis only (build-torcs.sh FDTRACE=1), linked with -Wl,--wrap for
 * each function below. Every call made by the program, its libraries
 * linked in and UnixLib itself (stdio's reads and so on) comes here
 * first. A call that fails with EBADF is counted by function, descriptor
 * and caller; the first 30 are written to the log (stdout) with the
 * callers found by walking the frame-pointer chain, then a summary every 2 seconds while they go on.
 * Output goes through __real_write, so it isn't traced itself.
 * The addresses are looked up in the unstripped program afterwards
 * (arm-riscos-gnueabihf-addr2line -f -C -e torcs ADDR). */
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/stat.h>

extern ssize_t __real_read(int, void *, size_t);
extern ssize_t __real_write(int, const void *, size_t);
extern int __real_close(int);
extern int __real_fstat(int, struct stat *);
extern int __real_fcntl(int, int, ...);
extern int __real_isatty(int);
extern int __real_ioctl(int, unsigned long, ...);
extern int __real_select(int, fd_set *, fd_set *, fd_set *, struct timeval *);
extern int __real_dup(int);
extern int __real_dup2(int, int);
extern __off_t __real_lseek(int, __off_t, int);
extern int __real_poll(struct pollfd *, nfds_t, int);
extern int __real_fsync(int);

#define SLOTS 32
static struct { const char *op; int fd; unsigned caller; unsigned long n; } slot[SLOTS];
static unsigned long total;
static clock_t lastsum;
static int busy;

static void say(const char *fmt, ...)
{
	char b[400];
	va_list ap;
	va_start(ap, fmt);
	int n = vsnprintf(b, sizeof b, fmt, ap);
	va_end(ap);
	if (n > (int)sizeof b - 1) n = sizeof b - 1;
	if (n > 0) __real_write(1, b, n);
}

/* Callers above the wrapper, from the frame-pointer chain as this GCC
   lays it out (push {fp, lr}; add fp, sp, #4: [fp] = lr, [fp-4] = the
   caller's fp), checked to stay on this stack and to rise. Frames 0-2 are
   chain(), note() and the __wrap_ function; frame 2's lr is "first". */
static __attribute__((noinline)) int chain(unsigned *out, int max, unsigned first)
{
	int n = 0;
	unsigned *fp = (unsigned *)__builtin_frame_address(0);
	unsigned sp = (unsigned)&n;
	out[n++] = first;
	for (int i = 0; n < max && i < 10 && fp; i++) {
		unsigned f = (unsigned)fp;
		if (f < sp || f > sp + 0x100000 || (f & 3)) break;
		unsigned lr = fp[0];
		unsigned *up = (unsigned *)fp[-1];
		if (i >= 3) out[n++] = lr;
		if ((unsigned)up <= f) break;
		fp = up;
	}
	return n;
}

static __attribute__((noinline)) void note(const char *op, int fd, unsigned caller)
{
	int e = errno;
	if (busy) { errno = e; return; }
	busy = 1;
	total++;
	int i, free_slot = -1;
	for (i = 0; i < SLOTS; i++) {
		if (slot[i].op == op && slot[i].fd == fd && slot[i].caller == caller) break;
		if (slot[i].op == NULL && free_slot < 0) free_slot = i;
	}
	if (i == SLOTS && free_slot >= 0) {
		i = free_slot;
		slot[i].op = op; slot[i].fd = fd; slot[i].caller = caller; slot[i].n = 0;
	}
	if (i < SLOTS) slot[i].n++;
	if (total <= 30) {
		unsigned c[6];
		int n = chain(c, 6, caller);
		say("[fdtrace] %s(fd %d) failed EBADF (#%lu); called from", op, fd, total);
		for (int k = 0; k < n; k++) say(" &%X", c[k]);
		say("\n");
	}
	clock_t now = clock();
	if (now - lastsum >= 2 * CLOCKS_PER_SEC) {
		lastsum = now;
		say("[fdtrace] %lu EBADF calls so far:", total);
		for (int k = 0; k < SLOTS; k++)
			if (slot[k].op) say(" %s(%d)@&%X x%lu;", slot[k].op, slot[k].fd, slot[k].caller, slot[k].n);
		say("\n");
	}
	busy = 0;
	errno = e;
}

#define RA ((unsigned)__builtin_return_address(0))
#define CHECK(op, fd, r) do { if ((r) < 0 && errno == EBADF) note(op, fd, RA); } while (0)

ssize_t __wrap_read(int fd, void *b, size_t n) { ssize_t r = __real_read(fd, b, n); CHECK("read", fd, r); return r; }
ssize_t __wrap_write(int fd, const void *b, size_t n) { ssize_t r = __real_write(fd, b, n); CHECK("write", fd, r); return r; }
int __wrap_close(int fd) { int r = __real_close(fd); CHECK("close", fd, r); return r; }
int __wrap_fstat(int fd, struct stat *s) { int r = __real_fstat(fd, s); CHECK("fstat", fd, r); return r; }
int __wrap_fcntl(int fd, int cmd, ...)
{
	va_list ap; va_start(ap, cmd); long a = va_arg(ap, long); va_end(ap);
	int r = __real_fcntl(fd, cmd, a); CHECK("fcntl", fd, r); return r;
}
int __wrap_isatty(int fd) { int r = __real_isatty(fd); if (r == 0 && errno == EBADF) note("isatty", fd, RA); return r; }
int __wrap_ioctl(int fd, unsigned long req, ...)
{
	va_list ap; va_start(ap, req); void *a = va_arg(ap, void *); va_end(ap);
	int r = __real_ioctl(fd, req, a); CHECK("ioctl", fd, r); return r;
}
int __wrap_select(int n, fd_set *r_, fd_set *w, fd_set *x, struct timeval *t) { int r = __real_select(n, r_, w, x, t); CHECK("select", n, r); return r; }
int __wrap_dup(int fd) { int r = __real_dup(fd); CHECK("dup", fd, r); return r; }
int __wrap_dup2(int fd, int to) { int r = __real_dup2(fd, to); CHECK("dup2", fd, r); return r; }
__off_t __wrap_lseek(int fd, __off_t o, int w) { __off_t r = __real_lseek(fd, o, w); CHECK("lseek", fd, r); return r; }
int __wrap_poll(struct pollfd *p, nfds_t n, int t) { int r = __real_poll(p, n, t); CHECK("poll", n > 0 ? p[0].fd : -1, r); return r; }
int __wrap_fsync(int fd) { int r = __real_fsync(fd); CHECK("fsync", fd, r); return r; }
