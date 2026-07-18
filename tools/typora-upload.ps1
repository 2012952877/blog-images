<#
  typora-upload.ps1  —  Typora "Custom Command" 图片上传器
  Typora 以  <此命令> "<图片路径>"  调用，并从 stdout 倒序解析 URL 行。
  本脚本【只向 stdout 打印 CDN 链接】(每张一行)，其它输出全部吞掉。

  注意：Typora 通过 cmd 启动 powershell.exe，其 PSModulePath 被 PS7 污染，
  会导致 Get-FileHash / Get-Date 等 Utility cmdlet 不可用。
  因此这里【只用 .NET 方法 + 原生 git】，不依赖任何可能缺失的 cmdlet。
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

# ==== 图床配置 ====
$Owner    = '2012952877'
$Repo     = 'blog-images'
$Branch   = 'main'
$CdnBase  = "https://cdn.jsdelivr.net/gh/$Owner/$Repo@$Branch"
$RepoRoot = 'C:\Users\dche\blog-images'
$allowed  = '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp', '.ico'
$git      = 'C:\Program Files\Git\cmd\git.exe'
if (-not [System.IO.File]::Exists($git)) { $git = 'git' }
# ==================

function Fail([string]$m) { [Console]::Error.WriteLine("typora-upload: $m"); exit 1 }

if (-not $Path -or $Path.Count -eq 0) { Fail 'no image path passed' }

$urls = [System.Collections.Generic.List[string]]::new()
foreach ($p in $Path) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (-not [System.IO.File]::Exists($p)) { Fail "file not found: $p" }
    $ext = [System.IO.Path]::GetExtension($p).ToLower()
    if ($allowed -notcontains $ext) { Fail "unsupported ext: $ext" }

    # SHA1 (纯 .NET，避开 Get-FileHash)
    $bytes = [System.IO.File]::ReadAllBytes($p)
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $hashHex = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLower()
    $sha.Dispose()
    $hash = $hashHex.Substring(0, 8)

    $base = [System.IO.Path]::GetFileNameWithoutExtension($p).ToLower() -replace '[^a-z0-9\-]', '-' -replace '-+', '-'
    $base = $base.Trim('-'); if ([string]::IsNullOrWhiteSpace($base)) { $base = 'img' }
    if ($base.Length -gt 40) { $base = $base.Substring(0, 40).Trim('-') }

    $now = [System.DateTime]::Now
    $rel = "images/" + $now.ToString('yyyy') + "/" + $now.ToString('MM') + "/" + $base + "-" + $hash + $ext
    $dest = [System.IO.Path]::Combine($RepoRoot, $rel.Replace('/', '\'))

    $destDir = [System.IO.Path]::GetDirectoryName($dest)
    [void][System.IO.Directory]::CreateDirectory($destDir)
    if (-not [System.IO.File]::Exists($dest)) { [System.IO.File]::Copy($p, $dest, $false) }

    $urls.Add("$CdnBase/$rel")
}
if ($urls.Count -eq 0) { Fail 'no valid image' }

# ---- git 提交并推送（原生 git，用 -C 指定仓库；输出全部吞掉）----
& $git -C $RepoRoot add -A *> $null
$dirty = (& $git -C $RepoRoot status --porcelain 2>$null)
if ($dirty) { & $git -C $RepoRoot commit -m ("typora upload " + $urls.Count + " image(s)") *> $null }
& $git -C $RepoRoot push *> $null
if ($LASTEXITCODE -ne 0) {
    & $git -C $RepoRoot pull --rebase *> $null
    & $git -C $RepoRoot push *> $null
}
if ($LASTEXITCODE -ne 0) { Fail 'git push failed (network/offline?)' }

# ---- 只打印 URL ----
foreach ($u in $urls) { [Console]::Out.WriteLine($u) }
