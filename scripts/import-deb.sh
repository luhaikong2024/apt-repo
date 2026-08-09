#!/usr/bin/env bash
# 将 .deb 导入官方布局的 pool/
# 用法: import-deb.sh <suite> <deb文件> [component]
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_dirs
need dpkg-deb

SUITE="${1:-}"
DEB_FILE="${2:-}"
COMPONENT="${3:-${DEFAULT_COMPONENT}}"

[[ -n "${SUITE}" && -n "${DEB_FILE}" ]] || die "用法: $0 <suite> <deb文件> [component]"
suite_valid "${SUITE}" || die "不支持的 suite: ${SUITE}（允许: ${SUITES}）"
[[ -f "${DEB_FILE}" ]] || die "文件不存在: ${DEB_FILE}"
[[ "${DEB_FILE}" == *.deb ]] || die "不是 .deb 文件: ${DEB_FILE}"

PKG_NAME="$(dpkg-deb -f "${DEB_FILE}" Package)"
PKG_VERSION="$(dpkg-deb -f "${DEB_FILE}" Version)"
PKG_ARCH="$(dpkg-deb -f "${DEB_FILE}" Architecture)"

# 版本中应包含 ~suite，便于按套件过滤索引
if [[ "${PKG_VERSION}" != *"~${SUITE}"* ]]; then
  log "警告: 包版本 ${PKG_VERSION} 未包含 ~${SUITE}，仍将导入；生成索引时可能被跳过"
fi

SUBDIR="$(pool_subdir_for_package "${PKG_NAME}")"
DEST_DIR="${REPO_PATH}/pool/${COMPONENT}/${SUBDIR}"
mkdir -p "${DEST_DIR}"

BASENAME="$(basename "${DEB_FILE}")"
DEST="${DEST_DIR}/${BASENAME}"
cp -f "${DEB_FILE}" "${DEST}"

# 记录该 deb 所属 suite（供 generate-repo 精确过滤）
META_DIR="${REPO_PATH}/.meta/suites/${SUITE}"
mkdir -p "${META_DIR}"
# 相对 repo 根的路径
REL="pool/${COMPONENT}/${SUBDIR}/${BASENAME}"
echo "${REL}" >>"${META_DIR}/files.list"
sort -u -o "${META_DIR}/files.list" "${META_DIR}/files.list"

log "已导入: ${REL}"
log "  Package=${PKG_NAME} Version=${PKG_VERSION} Arch=${PKG_ARCH} Suite=${SUITE} Component=${COMPONENT}"
