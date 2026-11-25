#!/usr/bin/env bash
set -euo pipefail

# OnePlus 7 (guacamoleb) SM8150 kernel build for Evolution X A15 / A16 ROMs.
#
# Kernel refs and boot layouts are pinned to the states the official
# Evolution X builds actually shipped, verified against the CDN boot.img
# banners and their embedded IKCONFIG (CONFIG_IKCONFIG=y):
#   /15/boot.img:  4.14.356-openela-rc1-✨Caelum-OnePlus-7, built
#                  2025-06-04 with Android (12701618) clang 19.0.1
#                  (based on r536225); IKCONFIG: BUILD_ARM64_APPENDED_DTB_IMAGE=y,
#                  LOCALVERSION_AUTO=n, QCA_CLD_WLAN=y.
#   /16/boot.img:  4.14.356-openela-rc1-perf-gce1fce98e3f9 (official 11.6.3,
#                  2026-04-15), built with Android (14054515) clang 21.0.0
#                  (based on r563880c); IKCONFIG: LOCALVERSION="-perf" +
#                  LOCALVERSION_AUTO=y, QCA_CLD_WLAN=m, no appended DTB.
#   The bka branch tip (6ddfa33, 4.14.357-openela) is NEWER than the 11.6.3
#   release kernel; ce1fce98 below is the exact 11.6.3 state.
#
# Modes (EVOX_ANDROID):
#   a16 (default): Evolution X 11.x. Kernel source
#     Evolution-X-Devices/kernel_oneplus_sm8150 @ ce1fce98e3f97beb4a3379da3934d6136577e08a
#     (the exact official 11.6.3 kernel commit), defconfig
#     vendor/sm8150-perf_defconfig with the vendor/oplus.config fragment
#     merged by kbuild's %.config rule, target Image (DTB travels in the
#     boot image's own dtb section). kernel.banner gains "-perf-g<hash>"
#     exactly like the official build (LOCALVERSION_AUTO=y).
#   a15: Evolution X 10.x. The EvoX ap3a kernel branch was deleted, but its
#     content is preserved inside bka's history on the lineage-22.1
#     mainline: 80bbe21cceb928c95fcc7a7c7022f8070545c051 is the last state
#     carrying lineage_sm8150_defconfig (parent of the 2025-06-07
#     "configs: Convert OP7 to use config fragments"), i.e. the 4.14.356
#     era the official /15/ builds shipped (June 2025). Target Image-dtb
#     (UNCOMPRESSED_IMG header + Image + appended DTBs). The official
#     A15 build runs with LOCALVERSION_AUTO=n and
#     LOCALVERSION="-✨Caelum-OnePlus-7"; this script replicates both (the
#     official banner additionally carries a dirty-tree "+" suffix that a
#     clean checkout does not produce).
#
# BakaSU (ReSukiSU renamed) manual hooks are optional via ENABLE_BAKASU;
# patch selection depends on the mode because the A16-era trees carry the
# LineageOS __do_execve_file refactor while the A15-era tree does not.

workspace="${GITHUB_WORKSPACE:-$(pwd)}"
kernel="$workspace/kernel"
out="$kernel/out"
artifacts="$workspace/artifacts/guacamoleb"

android_mode="$(printf '%s' "${EVOX_ANDROID:-a16}" | tr '[:upper:]' '[:lower:]')"
enable_bakasu="${ENABLE_BAKASU:-false}"

case "$android_mode" in
  a15)
    default_repo='Evolution-X-Devices/kernel_oneplus_sm8150'
    default_ref='80bbe21cceb928c95fcc7a7c7022f8070545c051'
    base_defconfig='lineage_sm8150_defconfig'
    fragment_defconfig=''
    image_target='Image-dtb'
    hook_patch='patch/guacamoleb/bakasu-manual-hooks-4.14.patch'
    mode_label='Evolution X A15 (bka-history 80bbe21c, 4.14.356-openela-rc1, official /15/ kernel era)'
    required_platform=(BUILD_ARM64_APPENDED_DTB_IMAGE)
    forbidden_platform=( )
    localversion='-✨Caelum-OnePlus-7'
    ;;
  a16)
    default_repo='Evolution-X-Devices/kernel_oneplus_sm8150'
    default_ref='ce1fce98e3f97beb4a3379da3934d6136577e08a'
    base_defconfig='vendor/sm8150-perf_defconfig'
    fragment_defconfig='vendor/oplus.config'
    image_target='Image'
    hook_patch='patch/guacamoleb/bakasu-manual-hooks-4.14-evox-bka.patch'
    mode_label='Evolution X A16 (official 11.6.3 kernel state ce1fce98, 4.14.356-openela-rc1-perf)'
    required_platform=( )
    # The A16 ROM packs the DTB into the boot image dtb section; an appended
    # DTB would silently double it.
    forbidden_platform=(BUILD_ARM64_APPENDED_DTB_IMAGE)
    localversion=''
    ;;
  *)
    printf 'EVOX_ANDROID must be a15 or a16, got: %s\n' "$android_mode" >&2
    exit 2
    ;;
