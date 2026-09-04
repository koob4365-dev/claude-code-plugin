# Windows 修复脚本包（KYH 的机器）

给一台 Windows 11 25H2（HP，i5-14500，32 GB，BitLocker 开启）用的最小修复脚本。
只用 Windows 自带命令，不装任何东西，不重复造轮子。

## 三条铁律

1. **默认只读。** 每个脚本不加参数时只显示状态，不改任何东西。
2. **改动要显式。** 只有加了 `-Apply` 才会动手，动手的每一步都打印出来。
3. **不删除，只记录。** 没有一条删除命令。所有输出都记到 `桌面\repair-logs\`。

## 拿到脚本

网络恢复后，在 PowerShell 里：

```powershell
cd $env:USERPROFILE\Desktop
git clone -b claude/disk-cleanup-cache-issues-ku6t9g https://github.com/koob4365-dev/claude-code-plugin repair
cd repair\tools\windows-repair
```

没有 git 的话，在 GitHub 网页上打开这个分支，Code → Download ZIP，解压后进入 `tools\windows-repair`。

## 运行顺序

所有 `.ps1` 都这样运行（以管理员身份打开 PowerShell）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\00-check.ps1
```

`.cmd` 文件右键 → 以管理员身份运行。

| 步骤 | 文件 | 做什么 | 会改东西吗 |
|---|---|---|---|
| 0 | 先重启电脑一次 | 大多数网卡问题重启就好 | 否 |
| 1 | `00-check.ps1` | 全面体检：网卡、网关、代理、连通性、hosts、R: 盘、BitLocker、AI 登录状态、空间大头 | 否 |
| 2 | `01-network.ps1 -Apply` | 启用被禁的物理网卡、DHCP 续租、清 DNS。还不行加 `-Reset` 后重启 | 是 |
| 3 | `02-hide-recovery.cmd` | 去掉恢复分区的 R: 盘符，确认恢复环境仍启用 | 是 |
| 4 | `03-relogin.md` | 照着重新登录 Claude Code、Codex、VS Code GitHub | 手动 |
| 5 | `03-space.ps1 -Apply` | 关休眠文件、WSL 不再生成交换盘、打开系统磁盘清理 | 是 |
| 6 | `driver_store_cleanup.cmd` | 可选。清理驱动仓库旧包，前后快照对比，不强制重启 | 是 |

每一步跑完，把 `桌面\repair-logs\` 里对应的文件发给 Claude 看。

## 什么时候停下来问

- `00-check.ps1` 显示 BitLocker 已开启，而你在 aka.ms/myrecoverykey 找不到恢复密钥：**先别动分区和固件**，先把密钥存好。
- `01-network.ps1` 显示有一块 TAP / TUN / Wintun 网卡处于 Up 状态且没有网关：那是 VPN 软件的网卡在抢路由，禁用它或关掉 VPN 软件。
- 任何脚本报错：把 `repair-logs` 里的文件发过来，不要自己换别的脚本继续跑。

## 不做什么

- 不重置系统。已经重置过很多次，问题不在系统镜像里。
- 不扫描"可疑关键词"。之前的审计脚本用 default、cache、session 这类词当特征，扫出上千条全是误报。
- 不动注册表。
- 不碰 `ai-skill-audit\quarantine-*` 里隔离的文件。要恢复的话是搬回去，不是删。
