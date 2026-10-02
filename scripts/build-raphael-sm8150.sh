#!/usr/bin/env bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
kernel="$workspace/kernel"
out="$kernel/out"
artifacts="$workspace/artifacts/raphael"
enable_resukisu="${ENABLE_RESUKISU:-false}"
variant="${KERNEL_VARIANT:-lineage22}"
platform_symbols=(ARCH_SM8150 MACH_XIAOMI MACH_XIAOMI_SM8150 MACH_XIAOMI_RAPHAEL)

case "$variant" in
  lineage22)
    KERNEL_REPOSITORY=xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150
    KERNEL_REF="${KERNEL_REF:-lineage-22.2}"
    KERNEL_CONFIG=configs/raphael/boot.config
    RESUKISU_HOOK_PATCH=patch/raphael/resukisu-manual-hooks-4.14.patch
    CLANG_REVISION=clang-r487747c
    CLANG_COMMIT=425c8149f17c8d9914bf690b4d5abe45a13fb993
    CLANG_VERSION=17.0.2
    CLANG_BUILD=10087095
    KERNEL_FLAVOR=Lineage22
    ARTIFACT_PREFIX=raphael-sm8150-lineage22
    platform_symbols+=(MFD_SPK_ID)
    ;;
  crdroid15)
    KERNEL_REPOSITORY=crdroidandroid/android_kernel_xiaomi_sm8150
    KERNEL_REF="${KERNEL_REF:-15.0-raphael}"
    KERNEL_CONFIG=configs/raphael/evolutionx-15.0-20250609.config
    RESUKISU_HOOK_PATCH=patch/raphael/resukisu-crdroid15-hooks.patch
    CLANG_REVISION=clang-r522817
    CLANG_COMMIT=921f6da692b1ffc96a0daa7e741373f0089d40b0
    CLANG_VERSION=18.0.1
    CLANG_BUILD=11967740
    KERNEL_FLAVOR=crDroid15
    ARTIFACT_PREFIX=raphael-sm8150-crdroid15
    ;;
  *)
    printf 'Unknown kernel source profile: %s\n' "$variant" >&2
    exit 2
    ;;
esac

verify_source() {
  if [[ "$enable_resukisu" == true ]]; then
    git -C "$kernel" diff --binary HEAD \
      | cmp - "$artifacts/kernel-source.patch"
    git -C "$kernel" apply --reverse --check \
      "$workspace/$RESUKISU_HOOK_PATCH"
    git -C "$kernel/KernelSU" diff --exit-code HEAD
    git -C "$kernel/KernelSU" diff --cached --exit-code
  else
    git -C "$kernel" diff --exit-code HEAD
  fi
  git -C "$kernel" diff --cached --exit-code
}

case "${1:-build}" in
  build) ;;
  --export-profile)
    for name in KERNEL_REPOSITORY KERNEL_REF KERNEL_CONFIG RESUKISU_HOOK_PATCH \
      CLANG_REVISION CLANG_COMMIT CLANG_VERSION CLANG_BUILD KERNEL_FLAVOR ARTIFACT_PREFIX; do
      printf '%s=%s\n' "$name" "${!name}" | tee -a "${GITHUB_ENV:?}"
    done
    exit 0
    ;;
  --verify-source)
    verify_source
    exit 0
    ;;
  *)
    printf 'Usage: %s [--export-profile | --verify-source]\n' "$0" >&2
    exit 2
    ;;
esac

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
verify_source

cp "$workspace/$KERNEL_CONFIG" "$out/.config"
cp "$workspace/$KERNEL_CONFIG" "$artifacts/boot.config"

# Raphael selects the Xiaomi SM8150 and Xiaomi platform symbols through Kconfig.
# The audio codecs also require the built-in Xiaomi speaker ID provider.
if [[ "$variant" == lineage22 ]]; then
  "$kernel/scripts/config" --file "$out/.config" \
    --enable MACH_XIAOMI_RAPHAEL \
    --enable MFD_SPK_ID
else
  # crDroid defaults to Polly; the extracted boot config does not enable it.
  "$kernel/scripts/config" --file "$out/.config" --disable POLLY_CLANG
fi

if [[ "$enable_resukisu" == true ]]; then
  "$kernel/scripts/config" --file "$out/.config" \
    --enable KSU \
    --enable KSU_MANUAL_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_INITRC_HOOK \
    --enable KSU_MANUAL_HOOK_AUTO_INPUT_HOOK \
    --enable KALLSYMS \
    --enable KALLSYMS_ALL \
    --disable KSU_TRACEPOINT_HOOK \
    --disable KSU_SUSFS
else
  "$kernel/scripts/config" --file "$out/.config" --disable KSU
fi

