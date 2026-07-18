<#
  typora-upload.ps1  —  Typora "Custom Command" 图片上传器
  Typora 会以  <此命令> "<图片路径>"  方式调用，并解析 stdout 里的 URL 行。
  因此本脚本【只向 stdout 打印 CDN 链接】(每张一行)，其它一切输出都吞掉。
  上传逻辑：按内容哈希归档到 images/年/月 -> git 提交并推送 -> 打印 jsDelivr 链接。
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'

# ==== 图床配置（与 upload.ps1 保持一致）====
$Owner    = '2012952877'
$Repo     = 'blog-images'
$Branch   = 'main'
$CdnBase  = "https://cdn.jsdelivr.net/gh/$Owner/$Repo@$Branch"
$RepoRoot = 'C:\Users\dche\blog-images'
$allowed  = '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico'
# ============================================

function Fail([string]$msg) { [Console]::Error.WriteLine("typora-upload: $msg"); exit 1 }

if (-not $Path -or $Path.Count -eq 0) { Fail 'no image path passed' }

$urls = New-Object System.Collections.Generic.List[string]
foreach ($p in $Path) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (-not (Test-Path -LiteralPath $p)) { Fail "file not found: $p" }
    $file = Get-Item -LiteralPath $p
    if ($allowed -notcontains $file.Extension.ToLower()) { Fail "unsupported ext: $($file.Name)" }

    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
    $base = ([System.IO.Path]::GetFileNameWithoutExtension($file.Name)).ToLower() -replace '[^a-z0-9\-]', '-' -replace '-+', '-'
    $base = $base.Trim('-'); if ([string]::IsNullOrWhiteSpace($base)) { $base = 'img' }
    if ($base.Length -gt 40) { $base = $base.Substring(0, 40).Trim('-') }
    $ext = $file.Extension.ToLower()
    $now = Get-Date
    $rel = "images/{0}/{1}/{2}-{3}{4}" -f $now.ToString('yyyy'), $now.ToString('MM'), $base, $hash, $ext
    $dest = Join-Path $RepoRoot $rel

    $dir = Split-Path -Parent $dest
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $dest)) { Copy-Item -LiteralPath $file.FullName -Destination $dest -Force }
    $urls.Add("$CdnBase/$rel")
}
if ($urls.Count -eq 0) { Fail 'no valid image' }

# ---- git 提交并推送（所有输出吞掉，避免污染 stdout）----
$ErrorActionPreference = 'Continue'
Push-Location $RepoRoot
try {
    git add -A 2>$null | Out-Null
    $dirty = git status --porcelain 2>$null
    if ($dirty) { git commit -m "typora upload $($urls.Count) image(s)" 2>$null | Out-Null }
    git push 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        git pull --rebase 2>$null | Out-Null
        git push 2>$null | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { Pop-Location; Fail 'git push failed (network/offline?)' }
}
finally { if ((Get-Location).Path -eq $RepoRoot) { Pop-Location } }

# ---- 只打印 URL（Typora 从 stdout 倒序取 URL 行）----
foreach ($u in $urls) { [Console]::Out.WriteLine($u) }
