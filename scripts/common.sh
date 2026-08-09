#!/usr/bin/env bash
# 公共函数与配置加载
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

deb_version_for_suite() {
  local base_version="$1"
  local suite="$2"
  echo "${base_version}~${suite}1"
}

ensure_dirs() {
  mkdir -p "${REPO_PATH}/pool" "${REPO_PATH}/dists" "${REPO_PATH}/.cache"
  mkdir -p "${PUBLIC_PATH}" "${GPG_HOME_PATH}" "${ROOT_DIR}/keys"
  mkdir -p "${ROOT_DIR}/build" "${ROOT_DIR}/artifacts"
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

# Debian 架构名 → Docker/OCI platform
docker_platform_for_arch() {
  case "$1" in
    amd64) echo "linux/amd64" ;;
    arm64) echo "linux/arm64" ;;
    armhf) echo "linux/arm/v7" ;;
    i386)  echo "linux/386" ;;
    *) die "未知架构，无法映射 Docker platform: $1" ;;
  esac
}

# 预创建官方布局空目录（dists 索引由 generate-repo 填充；pool 按需长出）
ensure_official_layout() {
  local suite component arch letter
  ensure_dirs
  for suite in ${SUITES}; do
    for component in ${COMPONENTS}; do
      for arch in ${ARCHITECTURES}; do
        mkdir -p "${REPO_PATH}/dists/${suite}/${component}/binary-${arch}"
        mkdir -p "${PUBLIC_PATH}/dists/${suite}/${component}/binary-${arch}"
      done
      # pool 官方路径：pool/<component>/<首字母或 lib*>/<pkg>/
      mkdir -p "${REPO_PATH}/pool/${component}"
      mkdir -p "${PUBLIC_PATH}/pool/${component}"
    done
  done
}
