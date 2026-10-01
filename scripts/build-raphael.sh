#!/usr/bin/env bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
kernel="$workspace/kernel"
out="$kernel/out"
artifacts="$workspace/artifacts/raphael"
enable_resukisu="${ENABLE_RESUKISU:-false}"
kernel_name="${KERNEL_NAME:-}"

if [[ ! "$kernel_name" =~ ^[A-Za-z0-9._-]*$ ]]; then
  printf 'Kernel name may contain only letters, digits, dots, underscores and hyphens.\n' >&2
  exit 1
fi

localversion='-englezos'
if [[ -n "$kernel_name" ]]; then
  localversion+="-$kernel_name"
fi
if [[ "$enable_resukisu" == true ]]; then
  localversion+='-ReSukiSU'
fi

mkdir -p "$out" "$artifacts"
cp "$workspace/configs/raphael/boot.config" "$out/.config"
cp "$workspace/configs/raphael/boot.config" "$artifacts/boot.config"

# Linux 4.14 does not implement the modern LLVM=1 / LLVM_IAS=1 switches.
# Its Makefile uses -no-integrated-as, so GNU cross-binutils are required.
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

# Keep the boot configuration as the baseline. The compiler's +lto tag
# describes its own build; boot.config explicitly selects LTO_NONE.
config="$kernel/scripts/config"
"$config" --file "$out/.config" \
  --disable LOCALVERSION_AUTO \
  --set-str LOCALVERSION "$localversion" \
  --disable CC_WERROR \
  --disable LTO \
  --disable LTO_CLANG \
  --enable LTO_NONE \
  --disable CFI \
  --disable CFI_CLANG \
  --disable BUILD_ARM64_APPENDED_DTB_IMAGE \
  --enable KALLSYMS \
  --enable KALLSYMS_ALL

if [[ "$enable_resukisu" == true ]]; then
  "$config" --file "$out/.config" \
    --enable KSU \
    --enable KSU_MANUAL_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_INITRC_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_INPUT_HOOK \
    --disable KSU_TRACEPOINT_HOOK \
    --disable KSU_SUSFS
else
  "$config" --file "$out/.config" --disable KSU
fi

{
  printf 'Raphael kernel build\n'
  printf 'Source: https://github.com/penglezos/kernel_xiaomi_raphael\n'
  printf 'Source ref: %s\n' "${KERNEL_REF:-lineage-20}"
  printf 'Source commit: %s\n' "$(git -C "$kernel" rev-parse HEAD)"
  printf 'Boot kernel: 4.14.350-englezos-a8c95a375c\n'
  printf 'Boot config header: Linux/arm64 4.14.170\n'
  printf 'Compiler: %s\n' "$(clang --version)"
  printf 'Linker: %s\n' "$(ld.lld --version)"
  printf 'ReSukiSU enabled: %s\n' "$enable_resukisu"
  if [[ "$enable_resukisu" == true ]]; then
    printf 'ReSukiSU commit: %s\n' "$(git -C "$kernel/KernelSU" rev-parse HEAD)"
  fi
  printf 'Date: %s\n' "$(date -u +%FT%TZ)"
  printf 'Make arguments:'
  printf ' %q' "${make_args[@]}"
  printf '\n'
} > "$artifacts/build_info.txt"

make -C "$kernel" "${make_args[@]}" olddefconfig \
  2>&1 | tee "$artifacts/configure.log"
cp "$out/.config" "$artifacts/kernel.config"

if [[ "$enable_resukisu" == true ]]; then
  for symbol in KSU KSU_MANUAL_HOOK KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
    KSU_MANUAL_HOOK_AUTO_INITRC_HOOK KSU_MANUAL_HOOK_AUTO_INPUT_HOOK KALLSYMS_ALL; do
    grep -Fxq "CONFIG_$symbol=y" "$out/.config" || {
      printf 'Required configuration is missing: CONFIG_%s=y\n' "$symbol" >&2
      exit 1
    }
  done
fi

make -C "$kernel" "${make_args[@]}" -j"$(nproc)" Image.gz \
  2>&1 | tee "$artifacts/build.log"
cp "$out/arch/arm64/boot/Image.gz" "$artifacts/Image.gz"
cp "$out/include/config/kernel.release" "$artifacts/kernel.release"
kernel_release=$(< "$out/include/config/kernel.release")
printf 'Kernel release: %s\n' "$kernel_release" >> "$artifacts/build_info.txt"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'kernel_release=%s\n' "$kernel_release" >> "$GITHUB_OUTPUT"
fi
ccache --show-stats