esac

source_repo="${KERNEL_REPOSITORY:-$default_repo}"
source_ref="${KERNEL_REF:-$default_ref}"

verify_source() {
  if [[ "$enable_bakasu" == true ]]; then
    git -C "$kernel" diff --binary HEAD \
      | cmp - "$artifacts/kernel-source.patch"
    git -C "$kernel" apply --reverse --check \
      "$workspace/$hook_patch"
    git -C "$kernel/KernelSU" diff --exit-code HEAD
    git -C "$kernel/KernelSU" diff --cached --exit-code
  else
    git -C "$kernel" diff --exit-code HEAD
  fi
  git -C "$kernel" diff --cached --exit-code
}

case "${1:-build}" in
  build) ;;
  --verify-source)
    verify_source
    exit 0
    ;;
  *)
    printf 'Usage: %s [--verify-source]\n' "$0" >&2
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
  # guacamoleb device trees pass these as TARGET_KERNEL_ADDITIONAL_FLAGS;
  # the LOS build appends them to every make invocation, so mirror that
  # exactly. Neither symbol is defined in the sm8150 4.14 Kconfigs, where
  # skip_initramfs is handled by __setup in init/initramfs.c, so these stay
  # inert make variables kept for build parity with the ROM.
  CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y
  CONFIG_PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT=y
  # The in-tree dtc (1.4.x) rejects the top-level `&label` overlay syntax in
  # -O dtbo files (Image-dtb also compiles the full dtbo set via the dtbs
  # prerequisite); the ROM build always overrides with an external modern
  # dtc through DTC_EXT (scripts/Makefile.lib: DTC = $(DTC_EXT)). The
  # workflow installs device-tree-compiler (dtc 1.6.1) for this. No-op for
  # targets that never invoke dtc (A16 "Image").
  DTC_EXT=/usr/bin/dtc
)

config_targets=("$base_defconfig")
if [[ -n "$fragment_defconfig" ]]; then
  # kbuild applies the base defconfig first, then the %.config rule merges
  # the fragment with scripts/kconfig/merge_config.sh -m and runs
  # olddefconfig -- identical to the ROM build.
  config_targets+=("$fragment_defconfig")
fi

mkdir -p "$out" "$artifacts"
verify_source

{
  printf 'OnePlus 7 (guacamoleb) SM8150 kernel build\n'
  printf 'Mode: %s\n' "$mode_label"
  printf 'Source: https://github.com/%s\n' "$source_repo"
  printf 'Source ref: %s\n' "$source_ref"
  printf 'Source commit: %s\n' "$(git -C "$kernel" rev-parse HEAD)"
  printf 'Defconfig: %s\n' "$base_defconfig"
  if [[ -n "$fragment_defconfig" ]]; then
    printf 'Defconfig fragment: %s (kbuild base+fragment merge)\n' "$fragment_defconfig"
  fi
  printf 'Boot image kernel: %s\n' "$image_target"
  if [[ -n "$localversion" ]]; then
    printf 'Localversion: %s (LOCALVERSION_AUTO disabled, mirrors official /15/ banner)\n' "$localversion"
  fi
  printf 'BakaSU enabled: %s\n' "$enable_bakasu"
  if [[ "$enable_bakasu" == true ]]; then
    printf 'BakaSU source: https://github.com/Baka-SU/BakaSU\n'
    printf 'BakaSU ref: %s\n' "$BAKASU_REF"
    printf 'BakaSU commit: %s\n' "$(git -C "$kernel/KernelSU" rev-parse HEAD)"
    printf 'Source patches: BakaSU driver registration and manual hooks\n'
    printf 'Hook patch: %s\n' "$hook_patch"
    printf 'BakaSU configuration: KSU=y KSU_MANUAL_HOOK=y; automatic input/setuid/init.rc hooks; KALLSYMS_ALL=y\n'
  else
    printf 'Source patches: none\n'
  fi
  printf 'Additional make flags: CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y CONFIG_PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT=y (device-tree parity)\n'
  printf 'Compiler: %s\n' "$(clang --version)"
  printf 'Linker: %s\n' "$(ld.lld --version)"
  printf 'Date: %s\n' "$(date -u +%FT%TZ)"
  printf 'Make arguments:'
  printf ' %q' "${make_args[@]}"
  printf '\n'
} > "$artifacts/build_info.txt"

