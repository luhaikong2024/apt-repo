#!/usr/bin/env bash
# 在客户端机器上添加本仓库（官方 sources 写法）
# 用法:
#   curl -fsSL https://YOUR_PAGES_URL/add-apt-source.sh | sudo bash -s -- https://YOUR_PAGES_URL
# 或:
#   sudo ./add-apt-source.sh https://YOUR_PAGES_URL [suite] [component]
set -euo pipefail

BASE_URL="${1:-}"
SUITE="${2:-$(lsb_release -cs 2>/dev/null || echo jammy)}"
COMPONENT="${3:-main}"
ORIGIN_NAME="linux-apt-repo"

[[ -n "${BASE_URL}" ]] || {
  echo "用法: $0 <仓库基址URL> [suite] [component]" >&2
  echo "示例: $0 https://group.gitlab.io/linux_apt_repo jammy main" >&2
  exit 1
}

BASE_URL="${BASE_URL%/}"
KEYRING="/usr/share/keyrings/${ORIGIN_NAME}.gpg"
LIST="/etc/apt/sources.list.d/${ORIGIN_NAME}.list"

echo "下载公钥 → ${KEYRING}"
curl -fsSL "${BASE_URL}/repo-key.gpg" | gpg --dearmor | tee "${KEYRING}" >/dev/null
chmod 644 "${KEYRING}"

echo "写入源 → ${LIST}"
echo "deb [signed-by=${KEYRING} arch=$(dpkg --print-architecture)] ${BASE_URL} ${SUITE} ${COMPONENT}" >"${LIST}"

apt-get update
echo "完成。可安装: sudo apt install <包名>"
