# VRMZygisk

VRMZygisk 是基于 ReZygisk 的独立 Zygisk 实现，仅支持 ARM64。

## 支持范围

- KernelSU（包括 LKM late-load）
- APatch（标准启动阶段）
- Android 7.1 及以上的 ARM64 设备

不支持 Magisk。模块 ID 继续使用 `rezygisk`，以保留现有模块数据和原地升级路径。

## 功能

- Zygisk API 实现与模块注入
- 仅注入 64 位 Zygote；不注入次要的 32 位 Zygote 和 Tango translator
- 通过模块自身的 `late-load.sh` 支持 KernelSU LKM late-load
- 模块卡片显示 Monitor 状态和已启用的 Zygisk 模块列表
- 不包含 WebUI

Late-load 仅适用于 KernelSU。KernelSU 在 Android 启动完成后注入时，VRMZygisk 会重启一次现有的 64 位 Zygote，由 init 重新拉起并交给 monitor 注入。这会导致 system_server 和 Android Framework 重启。

## 安装

1. 从 [GitHub Releases](https://github.com/pingranQi/VRMZygisk/releases) 下载 Release ZIP。
2. 在 KernelSU 或 APatch 管理器中刷入。
3. 标准安装后重启设备。KernelSU LKM late-load 模式下，KernelSU 注入后会自动调用模块入口。

模块更新检查使用本项目自己的 Release 更新清单。

## 构建

安装 Android NDK r30 并设置 `NDK_PATH`：

```sh
make all -j"$(nproc)"       # Debug 和 Release
make release -j"$(nproc)"   # 仅 Release
```

构建目标仅为 `arm64-v8a`。

## 许可证

AGPL-3.0，详见 [LICENSE](LICENSE)。
