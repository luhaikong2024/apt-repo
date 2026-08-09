#!/usr/bin/env bash
# 在指定 Ubuntu 套件环境中编译 toolchain_source/
# 用法: build-toolchain.sh <suite> [arch]
# 产出: artifacts/toolchain/<suite>-<arch>/ 以及可选的 prefix tarball
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SUITE="${1:-}"
ARCH="${2:-amd64}"

[[ -n "${SUITE}" ]] || die "用法: $0 <suite> [arch]"
suite_valid "${SUITE}" || die "不支持的 suite: ${SUITE}"
arch_valid "${ARCH}" || die "不支持的 arch: ${ARCH}"

SRC="${ROOT_DIR}/toolchain_source"
[[ -d "${SRC}" ]] || die "目录不存在: ${SRC}"

# 探测是否有可构建内容
if [[ ! -f "${SRC}/CMakeLists.txt" && ! -f "${SRC}/configure" && ! -f "${SRC}/Makefile" && ! -f "${SRC}/build.sh" ]]; then
  die "toolchain_source/ 尚无构建入口。请放入源码，并提供以下之一: build.sh / CMakeLists.txt / configure / Makefile"
fi

IMAGE="${DOCKER_IMAGE_PREFIX}:${SUITE}-${ARCH}"
OUT="${ROOT_DIR}/artifacts/toolchain/${SUITE}-${ARCH}"
PLATFORM="$(docker_platform_for_arch "${ARCH}")"
mkdir -p "${OUT}"

need docker

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  log "构建 Docker 镜像 ${IMAGE} （platform=${PLATFORM}）"
  docker build \
    --platform "${PLATFORM}" \
    --build-arg ARCH="${ARCH}" \
    -t "${IMAGE}" \
    -f "${ROOT_DIR}/docker/Dockerfile.${SUITE}" \
    "${ROOT_DIR}/docker"
fi

log "编译工具链 suite=${SUITE} arch=${ARCH} platform=${PLATFORM}"
docker run --rm \
  --platform "${PLATFORM}" \
  -v "${SRC}:/src/toolchain:ro" \
  -v "${OUT}:/out" \
  -e TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX}" \
  -e SUITE="${SUITE}" \
  -e ARCH="${ARCH}" \
  "${IMAGE}" \
  bash -lc '
    set -euo pipefail
    mkdir -p /build/toolchain /out
    cp -a /src/toolchain/. /build/toolchain/
    cd /build/toolchain
    if [[ -f build.sh ]]; then
      chmod +x build.sh
      ./build.sh --prefix "${TOOLCHAIN_PREFIX}" --out /out
    elif [[ -f CMakeLists.txt ]]; then
      cmake -S . -B /build/tc-build -DCMAKE_INSTALL_PREFIX="${TOOLCHAIN_PREFIX}"
      cmake --build /build/tc-build -j"$(nproc)"
      DESTDIR=/out/root cmake --install /build/tc-build
    elif [[ -f configure ]]; then
      ./configure --prefix="${TOOLCHAIN_PREFIX}"
      make -j"$(nproc)"
      make DESTDIR=/out/root install
    else
      make -j"$(nproc)" PREFIX="${TOOLCHAIN_PREFIX}"
      make PREFIX="${TOOLCHAIN_PREFIX}" DESTDIR=/out/root install
    fi
    tar -C /out/root -czf "/out/toolchain-${SUITE}-${ARCH}.tar.gz" .
    echo "OK" > /out/.build-ok
  '

log "工具链产物: ${OUT}"
