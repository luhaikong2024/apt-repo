# apt-repo

私有 APT **分发仓**：管理 `.deb`、生成官方 `dists/` + `pool/`、发布到 GitHub Pages。

**不负责编包。** 源码 / 工具链 / 构建在私有仓：  
https://github.com/luhaikong2024/apt-repo-toolchain

## 分工

| 仓库 | 做什么 |
|------|--------|
| [apt-repo-toolchain](https://github.com/luhaikong2024/apt-repo-toolchain)（私有） | 源码、工具链、Docker 编出 `.deb` |
| **本仓 apt-repo**（公开 Pages） | `incoming/` → 索引签名 → Pages |

## 目录

| 路径 | 作用 |
|------|------|
| `incoming/<套件>/` | 放入要发布的 `.deb`（构建仓 `make sync` 会拷到这里） |
| `conf/repo.conf` | 套件、架构、签名配置 |
| `scripts/` | 导入 / 生成索引 / 签名 / 发布 |
| `keys/` | 公钥（私钥勿提交） |
| `repo/` · `public/` | 生成产物（gitignore） |

## 发布流程

```bash
# 在构建仓编好并同步过来之后，于本仓执行：
make all          # import + 生成索引签名 + public/
git add incoming && git commit -m "release debs" && git push
```

或只更新索引：`make import && make repo && make publish`。

## 客户端

```bash
curl -fsSL https://luhaikong2024.github.io/apt-repo/add-apt-source.sh \
  | sudo bash -s -- https://luhaikong2024.github.io/apt-repo
sudo apt install <包名>
```

## GitHub Pages

1. Settings → Pages → Source = **GitHub Actions**  
2. Secret：`APT_REPO_GPG_PRIVATE_KEY`（私钥备份见私有仓 apt-repo-key）  
3. 地址：https://luhaikong2024.github.io/apt-repo/
