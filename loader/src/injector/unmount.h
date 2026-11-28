#ifndef UNMOUNT_H
#define UNMOUNT_H

#include <stdbool.h>
#include <stdint.h>

/* Revert root-related mounts in the calling process's private mount namespace.
   False means the caller must use the cached clean namespace fallback. */
bool revert_mode_enabled(void);
bool revert_root_traces_here(uint32_t root_flags);

/* Refresh bionic's cached mount line after the namespace has been cleaned. */
bool refresh_mount_line(void);

#endif /* UNMOUNT_H */
