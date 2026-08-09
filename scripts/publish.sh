#!/usr/bin/env bash
# 将 repo/ 同步到 public/（供 GitLab Pages 或任意静态托管）
# 客户端基址应对准 public/ 的内容根（含 dists/ 与 pool/）
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_dirs

[[ -d "${REPO_PATH}/dists" ]] || die "尚未生成索引，请先: scripts/generate-repo.sh"

log "同步 ${REPO_PATH}/ → ${PUBLIC_PATH}/"
rm -rf "${PUBLIC_PATH:?}/dists" "${PUBLIC_PATH:?}/pool"
mkdir -p "${PUBLIC_PATH}/dists" "${PUBLIC_PATH}/pool"
cp -a "${REPO_PATH}/dists/." "${PUBLIC_PATH}/dists/"
if [[ -d "${REPO_PATH}/pool" ]]; then
  cp -a "${REPO_PATH}/pool/." "${PUBLIC_PATH}/pool/"
fi

# 公钥与客户端脚本放到站点根
if [[ -f "${GPG_PUBLIC_KEY_PATH}" ]]; then
  cp -f "${GPG_PUBLIC_KEY_PATH}" "${PUBLIC_PATH}/repo-key.gpg"
fi
cp -f "${ROOT_DIR}/scripts/add-apt-source.sh" "${PUBLIC_PATH}/add-apt-source.sh"

# 简易说明页
cat >"${PUBLIC_PATH}/index.html" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <title>${ORIGIN}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
    code, pre { background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 4px; }
    pre { padding: 1rem; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>${ORIGIN}</h1>
  <p>${DESCRIPTION}</p>
  <p>官方布局：<code>dists/</code> + <code>pool/</code></p>
  <h2>添加软件源（示例）</h2>
  <p>apt 会按本机架构自动访问 <code>dists/&lt;套件&gt;/main/binary-amd64</code> 或 <code>binary-arm64</code>。</p>
  <pre>curl -fsSL https://YOUR_PAGES_URL/repo-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/${ORIGIN}.gpg
echo "deb [signed-by=/usr/share/keyrings/${ORIGIN}.gpg arch=\$(dpkg --print-architecture)] https://YOUR_PAGES_URL \$(lsb_release -cs) ${DEFAULT_COMPONENT}" | sudo tee /etc/apt/sources.list.d/${ORIGIN}.list
sudo apt update
sudo apt install ${PACKAGE_NAME}</pre>
  <p>套件: ${SUITES}　组件: ${COMPONENTS}　架构: ${ARCHITECTURES}</p>
  <h2>路径一览</h2>
  <pre>dists/&lt;focal|jammy|noble&gt;/main/binary-amd64/Packages.gz
dists/&lt;focal|jammy|noble&gt;/main/binary-arm64/Packages.gz
pool/main/&lt;首字母&gt;/&lt;包名&gt;/&lt;包名&gt;_版本_amd64.deb
pool/main/&lt;首字母&gt;/&lt;包名&gt;/&lt;包名&gt;_版本_arm64.deb</pre>
</body>
</html>
EOF

log "发布目录就绪: ${PUBLIC_PATH}"
log "请将 Pages 基址指向 public/（URL 根下应能访问 dists/ 与 pool/）"
