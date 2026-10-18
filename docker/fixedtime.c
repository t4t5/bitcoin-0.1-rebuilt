/* LD_PRELOAD shim: report a fixed wall-clock time, FIXED_TIME (seconds since
 * the epoch), to one process. Only the realtime clocks are changed; monotonic
 * clocks stay real, so Wine's waits and timeouts keep working. libfaketime
 * doesn't do here: Wine 8 reads CLOCK_REALTIME_COARSE, and faking the
 * wineserver's clock as well hangs it.
 *
 * Used for the build steps whose output embeds the time: cc1plus expanding
 * __DATE__/__TIME__, windres stamping resource directories, ld stamping the
 * PE header. Unset FIXED_TIME leaves the process alone. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

static int64_t fixed(void)
{
    const char *s = getenv("FIXED_TIME");
    return s ? strtoll(s, NULL, 10) : -1;
}

static int is_realtime(clockid_t c)
{
    return c == CLOCK_REALTIME || c == CLOCK_REALTIME_COARSE;
}

int clock_gettime(clockid_t c, struct timespec *ts)
{
    static int (*real)(clockid_t, struct timespec *);
    int64_t t = fixed();
    if (t >= 0 && is_realtime(c)) {
        ts->tv_sec = t;
        ts->tv_nsec = 0;
        return 0;
    }
    if (!real)
        real = dlsym(RTLD_NEXT, "clock_gettime");
    return real(c, ts);
}

/* 64-bit time_t entry points of 32-bit glibc */
struct timespec64 { int64_t tv_sec; int32_t tv_nsec; int32_t pad; };

int __clock_gettime64(clockid_t c, struct timespec64 *ts)
{
    static int (*real)(clockid_t, struct timespec64 *);
    int64_t t = fixed();
    if (t >= 0 && is_realtime(c)) {
        ts->tv_sec = t;
        ts->tv_nsec = 0;
        ts->pad = 0;
        return 0;
    }
    if (!real)
        real = dlsym(RTLD_NEXT, "__clock_gettime64");
    return real(c, ts);
}

int gettimeofday(struct timeval *tv, void *tz)
{
    static int (*real)(struct timeval *, void *);
    int64_t t = fixed();
    if (t >= 0) {
        if (tv) {
            tv->tv_sec = t;
            tv->tv_usec = 0;
        }
        return 0;
    }
    if (!real)
        real = dlsym(RTLD_NEXT, "gettimeofday");
    return real(tv, tz);
}

time_t time(time_t *out)
{
    static time_t (*real)(time_t *);
    int64_t t = fixed();
    if (t >= 0) {
        if (out)
            *out = (time_t)t;
        return (time_t)t;
    }
    if (!real)
        real = dlsym(RTLD_NEXT, "time");
    return real(out);
}
