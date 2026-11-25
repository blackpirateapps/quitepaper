// Isolated process clock shim: only wall-clock time moves; monotonic time does not.
// QP_AUDIT_CLOCK_FILE contains a signed offset in seconds; absent/empty means zero.
// Build: cc -shared -fPIC clock_shift.c -o /tmp/qp-clock-shift.so -ldl
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <time.h>

static long long shift_seconds(void) {
  const char *path = getenv("QP_AUDIT_CLOCK_FILE");
  if (!path) return 0;
  FILE *stream = fopen(path, "r");
  if (!stream) return 0;
  long long seconds = 0;
  if (fscanf(stream, "%lld", &seconds) != 1) seconds = 0;
  fclose(stream);
  return seconds;
}

int clock_gettime(clockid_t clock_id, struct timespec *value) {
  static int (*real_clock_gettime)(clockid_t, struct timespec *);
  if (!real_clock_gettime) real_clock_gettime = dlsym(RTLD_NEXT, "clock_gettime");
  const int result = real_clock_gettime(clock_id, value);
  if (result == 0 && clock_id == CLOCK_REALTIME) value->tv_sec += shift_seconds();
  return result;
}

int gettimeofday(struct timeval *value, void *zone) {
  static int (*real_gettimeofday)(struct timeval *, void *);
  if (!real_gettimeofday) real_gettimeofday = dlsym(RTLD_NEXT, "gettimeofday");
  const int result = real_gettimeofday(value, zone);
  if (result == 0) value->tv_sec += shift_seconds();
  return result;
}

time_t time(time_t *destination) {
  struct timespec value;
  if (clock_gettime(CLOCK_REALTIME, &value) != 0) return (time_t)-1;
  if (destination) *destination = value.tv_sec;
  return value.tv_sec;
}
