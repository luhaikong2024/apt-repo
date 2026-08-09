#!/usr/bin/env bash
# 正规流程：先安装公钥，再写入带 signed-by 的源
# 用法:
#   curl -fsSL https://luhaikong2024.github.io/apt-repo/add-apt-source.sh \
#     | sudo bash -s -- https://luhaikong2024.github.io/apt-repo
set -euo pipefail

BASE_URL="${1:-}"
SUITE="${2:-$(lsb_release -cs 2>/dev/null || echo jammy)}"
COMPONENT="${3:-main}"
ORIGIN_NAME="linux-apt-repo"

[[ -n "${BASE_URL}" ]] || {
  echo "用法: $0 <仓库基址URL> [suite] [component]" >&2
  echo "示例: $0 https://luhaikong2024.github.io/apt-repo" >&2
  exit 1
}

BASE_URL="${BASE_URL%/}"
KEYRING="/usr/share/keyrings/${ORIGIN_NAME}.gpg"
LIST="/etc/apt/sources.list.d/${ORIGIN_NAME}.list"
TMP_KEY="$(mktemp)"

cleanup() { rm -f "${TMP_KEY}"; }
trap cleanup EXIT

echo "1/3 下载公钥 → ${KEYRING}"
if ! curl -fsSL "${BASE_URL}/repo-key.gpg" -o "${TMP_KEY}" || [[ ! -s "${TMP_KEY}" ]]; then
  curl -fsSL "${BASE_URL}/repo-key.asc" -o "${TMP_KEY}"
fi
[[ -s "${TMP_KEY}" ]] || {
  echo "错误: 公钥下载失败或为空（检查 ${BASE_URL}/repo-key.gpg）" >&2
  exit 1
}

if grep -q 'BEGIN PGP PUBLIC KEY' "${TMP_KEY}"; then
  gpg --dearmor <"${TMP_KEY}" >"${KEYRING}"
else
  cp -f "${TMP_KEY}" "${KEYRING}"
fi
chmod 644 "${KEYRING}"

echo "2/3 写入源 → ${LIST}"
echo "deb [signed-by=${KEYRING} arch=$(dpkg --print-architecture)] ${BASE_URL} ${SUITE} ${COMPONENT}" >"${LIST}"
echo "  deb [signed-by=${KEYRING}] ${BASE_URL} ${SUITE} ${COMPONENT}"

echo "3/3 apt update"
apt-get update
echo "完成。可安装: sudo apt install <包名>"
