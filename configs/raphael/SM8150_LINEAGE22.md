# SM8150 lineage-22.2 CI experiment

- Source: `xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150`.
- Branch: `lineage-22.2`, Linux 4.14.356-openela-rc1.
- Initial test source commit: `59220a048d04516e7fe1dfc094507930166a1e60`.
- Successful stock-source baseline: `tmp/sm8150-lineage22-stock-ci`,
  build-repository commit `26984d692401abd57f87404c3ead187c8fc9c460`,
  [CI run 36953672838](https://github.com/zhuzhuzihan/kernel_build/actions/runs/36953672838).
- BakaSU experiment branch: `tmp/sm8150-lineage22-resukisu-ci`
  (branch name predates the ReSukiSU → BakaSU rename).
- Compiler/linker: AOSP Clang/LLD 17.0.2, build 10087095.

The workflow runs `scripts/build-raphael-sm8150.sh`. It seeds
`kernel/out/.config` from the extracted IKCONFIG in
`configs/raphael/boot.config`, enables `MACH_XIAOMI_RAPHAEL` and `MFD_SPK_ID`,
runs `olddefconfig`, and builds `Image.gz`.
With `enable_bakasu=false`, git diff checks before and after compilation
verify that the tracked kernel source is pristine.

The original extracted configuration does not enable the new source's Xiaomi
platform symbols. Consequently, `apr_elliptic.c` references `elus_afe` while
`q6afe.c` excludes its definition behind `CONFIG_MACH_XIAOMI_SM8150`, causing
the initial stock-source test to fail during the final link.
`MACH_XIAOMI_RAPHAEL` selects `MACH_XIAOMI_SM8150`, which selects `MACH_XIAOMI`.
`MFD_SPK_ID` supplies `spk_id_get` for the Xiaomi audio codecs. CI checks all
these effective platform/provider symbols before compilation and records them
in `platform-config.log`.

## BakaSU manual integration

BakaSU is ReSukiSU after its rename to `Baka-SU/BakaSU`; the Kconfig
symbols, driver directory (`drivers/kernelsu`) and `KernelSU/` checkout
name are unchanged, only the upstream URLs and branding moved.

`enable_bakasu` defaults to `true` on the BakaSU experiment branch.
`bakasu_ref` defaults to the pinned upstream commit
`57b2db6076f439cfd489f14576444e8f0f2f0a25`. CI downloads the official setup
script from the selected ref, runs it with that ref, and verifies the resulting
BakaSU checkout before applying
`patch/raphael/bakasu-manual-hooks-4.14.patch`.

The patch follows the upstream
[manual integration guide](https://bakasu.org/guide/manual-integrate.html)
in its recommended form:

- `fs/exec.c`: declare the hook functions before `do_execveat_common`, call
  `ksu_handle_execveat` inside the function before the `IS_ERR(filename)`
  check, and call `ksu_handle_post_execveat` at `out_ret:` before
  `putname(filename)`. The older wrapper-rename variant
  (`__do_execveat_common`) is deprecated upstream and is no longer used.
  Native and compat execve/execveat share this function.
- `fs/stat.c`: hook newfstatat/fstatat64 and newfstat/fstat64 returns.
- `fs/open.c`: hook the 4.14 faccessat syscall.
- `kernel/reboot.c`: hook reboot before the capability check.

BakaSU verifies at build time (`kernel/tools/check_symbol`) that every hook
symbol referenced by the driver is defined in `vmlinux`, so a missing hook
patch fails the build instead of booting without root.

The effective configuration must enable `KSU`, `KSU_MANUAL_HOOK`,
`KSU_MANUAL_HOOK_AUTO_INPUT_HOOK`, `KSU_MANUAL_HOOK_AUTO_SETUID_HOOK`, and
`KSU_MANUAL_HOOK_AUTO_INITRC_HOOK`. The last three use the guide's automatic
input_handler/LSM integration for Linux 4.14. `KALLSYMS_ALL` supplies the
SELinux static symbols. Tracepoint and SUSFS hook modes are disabled.

CI records the driver-registration and hook changes in `kernel-source.patch`,
checks that compilation does not change that snapshot or the BakaSU source,
and verifies all seven manual-hook provider symbols in the final `vmlinux`.
The extracted `boot.config` is the configuration baseline for both modes;
all overrides are applied to its copy in `kernel/out/.config`.

Artifacts include the original extracted `boot.config`, effective
`kernel.config`, configuration/build/platform logs, build metadata, and, on
success, `Image.gz` and an AnyKernel3 ZIP for Raphael.
BakaSU builds also include setup/configuration logs, `kernel-source.patch`,
and `bakasu-symbols.log`; their AnyKernel3 ZIP name includes `BakaSU`.
