#!/usr/bin/env bash
# 导入 incoming/<suite>/*.deb 到官方 pool/（供本地与 CI 正式发布）
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

INCOMING="${ROOT_DIR}/incoming"
[[ -d "${INCOMING}" ]] || {
  log "无 incoming/ 目录，跳过"
  exit 0
}

count=0
for suite_dir in "${INCOMING}"/*; do
  [[ -d "${suite_dir}" ]] || continue
  suite="$(basename "${suite_dir}")"
  suite_valid "${suite}" || {
    log "跳过未知套件目录: ${suite}"
    continue
  }
  shopt -s nullglob
  for deb in "${suite_dir}"/*.deb; do
    "${ROOT_DIR}/scripts/import-deb.sh" "${suite}" "${deb}" "${DEFAULT_COMPONENT}"
    count=$((count + 1))
  done
  shopt -u nullglob
done

log "incoming 导入完成，共 ${count} 个包"
