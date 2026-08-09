# linux_apt_repo

私有 APT 仓库，采用与 Ubuntu 官方一致的 **`dists/` + `pool/`** 布局，并为多个发行版代号（bionic / focal / jammy / noble，即 18.04～24.04）分别构建与索引。

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

## 客户端用法（正规：先公钥，再加源）

```bash
curl -fsSL https://luhaikong2024.github.io/apt-repo/add-apt-source.sh \
  | sudo bash -s -- https://luhaikong2024.github.io/apt-repo
sudo apt install hello
```

手动等价步骤：

```bash
# 1. 安装公钥
curl -fsSL https://luhaikong2024.github.io/apt-repo/repo-key.gpg \
  | sudo tee /usr/share/keyrings/linux-apt-repo.gpg >/dev/null

# 2. 添加源（signed-by 指向刚装的公钥）
echo "deb [signed-by=/usr/share/keyrings/linux-apt-repo.gpg] https://luhaikong2024.github.io/apt-repo $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/linux-apt-repo.list

# 3. 更新并安装
sudo apt update
sudo apt install hello
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

## 正式发布地址（GitHub Pages）

仓库：https://github.com/luhaikong2024/apt-repo  

源基址（Actions 部署成功后）：

```text
https://luhaikong2024.github.io/apt-repo/
```

客户端：

```bash
curl -fsSL https://luhaikong2024.github.io/apt-repo/add-apt-source.sh \
  | sudo bash -s -- https://luhaikong2024.github.io/apt-repo
sudo apt install hello    # 当前示例包；之后换成你的包名
```

预置 `.deb` 放到 `incoming/<套件>/` 再 push，即可随 Pages 发布。

### GitHub 设置清单

1. **Settings → Pages → Source** = **GitHub Actions**
2. **Settings → Secrets → Actions** 添加 `APT_REPO_GPG_PRIVATE_KEY`（本地已导出到 `.secret-export/`，勿提交）
3. Actions 权限允许运行第三方 actions（deploy-pages 等）
4. 推送 `main` 或手动 **Run workflow**

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
