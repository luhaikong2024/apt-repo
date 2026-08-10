# incoming/

按套件放入要发布的 `.deb`：

```text
incoming/
├── bionic/*.deb
├── focal/*.deb
├── jammy/*.deb
└── noble/*.deb
```

推荐从构建仓同步，而不是手拷：

```bash
# 在 apt-repo-toolchain 中
make sync          # 或 make sync-publish
```

本仓执行 `make all` 或 push 触发 Actions，即可更新 Pages。
