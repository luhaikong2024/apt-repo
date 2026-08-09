# incoming/

把要正式发布的 `.deb` 放进对应套件目录，推送到 GitHub 后，Actions 会自动导入并发布到 Pages。

```text
incoming/
├── bionic/*.deb   # Ubuntu 18.04
├── focal/*.deb    # Ubuntu 20.04
├── jammy/*.deb    # Ubuntu 22.04
└── noble/*.deb    # Ubuntu 24.04
```

当前示例：`jammy/hello_2.10-2ubuntu4_amd64.deb`（轻量测试包）。
