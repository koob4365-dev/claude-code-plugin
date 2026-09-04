# 01-network.ps1 —— 修网络。默认只显示；加 -Apply 才动手；加 -Reset 额外重置 TCP/IP（需重启）。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\01-network.ps1 -Apply
# 必须以管理员身份运行。

param(
    [switch]$Apply,
    [switch]$Reset
)

$ErrorActionPreference = "Continue"
$LogDir = Join-Path $env:USERPROFILE "Desktop\repair-logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Start-Transcript -Path (Join-Path $LogDir "01-network-$Stamp.txt") | Out-Null

function Section($Title) {
    Write-Host ""
    Write-Host "===== $Title =====" -ForegroundColor Cyan
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Apply -and -not $IsAdmin) {
    Write-Host "需要管理员权限。右键 PowerShell → 以管理员身份运行。" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# 虚拟网卡不碰：Hyper-V、WSL、VMware、VirtualBox、VPN 的 TAP/TUN/Wintun
$VirtualPattern = "Hyper-V|WSL|Virtual|VMware|VirtualBox|TAP|TUN|Wintun|Loopback|Bluetooth"

Section "当前状态"
Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize
$Gateway = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
if ($Gateway) {
    Write-Host "已经有默认网关，网络基本正常。" -ForegroundColor Green
    $Gateway | Format-Table InterfaceAlias, @{ n = "网关"; e = { ($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join "," } } -AutoSize
} else {
    Write-Host "没有默认网关。" -ForegroundColor Yellow
}

$VpnUp = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -match "TAP|TUN|Wintun" }
if ($VpnUp) {
    Write-Host "注意：有 VPN 类网卡处于 Up 状态：" -ForegroundColor Yellow
    $VpnUp | Format-Table Name, InterfaceDescription -AutoSize
    Write-Host "如果没有网关，先关掉 VPN 软件或禁用这块网卡再试。本脚本不会自动禁用它。" -ForegroundColor Yellow
}

if (-not $Apply) {
    Section "只读模式，未做任何改动"
    Write-Host "要执行修复：  powershell -NoProfile -ExecutionPolicy Bypass -File .\01-network.ps1 -Apply"
    Stop-Transcript | Out-Null
    exit 0
}

Section "第 1 步：启用被禁用的物理网卡（虚拟网卡不碰）"
$Disabled = Get-NetAdapter | Where-Object { $_.Status -eq "Disabled" -and $_.InterfaceDescription -notmatch $VirtualPattern }
if ($Disabled) {
    foreach ($Adapter in $Disabled) {
        Write-Host "启用: $($Adapter.Name)  ($($Adapter.InterfaceDescription))"
        Enable-NetAdapter -Name $Adapter.Name -Confirm:$false
    }
    Start-Sleep -Seconds 5
} else {
    Write-Host "没有被禁用的物理网卡。"
}

Section "第 2 步：DHCP 释放并续租，清 DNS 缓存"
ipconfig /release | Out-Null
ipconfig /renew
ipconfig /flushdns
Start-Sleep -Seconds 5

Section "第 3 步：复查"
$Gateway = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
if ($Gateway) {
    $Gateway | Format-Table InterfaceAlias,
        @{ n = "IPv4"; e = { ($_.IPv4Address | ForEach-Object { $_.IPAddress }) -join "," } },
        @{ n = "网关"; e = { ($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join "," } } -AutoSize
} else {
    Write-Host "仍然没有默认网关。" -ForegroundColor Yellow
}
ping -n 2 1.1.1.1
ping -n 2 www.baidu.com

if ($Reset) {
    Section "第 4 步：重置 Winsock 和 TCP/IP（微软官方排查步骤）"
    netsh winsock reset
    netsh int ip reset
    Write-Host "已重置。现在重启电脑，重启后再跑一次 00-check.ps1。" -ForegroundColor Yellow
} elseif (-not $Gateway) {
    Section "下一步"
    Write-Host "复查仍无网关。运行：  .\01-network.ps1 -Apply -Reset   然后重启。"
    Write-Host "如果是 Wi-Fi：点右下角网络图标，手动重新连接一次。"
    Write-Host "如果是网线：检查线是否插好，路由器灯是否亮。"
}

Stop-Transcript | Out-Null
