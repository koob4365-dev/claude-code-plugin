# 03 重新登录 AI 工具

9 月 2 日的"隔离"脚本把这些登录凭据搬走了，所以工具打开就要求登录。这不是网络问题。
凭据重新登录就会生成，不需要从隔离文件夹搬回来。

## 前提

`00-check.ps1` 第 5 项里 `https://api.anthropic.com` 和 `https://api.openai.com` 要能返回数字。
返回"超时/失败"而 google 能通，说明命令行程序需要走代理。先在同一个 PowerShell 窗口里设：

```powershell
$env:HTTPS_PROXY = "http://127.0.0.1:端口"
$env:HTTP_PROXY  = "http://127.0.0.1:端口"
```

端口看你 VPN 软件的设置页，常见是 7890 或 1080。只对当前窗口生效，关了就没了。

## Claude Code

```powershell
claude
```

进去后输入 `/login`，浏览器会打开，登录后回到终端。
成功后 `C:\Users\KYH\.claude\.credentials.json` 会重新出现。

## Codex

```powershell
codex login
```

浏览器登录。成功后 `C:\Users\KYH\.codex\auth.json` 会重新出现。

## VS Code 的 GitHub

打开 VS Code，左下角账户图标 → 使用 GitHub 登录。
这会重新创建 Windows 凭据管理器里的 `GitHub - https://api.github.com/koob4365-dev` 条目，那个条目是正常的，不要再删。

## GitHub CLI（如果装了）

```powershell
gh auth login
```

## 验证

再跑一次 `00-check.ps1`，第 9 项两个文件都应显示"存在（已登录）"。
