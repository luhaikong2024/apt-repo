#!/usr/bin/env bash
# 初始化仓库签名用 GPG 密钥（一次性）
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_dirs
need gpg

NAME="${GPG_NAME:-APT Repo Signing Key}"
EMAIL="${GPG_EMAIL:-apt-repo@localhost}"
EXPIRE="${GPG_EXPIRE:-0}"

export GNUPGHOME="${GPG_HOME_PATH}"
chmod 700 "${GNUPGHOME}"

if gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'; then
  log "已存在私钥，跳过生成"
else
  log "生成 GPG 密钥: ${NAME} <${EMAIL}>"
  cat >"${GNUPGHOME}/keygen.batch" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Key-Usage: sign
Name-Real: ${NAME}
Name-Email: ${EMAIL}
Expire-Date: ${EXPIRE}
%commit
EOF
  gpg --batch --generate-key "${GNUPGHOME}/keygen.batch"
  rm -f "${GNUPGHOME}/keygen.batch"
fi

KEY_ID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
[[ -n "${KEY_ID}" ]] || die "未能读取 KEY_ID"

gpg --export --armor "${KEY_ID}" >"${GPG_PUBLIC_KEY_PATH}"
# 二进制公钥，便于客户端 apt-key / signed-by
gpg --export "${KEY_ID}" >"${ROOT_DIR}/keys/repo-public.gpg.bin"

# 写回 SIGNING_KEY_ID 提示
log "密钥 ID: ${KEY_ID}"
log "公钥已导出: ${GPG_PUBLIC_KEY_PATH}"
log "请在 conf/repo.conf 中设置: SIGNING_KEY_ID=\"${KEY_ID}\""

# 若配置为空则自动写入
if grep -q '^SIGNING_KEY_ID=""$' "${CONF_FILE}" 2>/dev/null || grep -q "^SIGNING_KEY_ID=''$" "${CONF_FILE}" 2>/dev/null; then
  sed -i "s/^SIGNING_KEY_ID=.*/SIGNING_KEY_ID=\"${KEY_ID}\"/" "${CONF_FILE}"
  log "已自动写入 conf/repo.conf 的 SIGNING_KEY_ID"
fi
