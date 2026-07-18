<#
.SYNOPSIS
  把整个图床仓库(含全部历史)打包成单个 .bundle 文件，用于长期离线备份 / 几年后恢复。
.DESCRIPTION
  git bundle 会把所有 commit、所有图片、所有历史打进一个文件。
  把这个文件丢到移动硬盘 / 网盘 / 邮箱附件，即使 GitHub 账号和本地都没了，也能一条命令完整还原。
.EXAMPLE
  .\tools\backup.ps1
.EXAMPLE
  .\tools\backup.ps1 -OutDir "D:\网盘\图床备份"
#>
[CmdletBinding()]
param(
    [string]$OutDir = "C:\Users\dche\blog-images-backups"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

Push-Location $RepoRoot
try {
    # 先确保本地是最新的
    git pull --rebase --quiet 2>$null

    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bundle = Join-Path $OutDir "blog-images-$stamp.bundle"
    git bundle create $bundle --all

    $size = '{0:N1} MB' -f ((Get-Item $bundle).Length / 1MB)
    Write-Host "`n备份完成 ✅" -ForegroundColor Green
    Write-Host "  文件: $bundle"
    Write-Host "  大小: $size"
    Write-Host "`n【几年后恢复】把该 .bundle 拷到任意电脑，执行：" -ForegroundColor Cyan
    Write-Host "  git clone `"$bundle`" blog-images-restored" -ForegroundColor Yellow
    Write-Host "  # 即可得到包含所有图片和历史的完整仓库副本`n"

    # 只保留最近 10 份，避免堆积
    Get-ChildItem $OutDir -Filter 'blog-images-*.bundle' |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
finally { Pop-Location }
