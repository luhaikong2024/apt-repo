#!/usr/bin/env bash
# 根据 pool/ 与 .meta 生成官方 dists/ 索引（Packages / Release）
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_dirs
need apt-ftparchive
need gzip
need xz

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

generate_packages_for() {
  local suite="$1" component="$2" arch="$3"
  local out_dir="${REPO_PATH}/dists/${suite}/${component}/binary-${arch}"
  local meta_list="${REPO_PATH}/.meta/suites/${suite}/files.list"
  local scan_dir="${TMP_ROOT}/${suite}-${component}-${arch}"

  mkdir -p "${out_dir}" "${scan_dir}"

  # 收集属于该 suite、且架构匹配（或 all）的 deb
  local count=0
  if [[ -f "${meta_list}" ]]; then
    while IFS= read -r rel || [[ -n "${rel}" ]]; do
      [[ -z "${rel}" || "${rel}" =~ ^# ]] && continue
      local abs="${REPO_PATH}/${rel}"
      [[ -f "${abs}" ]] || continue
      local deb_arch
      deb_arch="$(dpkg-deb -f "${abs}" Architecture)"
      if [[ "${deb_arch}" == "${arch}" || "${deb_arch}" == "all" ]]; then
        # 仅链接到临时目录，让 Filename 相对路径正确需特殊处理
        ln -sfn "${abs}" "${scan_dir}/$(basename "${abs}")"
        count=$((count + 1))
      fi
    done <"${meta_list}"
  fi

  local pkg_file="${out_dir}/Packages"
  if [[ "${count}" -eq 0 ]]; then
    : >"${pkg_file}"
  else
    # apt-ftparchive 生成的 Filename 是相对 scan 目录的 basename
    # 需要改写为 pool/... 官方路径
    apt-ftparchive packages "${scan_dir}" >"${pkg_file}.raw"
    : >"${pkg_file}"
    local current_file=""
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" == Filename:* ]]; then
        local bn
        bn="$(echo "${line}" | awk '{print $2}')"
        bn="$(basename "${bn}")"
        # 从 meta 反查完整 pool 路径
        local full
        full="$(grep -E "/${bn}\$" "${meta_list}" | head -n1 || true)"
        if [[ -n "${full}" ]]; then
          echo "Filename: ${full}" >>"${pkg_file}"
        else
          echo "Filename: pool/${component}/$(pool_subdir_for_package "$(dpkg-deb -f "${scan_dir}/${bn}" Package)")/${bn}" >>"${pkg_file}"
        fi
      else
        echo "${line}" >>"${pkg_file}"
      fi
    done <"${pkg_file}.raw"
    rm -f "${pkg_file}.raw"
  fi

  gzip -9c "${pkg_file}" >"${pkg_file}.gz"
  xz -9c "${pkg_file}" >"${pkg_file}.xz"

  # Release（组件级）
  cat >"${out_dir}/Release" <<EOF
Archive: ${suite}
Component: ${component}
Origin: ${ORIGIN}
Label: ${LABEL}
Architecture: ${arch}
EOF

  log "生成 ${suite}/${component}/binary-${arch} （${count} 个包）"
}

generate_suite_release() {
  local suite="$1"
  local suite_dir="${REPO_PATH}/dists/${suite}"
  mkdir -p "${suite_dir}"

  local release_file="${suite_dir}/Release"
  local now
  now="$(date -u '+%a, %d %b %Y %H:%M:%S UTC')"

  cat >"${release_file}" <<EOF
Origin: ${ORIGIN}
Label: ${LABEL}
Suite: ${suite}
Codename: ${suite}
Version: 1.0
Architectures: ${ARCHITECTURES}
Components: ${COMPONENTS}
Description: ${DESCRIPTION}
Date: ${now}
EOF

  # 追加 MD5Sum / SHA256
  (
    cd "${suite_dir}"
    echo "MD5Sum:"
    find ${COMPONENTS} -type f \( -name 'Packages' -o -name 'Packages.gz' -o -name 'Packages.xz' -o -name 'Release' \) 2>/dev/null \
      | sort | while read -r f; do
          # shellcheck disable=SC2012
          size="$(wc -c <"${f}" | tr -d ' ')"
          hash="$(md5sum "${f}" | awk '{print $1}')"
          printf " %s %8s %s\n" "${hash}" "${size}" "${f}"
        done
    echo "SHA256:"
    find ${COMPONENTS} -type f \( -name 'Packages' -o -name 'Packages.gz' -o -name 'Packages.xz' -o -name 'Release' \) 2>/dev/null \
      | sort | while read -r f; do
          size="$(wc -c <"${f}" | tr -d ' ')"
          hash="$(sha256sum "${f}" | awk '{print $1}')"
          printf " %s %8s %s\n" "${hash}" "${size}" "${f}"
        done
  ) >>"${release_file}"

  log "生成 dists/${suite}/Release"
}

log "开始生成仓库索引 → ${REPO_PATH}"
ensure_official_layout

for suite in ${SUITES}; do
  for component in ${COMPONENTS}; do
    for arch in ${ARCHITECTURES}; do
      generate_packages_for "${suite}" "${component}" "${arch}"
    done
  done
  generate_suite_release "${suite}"
done

if [[ "${ENABLE_SIGNING}" == "yes" ]]; then
  "${ROOT_DIR}/scripts/sign-repo.sh"
else
  log "ENABLE_SIGNING!=yes，跳过签名"
fi

log "索引生成完成"
