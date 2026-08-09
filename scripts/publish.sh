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

# 公钥放到站点根（同时提供 armored / binary，避免空文件或格式问题）
export GNUPGHOME="${GPG_HOME_PATH}"
KEY_ID="${SIGNING_KEY_ID}"
if [[ -z "${KEY_ID}" ]] && [[ -d "${GPG_HOME_PATH}" ]]; then
  KEY_ID="$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/ {print $5; exit}' || true)"
fi
if [[ -z "${KEY_ID}" ]] && [[ -f "${GPG_PUBLIC_KEY_PATH}" ]]; then
  # 无私钥时，至少拷贝已有公钥文件
  cp -f "${GPG_PUBLIC_KEY_PATH}" "${PUBLIC_PATH}/repo-key.asc"
else
  [[ -n "${KEY_ID}" ]] || die "无法导出公钥：缺少 SIGNING_KEY_ID / 私钥"
  gpg --export --armor "${KEY_ID}" >"${PUBLIC_PATH}/repo-key.asc"
  gpg --export "${KEY_ID}" >"${PUBLIC_PATH}/repo-key.gpg"
fi
# 兼容旧路径：repo-key.gpg 若为空则用 asc 转一份 binary
if [[ ! -s "${PUBLIC_PATH}/repo-key.gpg" ]]; then
  if [[ -s "${PUBLIC_PATH}/repo-key.asc" ]]; then
    gpg --dearmor <"${PUBLIC_PATH}/repo-key.asc" >"${PUBLIC_PATH}/repo-key.gpg"
  elif [[ -s "${GPG_PUBLIC_KEY_PATH}" ]]; then
    if grep -q 'BEGIN PGP PUBLIC KEY' "${GPG_PUBLIC_KEY_PATH}"; then
      gpg --dearmor <"${GPG_PUBLIC_KEY_PATH}" >"${PUBLIC_PATH}/repo-key.gpg"
      cp -f "${GPG_PUBLIC_KEY_PATH}" "${PUBLIC_PATH}/repo-key.asc"
    else
      cp -f "${GPG_PUBLIC_KEY_PATH}" "${PUBLIC_PATH}/repo-key.gpg"
    fi
  else
    die "公钥为空，拒绝发布"
  fi
fi
[[ -s "${PUBLIC_PATH}/repo-key.gpg" ]] || die "repo-key.gpg 为空，拒绝发布"
log "公钥大小: $(wc -c <"${PUBLIC_PATH}/repo-key.gpg") bytes"

cp -f "${ROOT_DIR}/scripts/add-apt-source.sh" "${PUBLIC_PATH}/add-apt-source.sh"
# 避免 GitHub Pages/Jekyll 误处理
: >"${PUBLIC_PATH}/.nojekyll"

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
  <h2>添加软件源（先装公钥，再加源）</h2>
  <pre>curl -fsSL https://luhaikong2024.github.io/apt-repo/add-apt-source.sh \\
  | sudo bash -s -- https://luhaikong2024.github.io/apt-repo
sudo apt install hello</pre>
  <p>或手动：</p>
  <pre>curl -fsSL https://luhaikong2024.github.io/apt-repo/repo-key.gpg | sudo tee /usr/share/keyrings/${ORIGIN}.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/${ORIGIN}.gpg] https://luhaikong2024.github.io/apt-repo \$(lsb_release -cs) ${DEFAULT_COMPONENT}" | sudo tee /etc/apt/sources.list.d/${ORIGIN}.list
sudo apt update</pre>
  <p>apt 会按本机架构自动访问 <code>binary-amd64</code> 或 <code>binary-arm64</code>。</p>
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
