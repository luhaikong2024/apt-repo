#!/usr/bin/env bash
# 在指定 Ubuntu 套件环境中从 source/ 构建 .deb，并导入仓库
# 用法: build-package.sh <suite> [arch]
# 环境变量: PACKAGE_NAME PACKAGE_VERSION SKIP_IMPORT=1
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SUITE="${1:-}"
ARCH="${2:-amd64}"

[[ -n "${SUITE}" ]] || die "用法: $0 <suite> [arch]"
suite_valid "${SUITE}" || die "不支持的 suite: ${SUITE}"
arch_valid "${ARCH}" || die "不支持的 arch: ${ARCH}"

PKG_NAME="${PACKAGE_NAME}"
PKG_VER_BASE="${PACKAGE_VERSION}"
PKG_VER="$(deb_version_for_suite "${PKG_VER_BASE}" "${SUITE}")"

SRC="${ROOT_DIR}/source"
PKG_DIR="${ROOT_DIR}/packaging/${PKG_NAME}"
[[ -d "${SRC}" ]] || die "目录不存在: ${SRC}"

if [[ ! -d "${PKG_DIR}/debian" ]]; then
  log "未找到 packaging/${PKG_NAME}/debian，从模板生成"
  "${ROOT_DIR}/scripts/bootstrap-packaging.sh" "${PKG_NAME}"
fi

# 源码探测（允许仅有占位时给出明确错误）
if [[ -z "$(find "${SRC}" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' ! -name 'README*' 2>/dev/null | head -n1)" ]]; then
  die "source/ 为空。请放入软件源码后再构建"
fi

IMAGE="${DOCKER_IMAGE_PREFIX}:${SUITE}-${ARCH}"
OUT="${ROOT_DIR}/artifacts/debs/${SUITE}-${ARCH}"
TC_OUT="${ROOT_DIR}/artifacts/toolchain/${SUITE}-${ARCH}"
PLATFORM="$(docker_platform_for_arch "${ARCH}")"
mkdir -p "${OUT}"

need docker
need dpkg-deb

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  log "构建 Docker 镜像 ${IMAGE} （platform=${PLATFORM}）"
  docker build \
    --platform "${PLATFORM}" \
    --build-arg ARCH="${ARCH}" \
    -t "${IMAGE}" \
    -f "${ROOT_DIR}/docker/Dockerfile.${SUITE}" \
    "${ROOT_DIR}/docker"
fi

USE_TC=0
if [[ -f "${TC_OUT}/.build-ok" ]]; then
  log "检测到工具链产物，将挂载到构建环境: ${TC_OUT}"
  USE_TC=1
fi

INNER_SCRIPT="${OUT}/.inner-build.sh"
cat >"${INNER_SCRIPT}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [[ "${USE_TC}" == "1" && -d /toolchain/root ]]; then
  mkdir -p "${TOOLCHAIN_PREFIX}"
  cp -a /toolchain/root/. /
  export PATH="${TOOLCHAIN_PREFIX}/bin:\${PATH}"
  export LD_LIBRARY_PATH="${TOOLCHAIN_PREFIX}/lib:${TOOLCHAIN_PREFIX}/lib64:\${LD_LIBRARY_PATH:-}"
fi

WORK="/build/\${PACKAGE_NAME}-\${PACKAGE_VERSION}"
rm -rf /build
mkdir -p "\${WORK}"
cp -a /src/app/. "\${WORK}/"
cp -a /src/packaging/debian "\${WORK}/debian"

sed -i "s/@PACKAGE_NAME@/\${PACKAGE_NAME}/g" "\${WORK}/debian/control" "\${WORK}/debian/changelog" || true
sed -i "s/@PACKAGE_VERSION@/\${PACKAGE_VERSION}/g" "\${WORK}/debian/changelog"
sed -i "s/@SUITE@/\${SUITE}/g" "\${WORK}/debian/changelog"
sed -i "s/@DATE@/\$(date -R)/g" "\${WORK}/debian/changelog"

cd "\${WORK}"
if [[ -f build.sh ]]; then
  chmod +x build.sh
  ./build.sh
fi

dpkg-buildpackage -us -uc -b -a"\${ARCH}"
mkdir -p /out
cp -a /build/*.deb /out/ 2>/dev/null || cp -a ../*.deb /out/
ls -la /out
EOF

log "构建软件包 ${PKG_NAME}=${PKG_VER} suite=${SUITE} arch=${ARCH}"

docker_cmd=(
  docker run --rm
  --platform "${PLATFORM}"
  -v "${SRC}:/src/app:ro"
  -v "${PKG_DIR}:/src/packaging:ro"
  -v "${OUT}:/out"
  -v "${INNER_SCRIPT}:/inner-build.sh:ro"
  -e PACKAGE_NAME="${PKG_NAME}"
  -e PACKAGE_VERSION="${PKG_VER}"
  -e SUITE="${SUITE}"
  -e ARCH="${ARCH}"
)

if [[ "${USE_TC}" -eq 1 ]]; then
  docker_cmd+=(
    -v "${TC_OUT}:/toolchain:ro"
    -e TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX}"
    -e USE_CUSTOM_TOOLCHAIN=1
  )
fi

docker_cmd+=("${IMAGE}" bash /inner-build.sh)
"${docker_cmd[@]}"

DEB="$(find "${OUT}" -maxdepth 1 -name "${PKG_NAME}_${PKG_VER}_${ARCH}.deb" -print -quit || true)"
if [[ -z "${DEB}" ]]; then
  DEB="$(find "${OUT}" -maxdepth 1 -name "*.deb" -print -quit || true)"
fi
[[ -n "${DEB}" && -f "${DEB}" ]] || die "未找到构建出的 .deb，请检查 artifacts/debs/${SUITE}-${ARCH}"

log "构建成功: ${DEB}"

if [[ "${SKIP_IMPORT:-0}" != "1" ]]; then
  "${ROOT_DIR}/scripts/import-deb.sh" "${SUITE}" "${DEB}" "${DEFAULT_COMPONENT}"
  "${ROOT_DIR}/scripts/generate-repo.sh"
fi
