#!/usr/bin/env bash
# 公共函数与配置加载（APT 分发仓）
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF_FILE="${ROOT_DIR}/conf/repo.conf"

if [[ ! -f "${CONF_FILE}" ]]; then
  echo "缺少配置文件: ${CONF_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${CONF_FILE}"

REPO_PATH="${ROOT_DIR}/${REPO_DIR}"
PUBLIC_PATH="${ROOT_DIR}/${PUBLIC_DIR}"
GPG_HOME_PATH="${ROOT_DIR}/${GPG_HOME}"
GPG_PUBLIC_KEY_PATH="${ROOT_DIR}/${GPG_PUBLIC_KEY}"

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die()  { echo "错误: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "需要命令: $1"; }

pool_subdir_for_package() {
  local name="$1"
  local first
  first="$(echo "${name}" | cut -c1)"
  if [[ "${name}" == lib* ]]; then
    first="$(echo "${name}" | cut -c1-4)"
  fi
  echo "${first}/${name}"
}

ensure_dirs() {
  mkdir -p "${REPO_PATH}/pool" "${REPO_PATH}/dists" "${REPO_PATH}/.cache"
  mkdir -p "${PUBLIC_PATH}" "${GPG_HOME_PATH}" "${ROOT_DIR}/keys"
  for suite in ${SUITES}; do
    mkdir -p "${ROOT_DIR}/incoming/${suite}"
  done
}

suite_valid() {
  local suite="$1"
  for s in ${SUITES}; do
    [[ "${s}" == "${suite}" ]] && return 0
  done
  return 1
}

arch_valid() {
  local arch="$1"
  for a in ${ARCHITECTURES}; do
    [[ "${a}" == "${arch}" ]] && return 0
  done
  return 1
}

ensure_official_layout() {
  local suite component arch
  ensure_dirs
  for suite in ${SUITES}; do
    for component in ${COMPONENTS}; do
      for arch in ${ARCHITECTURES}; do
        mkdir -p "${REPO_PATH}/dists/${suite}/${component}/binary-${arch}"
        mkdir -p "${PUBLIC_PATH}/dists/${suite}/${component}/binary-${arch}"
      done
      mkdir -p "${REPO_PATH}/pool/${component}"
      mkdir -p "${PUBLIC_PATH}/pool/${component}"
    done
  done
}
