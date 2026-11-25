#!/usr/bin/env bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
kernel="$workspace/kernel"
out="$kernel/out"
artifacts="$workspace/artifacts/raphael"
source_repo='xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150-legacy'

make_args=(
  "O=$out"
  ARCH=arm64
  SUBARCH=arm64
  'CC=ccache clang'
  REAL_CC=clang
  CLANG_TRIPLE=aarch64-linux-gnu-
  CLANG_TRIPLE_ARM32=arm-linux-gnueabi-
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  AS=aarch64-linux-gnu-as
  LD=ld.lld
  LD_ARM32=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  HOSTCC=gcc
  HOSTCXX=g++
  'HOSTCFLAGS=-O2 -Wall -std=gnu89 -fcommon -fuse-ld=lld'
  PYTHON=python3
  KCFLAGS=-Wno-error
)

mkdir -p "$out" "$artifacts"
git -C "$kernel" diff --exit-code HEAD
git -C "$kernel" diff --cached --exit-code

cp "$workspace/configs/raphael/boot.config" "$out/.config"
cp "$workspace/configs/raphael/boot.config" "$artifacts/boot.config"

{
  printf 'Raphael SM8150 legacy stock-source build\n'
  printf 'Source: https://github.com/%s\n' "$source_repo"
  printf 'Source ref: %s\n' "${KERNEL_REF:-lineage-20}"
  printf 'Source commit: %s\n' "$(git -C "$kernel" rev-parse HEAD)"
  printf 'Source patches: none\n'
  printf 'Configuration source: configs/raphael/boot.config (extracted IKCONFIG)\n'
  printf 'Configuration normalization: olddefconfig\n'
  printf 'Compiler: %s\n' "$(clang --version)"
  printf 'Linker: %s\n' "$(ld.lld --version)"
  printf 'Date: %s\n' "$(date -u +%FT%TZ)"
  printf 'Make arguments:'
  printf ' %q' "${make_args[@]}"
  printf '\n'
} > "$artifacts/build_info.txt"

make -C "$kernel" "${make_args[@]}" olddefconfig \
  2>&1 | tee "$artifacts/configure.log"
cp "$out/.config" "$artifacts/kernel.config"

make -C "$kernel" "${make_args[@]}" -j"$(nproc)" Image.gz \
  2>&1 | tee "$artifacts/build.log"
cp "$out/arch/arm64/boot/Image.gz" "$artifacts/Image.gz"
cp "$out/include/config/kernel.release" "$artifacts/kernel.release"
kernel_release=$(< "$out/include/config/kernel.release")
printf 'Kernel release: %s\n' "$kernel_release" >> "$artifacts/build_info.txt"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'kernel_release=%s\n' "$kernel_release" >> "$GITHUB_OUTPUT"
fi

git -C "$kernel" diff --exit-code HEAD
git -C "$kernel" diff --cached --exit-code
ccache --show-stats
