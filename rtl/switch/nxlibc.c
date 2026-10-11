/* Free Pascal's libnx/newlib bridge. See COPYING.FPC for the RTL license.
 * SDK structs stay in C; Pascal uses fixed-width values and opaque handles. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fnmatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <switch.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <utime.h>

int fpc_nx_argc;
char **fpc_nx_argv;
int fpc_nx_errno(void) { return errno; }
void fpc_nx_seterrno(int value) { errno = value; }
int fpc_nx_unsupported(void) {
  errno = ENOSYS;
  return -1;
}
/* DOS/System IO errors are not newlib errno values. Keep this translation
 * shared by the low-level System file API and the compatibility Dos unit. */
uint16_t fpc_nx_doserror(void) {
  switch (errno) {
  case 0:
    return 0;
  case ENOENT:
    return 2;
  case ENOTDIR:
  case ENAMETOOLONG:
    return 3;
  case ENFILE:
  case EMFILE:
    return 4;
  case EACCES:
  case EPERM:
  case EEXIST:
  case EISDIR:
  case ENOTEMPTY:
  case EBUSY:
  case EROFS:
    return 5;
  case EBADF:
    return 6;
  case ENOMEM:
    return 8;
  case ENODEV:
    return 15;
  case EXDEV:
    return 17;
  case EINVAL:
  case ENOSYS:
    return 1;
  default:
    return 101;
  }
}
int fpc_nx_envcount(void) {
  extern char **environ;
  int count = 0;
  if (environ)
    while (environ[count])
      ++count;
  return count;
}
const char *fpc_nx_envstr(int index) {
  extern char **environ;
  if (index < 1 || index > fpc_nx_envcount())
    return NULL;
  return environ[index - 1];
}
int fpc_nx_open(const char *path, int mode, int create) {
  static const int modes[] = {O_RDONLY, O_WRONLY, O_RDWR};
  if (mode < 0 || mode > 2) {
    errno = EINVAL;
    return -1;
  }
  int flags = modes[mode];
  if (create == 1)
    flags |= O_CREAT | O_TRUNC;
  if (create == 2)
    flags |= O_APPEND;
  return open(path, flags, 0666);
}
static int file_attributes(const struct stat *st, const char *name) {
  int attr = S_ISDIR(st->st_mode) ? 16 : 32;
  if (!(st->st_mode & S_IWUSR))
    attr |= 1;
  const char *base = name ? strrchr(name, '/') : NULL;
  base = base ? base + 1 : name;
  if (base && base[0] == '.' && strcmp(base, ".") && strcmp(base, ".."))
    attr |= 2;
  return attr;
}
int fpc_nx_fileinfo(const char *path, int fd, int64_t *size, int64_t *stamp) {
  struct stat st;
  if ((path ? stat(path, &st) : fstat(fd, &st)) < 0)
    return -1;
  *size = st.st_size;
  *stamp = st.st_mtime;
  return file_attributes(&st, path);
}
int fpc_nx_setdate(const char *path, int fd, int64_t stamp) {
  if (path) {
    struct utimbuf t = {stamp, stamp};
    return utime(path, &t);
  }
  (void)fd;
  return fpc_nx_unsupported();
}
uint64_t fpc_nx_ticks(void) {
  return armTicksToNs(armGetSystemTick()) / 1000000;
}
void fpc_nx_sleep(uint32_t ms) { svcSleepThread((int64_t)ms * 1000000); }
int fpc_nx_systemtime(int local, uint16_t *out) {
  struct timeval tv;
  struct tm tm;
  memset(out, 0, 8 * sizeof(*out));
  if (gettimeofday(&tv, NULL) < 0 ||
      !(local ? localtime_r(&tv.tv_sec, &tm) : gmtime_r(&tv.tv_sec, &tm)))
    return -1;
  out[0] = tm.tm_year + 1900;
  out[1] = tm.tm_mon + 1;
  out[2] = tm.tm_mday;
  out[3] = tm.tm_wday;
  out[4] = tm.tm_hour;
  out[5] = tm.tm_min;
  out[6] = tm.tm_sec;
  out[7] = tv.tv_usec / 1000;
  return 0;
}
int64_t fpc_nx_diskspace(int free_space) {
  struct statvfs st;
  if (statvfs("sdmc:/", &st) < 0)
    return -1;
  return (int64_t)(free_space ? st.f_bavail : st.f_blocks) * st.f_frsize;
}
typedef struct {
  DIR *dir;
  char *directory;
  char *pattern;
} NxFind;
void fpc_nx_findclose(NxFind *find) {
  if (!find)
    return;
  if (find->dir)
    closedir(find->dir);
  free(find->directory);
  free(find->pattern);
  free(find);
}
NxFind *fpc_nx_findopen(const char *path) {
  NxFind *find = calloc(1, sizeof(*find));
  if (!find)
    return NULL;
  const char *slash = strrchr(path, '/');
  find->directory = slash ? strndup(path, slash - path + 1) : strdup("./");
  find->pattern = strdup(slash ? slash + 1 : path);
  if (!find->directory || !find->pattern ||
      !(find->dir = opendir(find->directory))) {
    fpc_nx_findclose(find);
    return NULL;
  }
  return find;
}
int fpc_nx_findnext(NxFind *find, char *name, size_t capacity, int64_t *size,
                    int64_t *stamp) {
  struct dirent *entry;
  while ((entry = readdir(find->dir))) {
    if (fnmatch(find->pattern, entry->d_name, 0))
      continue;
    if (strlen(entry->d_name) >= capacity) {
      errno = ENAMETOOLONG;
      return -1;
    }
    char *path = malloc(strlen(find->directory) + strlen(entry->d_name) + 1);
    if (!path)
      return -1;
    strcpy(path, find->directory);
    strcat(path, entry->d_name);
    int attr = fpc_nx_fileinfo(path, -1, size, stamp);
    free(path);
    if (attr < 0)
      continue;
    strcpy(name, entry->d_name);
    return attr;
  }
  return -1;
}