# Generate the configuration exactly like the ROM build does.
make -C "$kernel" "${make_args[@]}" "${config_targets[@]}" \
  2>&1 | tee "$artifacts/configure.log"

need_olddefconfig=0
if [[ -n "$localversion" ]]; then
  # Mirror the official A15 build banner: fixed LOCALVERSION, no -g<hash>
  # (the official /15/ boot.img banner runs 4.14.356-openela-rc1-✨Caelum-
  # OnePlus-7 without a git suffix; its trailing "+" comes from the ROM
  # tree being dirty during the official build).
  "$kernel/scripts/config" --file "$out/.config" \
    --disable LOCALVERSION_AUTO \
    --set-str LOCALVERSION "$localversion"
  need_olddefconfig=1
fi

if [[ "$enable_bakasu" == true ]]; then
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
  need_olddefconfig=1
fi

if [[ "$need_olddefconfig" == 1 ]]; then
  make -C "$kernel" "${make_args[@]}" olddefconfig \
    2>&1 | tee -a "$artifacts/configure.log"
fi

cp "$out/.config" "$artifacts/kernel.config"

printf 'Required platform configuration after defconfig merge:\n' \
  | tee "$artifacts/platform-config.log"
for symbol in KALLSYMS KALLSYMS_ALL SECURITY_SELINUX \
  "${required_platform[@]}"; do
  grep -Fx "CONFIG_$symbol=y" "$out/.config" \
    | tee -a "$artifacts/platform-config.log" || {
      printf 'Required configuration is missing: CONFIG_%s=y\n' "$symbol" >&2
      exit 1
    }
done
for symbol in "${forbidden_platform[@]}"; do
  if grep -Eq "^CONFIG_$symbol=[ym]$" "$out/.config"; then
    printf 'Configuration must stay disabled: CONFIG_%s\n' "$symbol" >&2
    exit 1
  fi
done

if [[ "$enable_bakasu" == true ]]; then
  printf 'Required BakaSU configuration after olddefconfig:\n' \
    | tee "$artifacts/bakasu-config.log"
  for symbol in KSU KSU_MANUAL_HOOK KSU_MANUAL_HOOK_AUTO_SETUID_HOOK \
    KSU_MANUAL_HOOK_AUTO_INITRC_HOOK KSU_MANUAL_HOOK_AUTO_INPUT_HOOK \
    KALLSYMS KALLSYMS_ALL COMPAT SECURITY SECURITY_SELINUX INPUT; do
    grep -Fx "CONFIG_$symbol=y" "$out/.config" \
      | tee -a "$artifacts/bakasu-config.log" || {
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

make -C "$kernel" "${make_args[@]}" -j"$(nproc)" "$image_target" \
  2>&1 | tee "$artifacts/build.log"

if [[ "$enable_bakasu" == true ]]; then
  llvm-nm --defined-only "$out/vmlinux" \
    | grep -E '[[:space:]][Tt][[:space:]]+ksu_handle_(execveat|post_execveat|stat|newfstat_ret|fstat64_ret|faccessat|sys_reboot)$' \
    | tee "$artifacts/bakasu-symbols.log"
  for symbol in ksu_handle_execveat ksu_handle_post_execveat ksu_handle_stat \
    ksu_handle_newfstat_ret ksu_handle_fstat64_ret ksu_handle_faccessat \
    ksu_handle_sys_reboot; do
    grep -Eq "[[:space:]][Tt][[:space:]]+$symbol$" "$artifacts/bakasu-symbols.log" || {
      printf 'Linked BakaSU hook symbol is missing: %s\n' "$symbol" >&2
      exit 1
    }
  done
fi

cp "$out/arch/arm64/boot/$image_target" "$artifacts/$image_target"
cp "$out/include/config/kernel.release" "$artifacts/kernel.release"
kernel_release=$(< "$out/include/config/kernel.release")
printf 'Kernel release: %s\n' "$kernel_release" >> "$artifacts/build_info.txt"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'kernel_release=%s\n' "$kernel_release" >> "$GITHUB_OUTPUT"
  printf 'image_target=%s\n' "$image_target" >> "$GITHUB_OUTPUT"
fi

verify_source
ccache --show-stats
