# 00-check.ps1 —— 只读体检。不改任何设置。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\00-check.ps1
# 建议以管理员身份运行，否则 reagentc / manage-bde 两项会报权限错误，其余照常。

$ErrorActionPreference = "Continue"
$LogDir = Join-Path $env:USERPROFILE "Desktop\repair-logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $LogDir "00-check-$Stamp.txt"
Start-Transcript -Path $LogFile | Out-Null

function Section($Title) {
    Write-Host ""
    Write-Host "===== $Title =====" -ForegroundColor Cyan
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "管理员权限: $IsAdmin"
Write-Host "时间: $(Get-Date)"
Write-Host "系统: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"

Section "1. 网卡状态"
Get-NetAdapter | Sort-Object Status | Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize

Section "2. 有默认网关的网卡（真正能上网的那块）"
$WithGateway = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
if ($WithGateway) {
    $WithGateway | Format-Table InterfaceAlias,
        @{ n = "IPv4"; e = { ($_.IPv4Address | ForEach-Object { $_.IPAddress }) -join "," } },
        @{ n = "网关"; e = { ($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join "," } },
        @{ n = "DNS"; e = { ($_.DNSServer | ForEach-Object { $_.ServerAddresses }) -join "," } } -AutoSize
} else {
    Write-Host "没有任何网卡有默认网关。这就是 ping 报“传输失败，常见故障”的原因。" -ForegroundColor Yellow
    Write-Host "下一步：重启；仍无网关则运行 01-network.ps1 -Apply" -ForegroundColor Yellow
}

Section "3. 处于 Up 但没有网关的网卡（VPN/TUN/虚拟网卡会出现在这里，正常）"
Get-NetIPConfiguration | Where-Object { -not $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq "Up" } |
    Format-Table InterfaceAlias, InterfaceDescription -AutoSize

Section "4. 代理设置"
netsh winhttp show proxy
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
    Select-Object ProxyEnable, ProxyServer, AutoConfigURL | Format-List
$ProxyEnv = Get-ChildItem Env: | Where-Object { $_.Name -match "proxy" }
if ($ProxyEnv) { $ProxyEnv | Format-Table Name, Value -AutoSize } else { Write-Host "没有代理环境变量。" }

Section "5. 连通性测试（每个 10 秒超时；数字是 HTTP 状态码，能返回数字就是通的）"
foreach ($Url in "https://www.google.com", "https://github.com", "https://api.anthropic.com", "https://api.openai.com") {
    $Code = & curl.exe -s -o NUL -w "%{http_code}" --max-time 10 $Url 2>$null
    if (-not $Code -or $Code -eq "000") { $Code = "超时/失败" }
    Write-Host ("{0,-30} {1}" -f $Url, $Code)
}
Write-Host "解读：google 通、anthropic 和 openai 失败 = 地区封锁，命令行程序需要走系统级代理。"

Section "6. hosts 文件（去掉注释后的内容）"
$HostsLines = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() }
if ($HostsLines) { $HostsLines } else { Write-Host "hosts 没有自定义条目，正常。" }

Section "7. 恢复分区盘符"
if (Test-Path "R:\") {
    Write-Host "R: 存在。恢复分区被挂了盘符，运行 02-hide-recovery.cmd 处理。" -ForegroundColor Yellow
} else {
    Write-Host "R: 不存在，正常。"
}
reagentc /info 2>&1

Section "8. BitLocker 状态（务必确认 aka.ms/myrecoverykey 里有密钥）"
manage-bde -status C: 2>&1

Section "9. AI 工具登录状态"
foreach ($Path in "$env:USERPROFILE\.claude\.credentials.json", "$env:USERPROFILE\.codex\auth.json") {
    $State = if (Test-Path $Path) { "存在（已登录）" } else { "不存在（需要重新登录，见 03-relogin.md）" }
    Write-Host ("{0,-48} {1}" -f $Path, $State)
}
if (Get-Command gh -ErrorAction SilentlyContinue) { gh auth status 2>&1 } else { Write-Host "gh 未安装。" }

Section "10. telegram-repair-bridge 是否装到了本机"
Write-Host ("数据目录存在: " + (Test-Path "$env:LOCALAPPDATA\TelegramRepairBridge"))
$Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "trb|telegram|repair" }
if ($Tasks) { $Tasks | Select-Object TaskName, State | Format-Table -AutoSize } else { Write-Host "没有相关计划任务。" }
$Services = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "trb|telegram|repair" }
if ($Services) { $Services | Select-Object Name, Status | Format-Table -AutoSize } else { Write-Host "没有相关服务。" }

Section "11. 空间大头"
function Show-Size($Path) {
    if (Test-Path -LiteralPath $Path) {
        $Bytes = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        if (-not $Bytes) { $Bytes = 0 }
        Write-Host ("{0,8:N1} GB  {1}" -f ($Bytes / 1GB), $Path)
    } else {
        Write-Host ("{0,8}     {1}  (不存在)" -f "-", $Path)
    }
}
foreach ($Path in "$env:SystemDrive\hiberfil.sys",
                  "$env:SystemDrive\pagefile.sys",
                  "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc",
                  "$env:APPDATA\Claude",
                  "$env:LOCALAPPDATA\Temp",
                  "$env:LOCALAPPDATA\wsl",
                  "$env:LOCALAPPDATA\Google\Chrome\User Data",
                  "$env:LOCALAPPDATA\Docker",
                  "$env:USERPROFILE\.codex",
                  "$env:USERPROFILE\.claude",
                  "$env:USERPROFILE\ai-skill-audit") {
    Show-Size $Path
}

Section "完成"
Write-Host "报告已保存: $LogFile"
Write-Host "把这个文件发给 Claude。"
Stop-Transcript | Out-Null