{
  printf 'Raphael SM8150 build\n'
  printf 'Source profile: %s\n' "$variant"
  printf 'Source: https://github.com/%s\n' "$KERNEL_REPOSITORY"
  printf 'Source ref: %s\n' "$KERNEL_REF"
  printf 'Source commit: %s\n' "$(git -C "$kernel" rev-parse HEAD)"
  printf 'ReSukiSU enabled: %s\n' "$enable_resukisu"
  if [[ "$enable_resukisu" == true ]]; then
    printf 'ReSukiSU source: https://github.com/ReSukiSU/ReSukiSU\n'
    printf 'ReSukiSU ref: %s\n' "$RESUKISU_REF"
    printf 'ReSukiSU commit: %s\n' "$(git -C "$kernel/KernelSU" rev-parse HEAD)"
    printf 'Source patches: ReSukiSU driver registration and manual hooks\n'
    printf 'Hook patch: %s\n' "$RESUKISU_HOOK_PATCH"
    printf 'ReSukiSU configuration: KSU=y KSU_MANUAL_HOOK=y; automatic input/setuid/init.rc hooks; KALLSYMS_ALL=y\n'
  else
    printf 'Source patches: none\n'
  fi
  printf 'Configuration source: %s (extracted IKCONFIG)\n' "$KERNEL_CONFIG"
  if [[ "$variant" == lineage22 ]]; then
    printf 'Configuration overrides: MACH_XIAOMI_RAPHAEL=y MFD_SPK_ID=y\n'
  else
    printf 'Configuration overrides: POLLY_CLANG=n (matching AOSP boot toolchain)\n'
  fi
  printf 'Configuration SHA256: %s\n' "$(sha256sum "$workspace/$KERNEL_CONFIG")"
  printf 'Configuration normalization: olddefconfig\n'
  printf 'Compiler: %s\n' "$(clang --version)"
  printf 'Linker: %s\n' "$(ld.lld --version)"
  printf 'Toolchain revision: %s; build: %s; prebuilt commit: %s\n' \
    "$CLANG_REVISION" "$CLANG_BUILD" "$CLANG_COMMIT"
  printf 'Date: %s\n' "$(date -u +%FT%TZ)"
  printf 'Make arguments:'
  printf ' %q' "${make_args[@]}"
  printf '\n'
} > "$artifacts/build_info.txt"

make -C "$kernel" "${make_args[@]}" olddefconfig \
  2>&1 | tee "$artifacts/configure.log"
cp "$out/.config" "$artifacts/kernel.config"

printf 'Required platform configuration after olddefconfig:\n' \
  | tee "$artifacts/platform-config.log"
for symbol in "${platform_symbols[@]}"; do
  grep -Fx "CONFIG_$symbol=y" "$out/.config" \
    | tee -a "$artifacts/platform-config.log" || {
      printf 'Required configuration is missing: CONFIG_%s=y\n' "$symbol" >&2
      exit 1
    }
done

if [[ "$variant" == crdroid15 ]]; then
  grep -Fx '# CONFIG_POLLY_CLANG is not set' "$out/.config"
fi

if [[ "$enable_resukisu" == true ]]; then
  printf 'Required ReSukiSU configuration after olddefconfig:\n' \
    | tee "$artifacts/resukisu-config.log"
  for symbol in KSU KSU_MANUAL_HOOK KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
    KSU_MANUAL_HOOK_AUTO_INITRC_HOOK KSU_MANUAL_HOOK_AUTO_INPUT_HOOK \
    KALLSYMS KALLSYMS_ALL COMPAT SECURITY SECURITY_SELINUX INPUT; do
    grep -Fx "CONFIG_$symbol=y" "$out/.config" \
      | tee -a "$artifacts/resukisu-config.log" || {
        printf 'Required configuration is missing: CONFIG_%s=y\n' "$symbol" >&2
        exit 1
      }
  done
  for symbol in KSU_TRACEPOINT_HOOK KSU_SUSFS; do
    if grep -Eq "^CONFIG_$symbol=[ym]$" "$out/.config"; then
      printf 'Incompatible hook method is enabled: CONFIG_%s\n' "$symbol" >&2
      exit 1
    fi
  done
fi

make -C "$kernel" "${make_args[@]}" -j"$(nproc)" Image.gz \
  2>&1 | tee "$artifacts/build.log"

if [[ "$enable_resukisu" == true ]]; then
  llvm-nm --defined-only "$out/vmlinux" \
    | grep -E '[[:space:]][Tt][[:space:]]+ksu_handle_(execveat|post_execveat|stat|newfstat_ret|fstat64_ret|faccessat|sys_reboot)$' \
    | tee "$artifacts/resukisu-symbols.log"
  for symbol in ksu_handle_execveat ksu_handle_post_execveat ksu_handle_stat \
    ksu_handle_newfstat_ret ksu_handle_fstat64_ret ksu_handle_faccessat \
    ksu_handle_sys_reboot; do
    grep -Eq "[[:space:]][Tt][[:space:]]+$symbol$" "$artifacts/resukisu-symbols.log" || {
      printf 'Linked ReSukiSU hook symbol is missing: %s\n' "$symbol" >&2
      exit 1
    }
  done
fi

cp "$out/arch/arm64/boot/Image.gz" "$artifacts/Image.gz"
cp "$out/include/config/kernel.release" "$artifacts/kernel.release"
kernel_release=$(< "$out/include/config/kernel.release")
printf 'Kernel release: %s\n' "$kernel_release" >> "$artifacts/build_info.txt"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'kernel_release=%s\n' "$kernel_release" >> "$GITHUB_OUTPUT"
fi

verify_source
ccache --show-stats