int64_t fpc_nx_epoch_from_parts(int local, uint16_t y, uint16_t m, uint16_t d,
                                uint16_t h, uint16_t n, uint16_t s) {
  struct tm tm = {.tm_year = y - 1900,
                  .tm_mon = m - 1,
                  .tm_mday = d,
                  .tm_hour = h,
                  .tm_min = n,
                  .tm_sec = s,
                  .tm_isdst = -1};
  if (local)
    return mktime(&tm);
  int year = y - (m <= 2);
  int era = (year >= 0 ? year : year - 399) / 400;
  unsigned yoe = year - era * 400;
  unsigned doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
  unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  int64_t days = (int64_t)era * 146097 + doe - 719468;
  return days * 86400 + h * 3600 + n * 60 + s;
}
void fpc_nx_epoch_to_parts(int local, int64_t epoch, uint16_t *y, uint16_t *m,
                           uint16_t *d, uint16_t *h, uint16_t *n, uint16_t *s) {
  time_t t = epoch;
  struct tm tm;
  if (local)
    localtime_r(&t, &tm);
  else
    gmtime_r(&t, &tm);
  *y = tm.tm_year + 1900;
  *m = tm.tm_mon + 1;
  *d = tm.tm_mday;
  *h = tm.tm_hour;
  *n = tm.tm_min;
  *s = tm.tm_sec;
}

/* FPC offsets are minutes west of UTC, including the DST at this instant. */
int fpc_nx_timeoffset(int64_t epoch, int *offset, int *isdst) {
  time_t t = epoch;
  struct tm tm;
  *offset = 0;
  *isdst = 0;
  if (!localtime_r(&t, &tm))
    return -1;
  int64_t local_wall_time =
      fpc_nx_epoch_from_parts(0, tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                              tm.tm_hour, tm.tm_min, tm.tm_sec);
  *offset = (epoch - local_wall_time) / 60;
  *isdst = tm.tm_isdst > 0;
  return 0;
}
