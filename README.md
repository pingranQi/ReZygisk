# VRMZygisk

VRMZygisk is an ARM64-only standalone Zygisk implementation based on ReZygisk.

## Supported environments

- KernelSU (including LKM late-load)
- APatch (normal boot stages)
- Android 7.1 or newer on ARM64 devices

Magisk is not supported. The module ID remains `rezygisk` to preserve existing module data and upgrade paths.

## Features

- Zygisk API implementation and module injection
- 64-bit Zygote only; the secondary 32-bit Zygote and Tango translator are intentionally not injected
- KernelSU LKM late-load through the module's `late-load.sh`
- Module-card status with monitor state and enabled Zygisk module names
- No WebUI

Late-load is KernelSU-specific. When KernelSU is injected after Android has booted, VRMZygisk restarts the existing 64-bit Zygote once so init can respawn it under the monitor. This restarts system_server and the Android framework.

## Install

1. Download the release ZIP from [GitHub Releases](https://github.com/pingranQi/VRMZygisk/releases).
2. Flash it from the KernelSU or APatch manager.
3. Reboot after a normal installation. For KernelSU LKM late-load, the module entry is invoked by KernelSU after injection.

The module manager checks updates through the project-owned release manifest.

## Build

Install Android NDK r30 and set `NDK_PATH`:

```sh
make all -j"$(nproc)"       # Debug and release
make release -j"$(nproc)"   # Release only
```

The build targets `arm64-v8a` only.

## License

AGPL-3.0. See [LICENSE](LICENSE).
