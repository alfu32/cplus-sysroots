#!/usr/bin/env bash
set -euo pipefail

reference=${1:?reference is required}
output=${2:?output directory is required}
target=${reference%-dev}
target=${target%-rt}
kind=${reference##*-}
arch=${target%%-*}

case "$target" in
  *-unknown-linux-musl) family=musl ;;
  *-unknown-linux-gnu) family=gnu ;;
  *) echo "not a Linux reference: $reference" >&2; exit 2 ;;
esac

case "$arch" in
  x86_64) platform=linux/amd64 ;;
  arm64) platform=linux/arm64 ;;
  riscv64) platform=linux/riscv64 ;;
  loongarch64) platform=linux/loong64 ;;
  *) echo "unsupported Linux architecture: $arch" >&2; exit 2 ;;
esac

if [[ "$family" == musl ]]; then
  image=${ALPINE_IMAGE:-alpine:3.21}
  packages='musl'
  [[ "$kind" == dev ]] && packages='musl-dev gcc libgcc'
  container="cplus-sysroot-${reference//[^A-Za-z0-9]/-}"
  cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
  trap cleanup EXIT
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker create --platform "$platform" --name "$container" "$image" sh -c 'sleep 3600' >/dev/null
  docker start "$container" >/dev/null
  docker exec "$container" sh -euxc "apk add --no-cache $packages"
  docker exec "$container" sh -euxc '
    mkdir -p /out
    test "'$kind'" != dev || cp -a /usr/include /out/
    cp -a /usr/lib /out/
    cp -a /lib /out/
  '
else
  case "$arch" in
    x86_64) image=${GLIBC_IMAGE_X86_64:-quay.io/pypa/manylinux2014_x86_64} ;;
    arm64) image=${GLIBC_IMAGE_ARM64:-quay.io/pypa/manylinux2014_aarch64} ;;
    riscv64) image=${GLIBC_IMAGE_RISCV64:-riscv64/debian:experimental} ;;
    loongarch64) image=${GLIBC_IMAGE_LOONGARCH64:-ghcr.io/loong64/debian:trixie-slim} ;;
  esac
  container="cplus-sysroot-${reference//[^A-Za-z0-9]/-}"
  cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
  trap cleanup EXIT
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker create --platform "$platform" --name "$container" "$image" sh -c 'sleep 3600' >/dev/null
  docker start "$container" >/dev/null
  docker exec "$container" sh -euxc "
    if command -v yum >/dev/null 2>&1; then
      if [ '$kind' = dev ]; then
        yum install -y glibc-devel gcc libgcc
      else
        yum install -y glibc
      fi
    else
      apt-get update
      if [ '$kind' = dev ]; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libc6-dev gcc libgcc-dev
      else
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libc6
      fi
    fi
  "
  docker exec "$container" sh -euxc '
    mkdir -p /out
    mkdir -p /out/usr
    test "'$kind'" != dev || cp -a /usr/include /out/usr/
    cp -a /usr/lib /out/usr/
    test ! -e /usr/lib64 || cp -a /usr/lib64 /out/usr/
    test ! -e /lib || cp -a /lib /out/
    test ! -e /lib64 || cp -a /lib64 /out/
  '
fi

if [[ "$family" == musl ]]; then
  libc_version=$(docker exec "$container" sh -c "apk info -v musl | head -n 1" | tr -d '\r\n')
else
  libc_version=$(docker exec "$container" sh -c "if command -v rpm >/dev/null 2>&1; then rpm -q glibc; else dpkg-query -W -f='\${Version}' libc6; fi" | tr -d '\r\n')
fi
image_digest=$(docker image inspect --format '{{index .RepoDigests 0}}' "$image" 2>/dev/null || true)

rm -rf "$output"
mkdir -p "$output"
docker exec "$container" tar -C /out -cf - . | tar --no-same-owner -xf - -C "$output"
printf '{"image":"%s","image_digest":"%s","platform":"%s","family":"%s","arch":"%s","libc_version":"%s"}\n' "$image" "$image_digest" "$platform" "$family" "$arch" "$libc_version" > "$output/.stage-metadata.json"
docker rm -f "$container" >/dev/null
