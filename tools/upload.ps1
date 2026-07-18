<#
.SYNOPSIS
  把本地图片上传到个人 GitHub 图床仓库，并输出可直接粘贴的 CDN 链接。
.DESCRIPTION
  流程：复制图片 -> 按 images/年/月 归档(内容哈希命名,自动去重) -> git commit & push
        -> 打印 jsDelivr / raw 链接 + Markdown 片段，并把 jsDelivr 链接复制到剪贴板。
.EXAMPLE
  .\tools\upload.ps1 -Path "C:\Users\dche\Pictures\screenshot.png"
.EXAMPLE
  Get-ChildItem *.png | ForEach-Object { .\tools\upload.ps1 -Path $_.FullName }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('FullName')]
    [string[]]$Path
)

begin {
    $ErrorActionPreference = 'Stop'

    # ==== 图床配置（换存储/改仓库只需改这里）====
    $Owner  = '2012952877'
    $Repo   = 'blog-images'
    $Branch = 'main'
    # CDN 前缀：默认 jsDelivr。将来若绑自定义域名，把 $CdnBase 改成 https://img.你的域名 即可，历史链接结构不变。
    $CdnBase = "https://cdn.jsdelivr.net/gh/$Owner/$Repo@$Branch"
    $RawBase = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch"
    # ============================================

    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $allowed  = '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico'
    $results  = @()

    function Sanitize([string]$name) {
        $n = $name.ToLower() -replace '[^a-z0-9\-]', '-' -replace '-+', '-'
        $n = $n.Trim('-')
        if ([string]::IsNullOrWhiteSpace($n)) { $n = 'img' }
        if ($n.Length -gt 40) { $n = $n.Substring(0, 40).Trim('-') }
        return $n
    }
}

process {
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { Write-Warning "跳过：找不到文件 $p"; continue }
        $file = Get-Item -LiteralPath $p
        if ($allowed -notcontains $file.Extension.ToLower()) {
            Write-Warning "跳过：$($file.Name) 不是支持的图片格式"; continue
        }

        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
        $base = Sanitize([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
        $ext  = $file.Extension.ToLower()
        $now  = Get-Date
        $rel  = "images/{0}/{1}/{2}-{3}{4}" -f $now.ToString('yyyy'), $now.ToString('MM'), $base, $hash, $ext
        $dest = Join-Path $RepoRoot $rel

        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        if (Test-Path $dest) {
            Write-Host "已存在(内容相同)，直接复用链接：$rel" -ForegroundColor DarkYellow
        }
        else {
            Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
        }

        $results += [pscustomobject]@{ Rel = $rel; Name = $file.Name }
    }
}

end {
    if ($results.Count -eq 0) { Write-Warning '没有可上传的图片。'; return }

    Push-Location $RepoRoot
    try {
        git add -A | Out-Null
        $staged = git status --porcelain
        if ($staged) {
            $msg = "upload: " + ($results.Rel -join ', ')
            if ($msg.Length -gt 200) { $msg = "upload: $($results.Count) image(s)" }
            git commit -m $msg | Out-Null
            git pull --rebase --quiet 2>$null
            git push --quiet
            Write-Host "`n已推送到 GitHub ✅" -ForegroundColor Green
        }
        else {
            Write-Host "`n无新增(全部为已存在的相同图片)，跳过提交。" -ForegroundColor DarkYellow
        }
    }
    finally { Pop-Location }

    Write-Host "`n================ 链接 ================" -ForegroundColor Cyan
    $lastCdn = $null
    foreach ($r in $results) {
        $cdn = "$CdnBase/$($r.Rel)"
        $raw = "$RawBase/$($r.Rel)"
        $lastCdn = $cdn
        Write-Host "`n[$($r.Name)]"
        Write-Host "  CDN(推荐) : $cdn" -ForegroundColor Green
        Write-Host "  raw(备用) : $raw" -ForegroundColor DarkGray
        Write-Host "  Markdown  : ![]($cdn)"
    }
    if ($lastCdn) {
        try { Set-Clipboard -Value $lastCdn; Write-Host "`n最后一张的 CDN 链接已复制到剪贴板 📋" -ForegroundColor Cyan } catch {}
    }
    Write-Host "======================================`n" -ForegroundColor Cyan
}
