# ZeroTier-KSU

在 Android 设备上以系统级 TUN 模式运行 [ZeroTier](https://www.zerotier.com/) 虚拟网络，通过 KernelSU/APatch 内建 WebUI 管理。

## 版本说明

- 模块版本：独立维护，用于表示本仓库自身的功能与修复更新
- ZeroTier Core 版本：表示当前打包附带的 `zerotier-one` 上游版本，由仓库根目录的 `CORE_VERSION` 文件维护

## 功能

- 可配置的开机自动启动
- 命令行管理（start/stop/restart/status/enable/disable/join/leave）
- KernelSU/APatch WebUI 管理界面
  - 查看运行状态与节点信息（Node ID、版本、在线状态）
  - 网络管理：加入/离开网络，查看分配的 IP
  - Peer 列表实时查看（角色、延迟、路径、版本）
  - Planet 管理：上传自定义 planet 文件、一键恢复默认
  - Moon 管理：orbit/deorbit moon、上传 moon 文件
  - 开机自启动开关
  - 错误日志查看
- 兼容 Magisk、KernelSU、APatch 三大框架
- 重刷模块不会覆盖已有身份和网络配置

## 安装

1. 获取 `zerotier-one` 的 aarch64 静态编译二进制（见下方说明）
2. 将 `zerotier-one` 放入模块根目录
3. 打包为 zip，在 Magisk/KSU/APatch Manager 中刷入
4. 运行 `zerotier start` 启动服务
5. 运行 `zerotier join <network_id>` 加入网络

> ⚠ 首次安装会自动启用开机自启。你可以在 WebUI 或命令行中随时关闭。

### 获取 zerotier-one 二进制

ZeroTier 官方未提供 Android aarch64 的独立二进制，你需要自行编译或从社区获取：

- 使用 musl + aarch64 交叉编译工具链从 [ZeroTier 源码](https://github.com/zerotier/ZeroTierOne) 编译
- 从社区 Android 移植项目获取
- 确保是**静态链接**的可执行文件

## 管理

```bash
zerotier start    # 启动
zerotier stop     # 停止
zerotier restart  # 重启
zerotier status   # 查看运行状态、节点信息和已加入网络
zerotier enable   # 开启开机自启
zerotier disable  # 关闭开机自启
zerotier join <network_id>   # 加入网络
zerotier leave <network_id>  # 离开网络
```

KernelSU/APatch 用户可在 Manager 中打开模块 WebUI 进行管理。

KernelSU 用户在模块列表中可直接看到运行状态和 IP 信息。

## 数据目录

所有运行时数据存储在 `/data/adb/zerotier/`：

```
/data/adb/zerotier/
├── identity.public      # 节点公钥（自动生成）
├── identity.secret      # 节点私钥（自动生成）
├── authtoken.secret     # API 认证令牌（自动生成）
├── planet               # 自定义 planet 文件（可选）
├── autostart.conf       # 开机自启配置
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

## 兼容性

- Magisk ≥ v20.4
- KernelSU ≥ 0.6.7
- APatch
- Android ≥ 9 (API 28)
- arm64 设备

## License

本项目（模块脚本、WebUI 等）采用 [MIT License](LICENSE)。

`zerotier-one` 二进制由 CI 从 [ZeroTier 上游源码](https://github.com/zerotier/ZeroTierOne) 编译，受其 [BSL 1.1 许可证](https://github.com/zerotier/ZeroTierOne/blob/dev/LICENSE.txt) 约束。
