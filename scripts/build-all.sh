#!/usr/bin/env bash
# 为 conf/repo.conf 中全部 SUITES × ARCHITECTURES 构建并发布
# 用法: build-all.sh [--with-toolchain] [--skip-publish]
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

WITH_TOOLCHAIN=0
SKIP_PUBLISH=0
for arg in "$@"; do
  case "${arg}" in
    --with-toolchain) WITH_TOOLCHAIN=1 ;;
    --skip-publish) SKIP_PUBLISH=1 ;;
    *) die "未知参数: ${arg}" ;;
  esac
done

ensure_dirs

for suite in ${SUITES}; do
  for arch in ${ARCHITECTURES}; do
    if [[ "${WITH_TOOLCHAIN}" -eq 1 ]]; then
      "${ROOT_DIR}/scripts/build-toolchain.sh" "${suite}" "${arch}"
    fi
    "${ROOT_DIR}/scripts/build-package.sh" "${suite}" "${arch}"
  done
done

if [[ "${SKIP_PUBLISH}" -eq 0 ]]; then
  "${ROOT_DIR}/scripts/publish.sh"
fi

log "全部套件构建完成"
