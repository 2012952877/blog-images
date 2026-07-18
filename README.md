# blog-images · 个人图床

Deon 的博客 / 微信公众号图床。**图片存在我个人名下、可整包备份恢复，不依赖任何会过期的账号或免费图床。**

- 出图源：本仓库（个人 GitHub，公开）
- CDN：jsDelivr（`https://cdn.jsdelivr.net/gh/2012952877/blog-images@main/...`）
- 备份：GitHub 远端 + 本地克隆 + `git bundle` 单文件离线包（三副本）

> ⚠️ 仓库是**公开**的（CDN 直链需要公开）。只上传打算公开发布的图片，别放客户机密/内网敏感截图的原图。

---

## 目录结构

```
blog-images/
├─ images/            # 所有图片，按 年/月 归档，文件名带内容哈希(自动去重)
│  └─ 2026/07/xxx-1a2b3c4d.png
├─ tools/
│  ├─ upload.ps1      # 上传图片 → 推送 → 输出 CDN 链接
│  └─ backup.ps1      # 打包 .bundle 离线备份
└─ README.md
```

## 日常使用

### 方式一：脚本上传（零依赖，最稳）

```powershell
cd C:\Users\dche\blog-images
.\tools\upload.ps1 -Path "C:\path\to\图.png"
```

输出示例：

```
CDN(推荐) : https://cdn.jsdelivr.net/gh/2012952877/blog-images@main/images/2026/07/img-1a2b3c4d.png
Markdown  : ![](https://cdn.jsdelivr.net/gh/2012952877/blog-images@main/images/2026/07/img-1a2b3c4d.png)
```

链接已复制到剪贴板，直接粘进 Markdown / mdnice。批量：

```powershell
Get-ChildItem "C:\截图文件夹\*.png" | .\tools\upload.ps1
```

### 方式二：Typora 粘贴自动上传（PicList，最省事）

在 Typora 里粘贴截图即自动上传并插入链接。配置见下方「PicList 配置」。

## 发到微信公众号的正确姿势

1. 在 **mdnice**（editor.mdnice.com）里粘贴你的 Markdown；
2. 图片链接已是本图床的 CDN 链接 → mdnice「一键上传图片到公众号图床」会把图**转存进微信素材库**；
3. 全选复制 → 贴进公众号编辑器。**图片与代码高亮一起过去，彻底绕开微信防盗链。**

> 转存微信后，公众号文章里的图由微信自己托管；本图床是你的**源文件档案 + 其它平台(博客/知乎)出图**用。

## 备份

```powershell
.\tools\backup.ps1                       # 生成 C:\Users\dche\blog-images-backups\blog-images-时间戳.bundle
.\tools\backup.ps1 -OutDir "D:\网盘\图床备份"   # 直接备到网盘/移动硬盘
```

建议每隔一段时间跑一次，把 `.bundle` 放到**与本机不同的地方**（网盘/移动硬盘/邮箱）。

## 几年后恢复（哪怕 GitHub 账号和电脑都没了）

只要手里有任意一份 `.bundle`：

```powershell
git clone "blog-images-20260718-093000.bundle" blog-images-restored
```

即得到含**全部图片和历史**的完整仓库。再 `git remote set-url` 指到新的 GitHub 仓库 `git push` 即可复活图床。

## 迁移 / 换存储（URL 不裂的关键）

历史文章里的图片链接结构是固定的 `.../images/年/月/文件名`。将来若要换到腾讯云 COS / Cloudflare R2 / 自定义域名：

1. 把 `images/` 整个目录同步到新存储（目录结构保持一致）；
2. 绑一个**自定义域名**指过去；
3. 改 `tools/upload.ps1` 顶部的 `$CdnBase`，历史链接用域名 301 到新存储。

只要你**从一开始就用自定义域名**当门面，换存储时历史链接完全不用动 —— 这是唯一能做到"永不裂图"的办法（可后续升级）。

## PicList 配置（GitHub 图床）

下载 PicList（PicGo 增强版）→ 图床设置 → GitHub：

| 字段 | 值 |
|---|---|
| 仓库名 repo | `2012952877/blog-images` |
| 分支 branch | `main` |
| Token | 到 github.com/settings/tokens 建一个 **classic PAT**，勾 `repo`，粘这里 |
| 存储路径 path | `images/` |
| 自定义域名 customUrl | `https://cdn.jsdelivr.net/gh/2012952877/blog-images@main` |

Typora → 文件 → 偏好设置 → 图像 → 上传服务选 PicList，勾"上传图片"。
