#!/usr/bin/env bash
# 为 dists/<suite>/Release 生成 InRelease 与 Release.gpg
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_dirs
need gpg

export GNUPGHOME="${GPG_HOME_PATH}"

if [[ ! -d "${GNUPGHOME}" ]] || ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'; then
  die "未找到签名密钥，请先运行: scripts/init-gpg.sh"
fi

KEY_ID="${SIGNING_KEY_ID}"
if [[ -z "${KEY_ID}" ]]; then
  KEY_ID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
fi
[[ -n "${KEY_ID}" ]] || die "无法确定 SIGNING_KEY_ID"

for suite in ${SUITES}; do
  release="${REPO_PATH}/dists/${suite}/Release"
  [[ -f "${release}" ]] || continue

  # clearsign → InRelease
  gpg --batch --yes --default-key "${KEY_ID}" \
    --clearsign -o "${REPO_PATH}/dists/${suite}/InRelease" "${release}"

  # detach sign → Release.gpg
  gpg --batch --yes --default-key "${KEY_ID}" \
    --detach-sign -o "${REPO_PATH}/dists/${suite}/Release.gpg" "${release}"

  log "已签名: dists/${suite}/InRelease , Release.gpg"
done

# 确保公钥在 keys/ 与即将发布的 public/
gpg --export --armor "${KEY_ID}" >"${GPG_PUBLIC_KEY_PATH}"
log "公钥: ${GPG_PUBLIC_KEY_PATH}"
