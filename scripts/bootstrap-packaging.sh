#!/usr/bin/env bash
# 从模板生成 packaging/<package>/debian
# 用法: bootstrap-packaging.sh [package_name]
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

PKG_NAME="${1:-${PACKAGE_NAME}}"
DEST="${ROOT_DIR}/packaging/${PKG_NAME}/debian"
TEMPLATE="${ROOT_DIR}/packaging/templates/debian"

[[ -d "${TEMPLATE}" ]] || die "模板不存在: ${TEMPLATE}"

if [[ -d "${DEST}" ]]; then
  log "已存在 ${DEST}，跳过"
  exit 0
fi

mkdir -p "${DEST}"
cp -a "${TEMPLATE}/." "${DEST}/"

# 替换包名占位
find "${DEST}" -type f -exec sed -i "s/@PACKAGE_NAME@/${PKG_NAME}/g" {} +

log "已生成 debian 打包元数据: ${DEST}"
log "请按实际项目修改 rules / control / install 等文件"
