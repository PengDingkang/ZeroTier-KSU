# ZeroTier-KSU

在 Android 设备上以系统级 TUN 模式运行 [ZeroTier](https://www.zerotier.com/) 虚拟网络，通过 KernelSU/APatch 内建 WebUI 管理。

## 升级注意：命令挂载默认关闭

**首次安装或从没有保存过挂载选项的旧版升级后，默认不再将命令挂载到 `/system/bin`。重启后生效。**
已经保存过挂载选择的用户会保留原值。隧道、WebUI 和开机自启使用数据目录下的工具，
无需系统目录挂载或元模块。现有配置和身份数据会保留。

在 Root shell 中使用完整路径 `/data/adb/zerotier/zerotier` 管理服务，
并更新自行编写的脚本中依赖短命令的调用。需要恢复短命令时，在 WebUI 的
**Shell Command Mount** 中开启挂载并重启设备；KernelSU 下需要可用的挂载元模块。

## 版本说明

- 模块版本：独立维护，用于表示本仓库自身的功能与修复更新
- ZeroTier Core 版本：表示当前打包附带的 `zerotier-one` 上游版本，由仓库根目录的 `CORE_VERSION` 文件维护

当前模块版本为 `v1.1.0`，附带 ZeroTier Core `1.16.2`；上游标签解析后的提交锁定在 `CORE_COMMIT` 中。

## 功能

- 可配置的开机自动启动
- 命令行管理（start/stop/restart/status/enable/disable/join/leave/mount）
- KernelSU/APatch WebUI 管理界面
  - 查看运行状态与节点信息（Node ID、版本、在线状态）
  - 网络管理：加入/离开网络，查看分配的 IP
  - Peer 列表实时查看（角色、延迟、路径、版本）
  - Planet 管理：上传自定义 planet 文件、一键恢复默认
  - Moon 管理：orbit/deorbit moon、上传 moon 文件
  - 开机自启动开关
  - 可选的 Shell 命令挂载开关（默认关闭）
  - 错误日志查看
- 兼容 Magisk、KernelSU、APatch 三大框架
- 重刷模块不会覆盖已有身份和网络配置

## 安装

1. 从 [Releases](../../releases) 下载 zip（已包含编译好的 `zerotier-one`）
2. 在 Magisk/KSU/APatch Manager 中刷入
3. 在 Root shell 中运行 `/data/adb/zerotier/zerotier start` 启动服务，安装或升级后重启设备以应用挂载设置
4. 运行 `/data/adb/zerotier/zerotier join <network_id>` 加入网络（或在 WebUI 中操作）

> ⚠ 首次安装会自动启用开机自启。你可以在 WebUI 或命令行中随时关闭。

## 管理

以下命令在 Root shell 中执行（先运行 `su`），完整路径不依赖命令挂载。

```bash
/data/adb/zerotier/zerotier start    # 启动
/data/adb/zerotier/zerotier stop     # 停止
/data/adb/zerotier/zerotier restart  # 重启
/data/adb/zerotier/zerotier status   # 查看运行状态、节点信息和已加入网络
/data/adb/zerotier/zerotier enable   # 开启开机自启
/data/adb/zerotier/zerotier disable  # 关闭开机自启
/data/adb/zerotier/zerotier join <network_id>   # 加入网络
/data/adb/zerotier/zerotier leave <network_id>  # 离开网络
```

KernelSU/APatch 用户可在 Manager 中打开模块 WebUI 进行管理。

KernelSU 用户在模块列表中可直接看到运行状态和 IP 信息。


### 可选的 Shell 命令挂载

**Shell Command Mount** 仅控制是否将命令放进系统命令路径，方便在终端输入短命令；
关闭时 ZeroTier 的现有服务和 WebUI 功能仍可用。切换后需要重启设备，升级会保留已保存的选择。
默认不生成 `system/bin` 副本；开启时按需生成，关闭并重启后只保留私有工具及数据目录中的 CLI/idtool 软链接。
升级尚未重启时修改开关，也会同步更新暂存模块。

KernelSU 下会检查已启用、未标记移除且带有 `metamount.sh` 的元模块；缺少挂载能力时，
WebUI 开关禁用并显示原因，CLI 也会拒绝开启。Magisk/APatch 使用其内置挂载能力。
如果另外在 MMRS 中禁止了该模块挂载，还需要在那里允许挂载。

```sh
/data/adb/zerotier/zerotier mount status     # 下次启动的挂载设置：1 开启，0 关闭
/data/adb/zerotier/zerotier mount supported  # 是否有可用的挂载能力：1 支持，0 不支持
/data/adb/zerotier/zerotier mount enable     # 开启，重启生效
/data/adb/zerotier/zerotier mount disable    # 关闭，重启生效
```

`mount status` 是保存的设置，不代表当前已完成挂载。选择保存在
`/data/adb/zerotier/mount_enabled` 中；默认不挂载通过模块的 `skip_mount` 标记实现。

启动服务时使用独立优先级 `1002` 的 `main` 路由规则；停止时只清理该规则，保留 WG 和其他模块的路由策略。

## 数据目录

所有运行时数据存储在 `/data/adb/zerotier/`：

```
/data/adb/zerotier/
├── identity.public      # 节点公钥（自动生成）
├── identity.secret      # 节点私钥（自动生成）
├── authtoken.secret     # API 认证令牌（自动生成）
├── planet               # 自定义 planet 文件（可选）
├── autostart.conf       # 开机自启配置
├── mount_enabled        # 下次启动的命令挂载选择（1/0）
├── zerotier-cli         # 指向本目录 zerotier-one 的入口
├── zerotier-idtool      # 指向本目录 zerotier-one 的入口
├── error.log            # 错误日志
├── networks.d/          # 已加入的网络
│   └── <network_id>.conf
└── moons.d/             # Moon 文件
    └── <moon_id>.moon
```

> 卸载模块时不会删除此目录，以保留身份和网络配置。

## Planet & Moon

### 自定义 Planet

将自定义 `planet` 文件放到 `/data/adb/zerotier/planet`，然后重启服务。也可以通过 WebUI 上传。

删除该文件即恢复使用 ZeroTier 内置的默认 planet。

### Moon

通过 WebUI 或命令行管理 moon：

- WebUI：输入 Moon ID 点击 Orbit，或上传 `.moon` 文件
- 命令行：将 `.moon` 文件放到 `/data/adb/zerotier/moons.d/`，重启服务

## 核心来源与构建

构建及发布共用 `scripts/ci/build-core.sh`。`CORE_VERSION` 指定上游版本，`CORE_COMMIT`
固定该标签解析后的完整提交；脚本明确拉取 `refs/tags/<版本>`，核对提交一致后才编译，避免误取同名分支。

保持 ARM64 静态嵌入式构建，显式指定 `ZT_SSO_SUPPORTED=0`、`ZT_CONTROLLER=0`，不再用
`sed` 修改上游 Makefile。生成后检查 ARM64 静态 ELF 格式，并写入缓存校验文件。

缓存键包含版本、源码提交、构建脚本、编译器/strip 版本、静态库哈希和外部编译/链接参数。
构建和发布共用 `.cache/core/`；复用前校验二进制 SHA256 和架构，不在 Git 中保存生成的核心。
两个 CI 流程固定使用 Ubuntu 24.04，工具链变化仍会导致缓存失效。

本地需要 Git、make、`file`、`sha256sum` 和 `g++-aarch64-linux-gnu`；验证还需要 ShellCheck 和 Python 3：

```sh
sh scripts/ci/validate.sh
sh scripts/ci/build-core.sh
sh scripts/ci/build-core.sh --cache-key
```

升级核心时同时更新 `CORE_VERSION` 与 `CORE_COMMIT`，并核对标签提交、静态编译和 Android 实机兼容性。
模块安装包内已包含核心，手机安装时无需编译或下载核心；`zerotier-cli` / `zerotier-idtool`
是指向同一份 `zerotier-one` 的软链接，不额外存储核心副本。

## 兼容性

- Magisk ≥ v20.4
- KernelSU ≥ 0.6.7
- APatch
- Android ≥ 9 (API 28)
- arm64 设备

## 发布与更新元数据

准备新版本时更新模块版本、核心锁定文件和 changelog，**不要提前把 `update.json` 改为尚未发布的版本**。
该文件只表示最近一次已成功发布并验证的稳定版，由 Release Action 维护。

发布顺序为：构建/检查 → 创建 Release 并上传 ZIP → 无认证访问公开下载链接，核对 ZIP 大小和 SHA256
与本地发布包一致 → 从包内 `module.prop` 生成元数据 → 更新默认分支的 `update.json`。
更新日志链接固定到该 Release 标签，避免后续文档变动与已发布版本不一致。

上传失败、公开链接不可用或内容不匹配时，稳定版元数据不会更新；预发布也不会覆盖它。
元数据通过独立的最新分支检出推送，遇到并发提交会重试，不会用旧版本覆盖更高的版本号。
Release 流程按仓库串行执行。首次正式发布之前可以没有 `update.json`，首发验证成功后会自动创建。

## License

本项目（模块脚本、WebUI 等）采用 [MIT License](LICENSE)。

`zerotier-one` 二进制由 CI 从 [ZeroTier 上游源码](https://github.com/zerotier/ZeroTierOne) 编译，受其 [BSL 1.1 许可证](https://github.com/zerotier/ZeroTierOne/blob/dev/LICENSE.txt) 约束。
