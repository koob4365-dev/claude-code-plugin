# 03-space.ps1 —— 释放空间。默认只显示；加 -Apply 才动手；加 -Docker 额外清理 Docker 未使用的镜像。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\03-space.ps1 -Apply
# 必须以管理员身份运行。
#
# 会做的事（每一步都可逆）：
#   1. powercfg /h off       关闭休眠，释放 hiberfil.sys（约 12.7 GB）。恢复：powercfg /h on
#   2. .wslconfig swap=0     WSL2 不再在 Temp 里生成 swap.vhdx（约 4 GB）。恢复：删掉那一行
#   3. docker system prune   仅在加 -Docker 时执行，删的是没有容器在用的镜像
#   4. cleanmgr              打开系统自带的磁盘清理窗口，由你勾选
# 不会做的事：不删任何用户文件，不碰 Claude、Codex、Chrome 的目录。

param(
    [switch]$Apply,
    [switch]$Docker
)

$ErrorActionPreference = "Continue"
$LogDir = Join-Path $env:USERPROFILE "Desktop\repair-logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Start-Transcript -Path (Join-Path $LogDir "03-space-$Stamp.txt") | Out-Null

function Section($Title) {
    Write-Host ""
    Write-Host "===== $Title =====" -ForegroundColor Cyan
}

function Get-GB($Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $Bytes = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if (-not $Bytes) { $Bytes = 0 }
    return [math]::Round($Bytes / 1GB, 1)
}

function Show-Free {
    $Drive = Get-PSDrive C
    Write-Host ("C: 可用 {0:N1} GB / 共 {1:N1} GB" -f ($Drive.Free / 1GB), (($Drive.Used + $Drive.Free) / 1GB))
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Apply -and -not $IsAdmin) {
    Write-Host "需要管理员权限。右键 PowerShell → 以管理员身份运行。" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

Section "当前"
Show-Free
Write-Host ("休眠文件 hiberfil.sys : {0} GB" -f (Get-GB "$env:SystemDrive\hiberfil.sys"))
Write-Host ("WSL 交换盘 (Temp 下)   : {0} GB" -f (Get-GB "$env:LOCALAPPDATA\Temp"))
Write-Host ("WSL 发行版             : {0} GB" -f (Get-GB "$env:LOCALAPPDATA\wsl"))
Write-Host ("Docker 数据            : {0} GB" -f (Get-GB "$env:LOCALAPPDATA\Docker"))
$WslConfig = Join-Path $env:USERPROFILE ".wslconfig"
if (Test-Path $WslConfig) { Write-Host "当前 .wslconfig:"; Get-Content $WslConfig } else { Write-Host ".wslconfig 不存在。" }

if (-not $Apply) {
    Section "只读模式，未做任何改动"
    Write-Host "要执行：  powershell -NoProfile -ExecutionPolicy Bypass -File .\03-space.ps1 -Apply"
    Write-Host "另加 -Docker 会清理 Docker 未使用的镜像。"
    Stop-Transcript | Out-Null
    exit 0
}

Section "1. 关闭休眠（快速启动也会随之关闭，开机稍慢一点，其他无影响）"
powercfg /h off
if (Test-Path "$env:SystemDrive\hiberfil.sys") { Write-Host "hiberfil.sys 仍存在，重启后会消失。" } else { Write-Host "hiberfil.sys 已释放。" -ForegroundColor Green }

Section "2. WSL2 不再生成交换盘"
if (Test-Path $WslConfig) {
    $Content = Get-Content $WslConfig -Raw
    if ($Content -match '(?m)^\s*swap\s*=') {
        Write-Host "已有 swap 设置，未改动。"
    } elseif ($Content -match '(?m)^\[wsl2\]') {
        $Content = $Content -replace '(?m)^\[wsl2\][ \t]*\r?$', "[wsl2]`r`nswap=0"
        Set-Content -Path $WslConfig -Value $Content -Encoding ASCII
        Write-Host "已在 [wsl2] 下加入 swap=0。"
    } else {
        Add-Content -Path $WslConfig -Value "`r`n[wsl2]`r`nswap=0" -Encoding ASCII
        Write-Host "已追加 [wsl2] swap=0。"
    }
} else {
    Set-Content -Path $WslConfig -Value "[wsl2]`r`nswap=0" -Encoding ASCII
    Write-Host "已创建 $WslConfig。"
}
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl --shutdown 2>$null
    Write-Host "WSL 已关闭，下次启动生效。"
}

Section "3. Docker"
if ($Docker) {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        docker system prune -a -f 2>&1
    } else {
        Write-Host "docker 命令不可用（Docker Desktop 没在运行或没装）。"
    }
} else {
    Write-Host "未加 -Docker，跳过。"
}

Section "4. 系统自带磁盘清理"
Write-Host "即将打开“磁盘清理”窗口。请勾选：设备驱动程序包、Windows 更新清理、临时文件、以前的 Windows 安装（如有）。"
Write-Host "勾完点“确定”。这一步是微软自己的清理，安全。"
Start-Process cleanmgr.exe -ArgumentList "/d C:"

Section "完成"
Show-Free
Write-Host "重启后再跑 00-check.ps1 看第 11 项。"
Stop-Transcript | Out-Null
