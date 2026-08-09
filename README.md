# linux_apt_repo

私有 APT 仓库，采用与 Ubuntu 官方一致的 **`dists/` + `pool/`** 布局，并为多个发行版代号（focal / jammy / noble）分别构建与索引。

> 不知道从哪看起？请先读 **[使用与原理说明.md](./使用与原理说明.md)**（目录怎么配合、工作原理、逐步怎么用）。

## 目录说明

| 路径 | 作用 |
|------|------|
| `source/` | **你来补充**：软件源码 |
| `toolchain_source/` | **你来补充**：编译工具链源码 |
| `packaging/` | Debian 打包元数据（`debian/`），可由模板生成 |
| `docker/` | 各 Ubuntu 版本的构建镜像 |
| `conf/` | 仓库套件、组件、架构等配置 |
| `scripts/` | 构建、导入、生成索引、签名、发布 |
| `repo/` | 仓库本体（`dists/`、`pool/`），构建后生成 |
| `public/` | 对外静态目录（GitHub / GitLab Pages） |
| `keys/` | 公钥；私钥在 `keys/gnupg/`（勿提交） |

## 客户端用法（官方写法）

```text
deb [signed-by=/usr/share/keyrings/linux-apt-repo.gpg] https://YOUR_PAGES_URL jammy main
```

一键添加（把 URL 换成你的 Pages 地址）：

```bash
curl -fsSL https://YOUR_PAGES_URL/add-apt-source.sh | sudo bash -s -- https://YOUR_PAGES_URL
```

APT 会请求例如：

- `.../dists/jammy/InRelease`
- `.../dists/jammy/main/binary-amd64/Packages.gz`
- 再按索引里的 `Filename:` 从 `pool/` 下载 `.deb`

## 本地工作流

### 1. 准备

```bash
# 系统依赖（生成索引 / 签名）
sudo apt-get install -y dpkg-dev apt-utils gnupg gzip xz-utils make

# Docker（多版本交叉构建）
# 以及将软件源码放入 source/，工具链源码放入 toolchain_source/
```

```bash
make gpg          # 生成签名密钥，写入 conf/repo.conf
make bootstrap    # 生成 packaging/myapp/debian（包名见 conf/repo.conf）
```

按需修改：

- `conf/repo.conf`：套件、架构、包名、版本
- `packaging/<包名>/debian/*`：依赖、安装路径、`rules`

### 2. 构建

```bash
# 可选：先编工具链
make toolchain S=jammy A=amd64

# 构建某个套件的 .deb，并导入 pool/、刷新 dists/
make package S=jammy A=amd64

# 或一次性构建 conf 里全部套件并发布到 public/
make all
# 带工具链：
./scripts/build-all.sh --with-toolchain
```

版本约定：同一上游版本在不同套件下会打成 `1.0.0~jammy1` / `1.0.0~focal1`，避免 `pool/` 文件名冲突，并便于按套件过滤索引。

### 3. 发布

```bash
make repo      # 仅重生成索引并签名
make publish   # 同步到 public/
```

将 `public/` 作为静态站点根目录托管（本仓库已含 `.gitlab-ci.yml` Pages 任务）。

## 源码约定

### `source/`

放入可被 `dpkg-buildpackage` 构建的项目，推荐具备其一：

- `CMakeLists.txt`（默认 `debian/rules` 走 debhelper + cmake）
- 或 `Makefile` / `configure`
- 或项目根目录 `build.sh`（会在打包前执行）

### `toolchain_source/`

放入工具链源码，推荐根目录提供 `build.sh`：

```bash
#!/bin/sh
# ./build.sh --prefix /opt/custom-toolchain --out /out
```

也支持 `CMakeLists.txt` / `configure` / `Makefile`。产物会进入 `artifacts/toolchain/<suite>-<arch>/`，随后 `build-package.sh` 自动挂载进构建容器。

## GitHub Pages（推荐）

已提供 `.github/workflows/pages.yml`。

1. 把仓库推到 GitHub。
2. **Settings → Pages → Source** 选 **GitHub Actions**。
3. （推荐）**Settings → Secrets → Actions** 添加 `APT_REPO_GPG_PRIVATE_KEY`（ASCII 私钥），避免每次流水线生成新密钥。
4. 推送到 `main`/`master`，或手动跑 workflow；成功后基址为：  
   `https://<用户名>.github.io/<仓库名>/`

该 URL 下应能直接访问 `dists/`、`pool/`、`repo-key.gpg`。

源码就绪后，可在 Actions 里手动运行 workflow，并勾选「构建 .deb」。

## GitLab CI（可选）

仍保留 `.gitlab-ci.yml`。推到 GitLab 后开启 Pages，CI 变量同样建议配置 `APT_REPO_GPG_PRIVATE_KEY`。  
基址示例：`https://<group>.gitlab.io/<project>/`

## 仓库结构（生成后）

```text
public/
├── dists/
│   ├── focal/
│   │   ├── InRelease
│   │   ├── Release
│   │   ├── main/binary-amd64/Packages.gz   ← x86_64，apt 自动选
│   │   └── main/binary-arm64/Packages.gz   ← ARM64，apt 自动选
│   ├── jammy/
│   └── noble/
├── pool/
│   └── main/
│       └── m/myapp/
│           ├── myapp_1.0.0~jammy1_amd64.deb
│           └── myapp_1.0.0~jammy1_arm64.deb
├── repo-key.gpg
└── add-apt-source.sh
```
