#include <errno.h>
#include <mntent.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/mount.h>
#include <sys/stat.h>

#include "logging.h"
#include "module.h"
#include "unmount.h"

#define ROOT_MODULES_ROOT "/adb/modules"
#define ROOT_MODULES_DIR "/data/adb/modules"
#define MODULE_DIR "/data/adb/modules/rezygisk"
#define TEMP_DIR "/data/adb/rezygisk"
#define PRODUCT_MOUNT "/product"

struct mount_entry {
  unsigned int id;
  char *root;
  char *target;
  char *source;
};

struct mount_list {
  struct mount_entry *items;
  size_t len;
  size_t cap;
};

static void mount_list_free(struct mount_list *list) {
  for (size_t i = 0; i < list->len; i++) {
    free(list->items[i].root);
    free(list->items[i].target);
    free(list->items[i].source);
  }

  free(list->items);
  memset(list, 0, sizeof(*list));
}

static bool mount_list_reserve(struct mount_list *list, size_t wanted) {
  if (list->cap >= wanted) return true;

  size_t cap = list->cap ? list->cap * 2 : 16;
  if (cap < wanted) cap = wanted;

  struct mount_entry *items = realloc(list->items, cap * sizeof(*items));
  if (items == NULL) {
    PLOGE("allocate mountinfo entries");
    return false;
  }

  list->items = items;
  list->cap = cap;
  return true;
}

static bool path_at_or_under(const char *path, const char *prefix) {
  size_t len = strlen(prefix);
  return strncmp(path, prefix, len) == 0 && (path[len] == '\0' || path[len] == '/');
}

static bool parse_mount_line(char *line, struct mount_entry *out) {
  char *separator = strstr(line, " - ");
  if (separator == NULL) return false;
  *separator = '\0';

  char *save = NULL;
  char *field = strtok_r(line, " ", &save);
  if (field == NULL) return false;

  char *end = NULL;
  unsigned long id = strtoul(field, &end, 10);
  if (end == field || *end != '\0' || id > UINT_MAX) return false;

  /* mountinfo fields: id parent major:minor root mountpoint ... */
  for (int i = 1; i < 4; i++) {
    field = strtok_r(NULL, " ", &save);
    if (field == NULL) return false;
  }
  char *root = field;

  char *target = strtok_r(NULL, " ", &save);
  if (target == NULL) return false;

  save = NULL;
  (void)strtok_r(separator + 3, " ", &save); /* filesystem type */
  char *source = strtok_r(NULL, " ", &save);
  if (source == NULL) return false;

  out->id = (unsigned int)id;
  out->root = strdup(root);
  out->target = strdup(target);
  out->source = strdup(source);
  if (out->root == NULL || out->target == NULL || out->source == NULL) {
    free(out->root);
    free(out->target);
    free(out->source);
    memset(out, 0, sizeof(*out));
    PLOGE("copy mountinfo entry");
    return false;
  }

  return true;
}

static bool mount_list_parse(struct mount_list *out) {
  FILE *file = fopen("/proc/self/mountinfo", "re");
  if (file == NULL) {
    PLOGE("open /proc/self/mountinfo");
    return false;
  }

  char *line = NULL;
  size_t capacity = 0;
  bool ok = true;

  while (getline(&line, &capacity, file) > 0) {
    struct mount_entry entry = { 0 };
    if (!parse_mount_line(line, &entry)) continue;

    if (!mount_list_reserve(out, out->len + 1)) {
      free(entry.root);
      free(entry.target);
      free(entry.source);
      ok = false;
      break;
    }

    out->items[out->len++] = entry;
  }

  free(line);
  fclose(file);
  return ok;
}

static const char *find_ksu_loop_source(const struct mount_list *all) {
  for (size_t i = 0; i < all->len; i++) {
    const struct mount_entry *entry = &all->items[i];
    if (strcmp(entry->target, ROOT_MODULES_DIR) != 0) continue;
    if (strncmp(entry->source, "/dev/block/loop", sizeof("/dev/block/loop") - 1) != 0) continue;
    return entry->source;
  }

  return NULL;
}

static bool carries_root_trace(const struct mount_entry *entry, uint32_t root_flags,
                               const char *ksu_loop_source) {
  if (path_at_or_under(entry->root, ROOT_MODULES_ROOT)) return true;
  if (path_at_or_under(entry->target, ROOT_MODULES_DIR)) return true;

  if ((root_flags & PROCESS_ROOT_IS_KSU) && strcmp(entry->source, "KSU") == 0) return true;
  if ((root_flags & PROCESS_ROOT_IS_APATCH) &&
      (strcmp(entry->source, "APatch") == 0 || strcmp(entry->source, "kpatch") == 0)) return true;

  return ksu_loop_source != NULL && strcmp(entry->source, ksu_loop_source) == 0;
}

static int compare_mount_id_desc(const void *left, const void *right) {
  const struct mount_entry *a = left;
  const struct mount_entry *b = right;
  if (a->id == b->id) return 0;
  return a->id > b->id ? -1 : 1;
}

bool revert_mode_enabled(void) {
  struct stat st;
  return stat(TEMP_DIR "/disable-revert", &st) != 0 &&
         stat(MODULE_DIR "/disable-revert", &st) != 0;
}

bool revert_root_traces_here(uint32_t root_flags) {
  struct mount_list all = { 0 };
  if (!mount_list_parse(&all)) {
    mount_list_free(&all);
    return false;
  }

  const char *loop_source = (root_flags & PROCESS_ROOT_IS_KSU) ? find_ksu_loop_source(&all) : NULL;
  struct mount_list traces = { 0 };
  bool ok = true;

  for (size_t i = 0; i < all.len; i++) {
    if (!carries_root_trace(&all.items[i], root_flags, loop_source)) continue;

    if (!mount_list_reserve(&traces, traces.len + 1)) {
      ok = false;
      break;
    }

    traces.items[traces.len++] = all.items[i];
    memset(&all.items[i], 0, sizeof(all.items[i]));
  }

  mount_list_free(&all);
  if (!ok) {
    mount_list_free(&traces);
    return false;
  }

  for (size_t i = 0; i < traces.len; i++) {
    if (strcmp(traces.items[i].target, PRODUCT_MOUNT) == 0) {
      LOGW("Refusing in-place mount revert: exact %s mount is present", PRODUCT_MOUNT);
      mount_list_free(&traces);
      return false;
    }
  }

  qsort(traces.items, traces.len, sizeof(*traces.items), compare_mount_id_desc);

  bool complete = true;
  for (size_t i = 0; i < traces.len; i++) {
    const struct mount_entry *entry = &traces.items[i];
    if (umount2(entry->target, MNT_DETACH) == 0) {
      LOGV("Reverted mount %s (id %u)", entry->target, entry->id);
    } else {
      LOGW("Failed to detach mount %s (id %u): %s",
           entry->target, entry->id, strerror(errno));
      complete = false;
    }
  }

  mount_list_free(&traces);
  return complete;
}

bool refresh_mount_line(void) {
  FILE *mounts = setmntent("/proc/self/mounts", "r");
  if (mounts == NULL) {
    PLOGE("open /proc/self/mounts");
    return false;
  }

  size_t lines = 0;
  while (getmntent(mounts) != NULL) lines++;
  endmntent(mounts);

  if (lines == 0) {
    LOGE("/proc/self/mounts has no entries");
    return false;
  }

  return true;
}
