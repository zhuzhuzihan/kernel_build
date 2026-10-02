# SM8150 lineage-22.2 CI experiment

- Source: `xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150`.
- Branch: `lineage-22.2`, Linux 4.14.356-openela-rc1.
- Initial test source commit: `59220a048d04516e7fe1dfc094507930166a1e60`.
- Successful stock-source baseline: `tmp/sm8150-lineage22-stock-ci`,
  build-repository commit `26984d692401abd57f87404c3ead187c8fc9c460`,
  [CI run 36953672838](https://github.com/zhuzhuzihan/kernel_build/actions/runs/36953672838).
- ReSukiSU experiment branch: `tmp/sm8150-lineage22-resukisu-ci`.
- Compiler/linker: AOSP Clang/LLD 17.0.2, build 10087095.

The workflow runs `scripts/build-raphael-sm8150.sh`. It seeds
`kernel/out/.config` from the extracted IKCONFIG in
`configs/raphael/boot.config`, enables `MACH_XIAOMI_RAPHAEL` and `MFD_SPK_ID`,
runs `olddefconfig`, and builds `Image.gz`.
With `enable_resukisu=false`, git diff checks before and after compilation
verify that the tracked kernel source is pristine.

The original extracted configuration does not enable the new source's Xiaomi
platform symbols. Consequently, `apr_elliptic.c` references `elus_afe` while
`q6afe.c` excludes its definition behind `CONFIG_MACH_XIAOMI_SM8150`, causing
the initial stock-source test to fail during the final link.
`MACH_XIAOMI_RAPHAEL` selects `MACH_XIAOMI_SM8150`, which selects `MACH_XIAOMI`.
`MFD_SPK_ID` supplies `spk_id_get` for the Xiaomi audio codecs. CI checks all
these effective platform/provider symbols before compilation and records them
in `platform-config.log`.

## ReSukiSU manual integration

`enable_resukisu` defaults to `true` on the ReSukiSU experiment branch.
`resukisu_ref` defaults to the pinned upstream commit
`3a2745f78ab68e61c02a0681463021952083ec8c`. CI downloads the official setup
script from the selected ref, runs it with that ref, and verifies the resulting
ReSukiSU checkout before applying
`patch/raphael/resukisu-manual-hooks-4.14.patch`.

The patch follows the upstream
[manual integration guide](https://raw.githubusercontent.com/ReSukiSU/ReSukiSU.github.io/refs/heads/main/docs/zh-Hans/guide/manual-integrate.md):

- `fs/exec.c`: wrap `do_execveat_common` with pre/post hooks. This source has
  no `__do_execve_file` helper, so the original implementation is renamed
  `__do_execveat_common`. Native and compat execve/execveat share this wrapper.
- `fs/stat.c`: hook newfstatat/fstatat64 and newfstat/fstat64 returns.
- `fs/open.c`: hook the 4.14 faccessat syscall.
- `kernel/reboot.c`: hook reboot before the capability check.

The effective configuration must enable `KSU`, `KSU_MANUAL_HOOK`,
`KSU_MANUAL_HOOK_AUTO_INPUT_HOOK`, `KSU_MANUAL_HOOK_AUTO_SETUID_HOOK`, and
`KSU_MANUAL_HOOK_AUTO_INITRC_HOOK`. The last three use the guide's automatic
input_handler/LSM integration for Linux 4.14. `KALLSYMS_ALL` supplies the
SELinux static symbols. Tracepoint and SUSFS hook modes are disabled.

CI records the driver-registration and hook changes in `kernel-source.patch`,
checks that compilation does not change that snapshot or the ReSukiSU source,
and verifies all seven manual-hook provider symbols in the final `vmlinux`.
The extracted `boot.config` is the configuration baseline for both modes;
all overrides are applied to its copy in `kernel/out/.config`.

Artifacts include the original extracted `boot.config`, effective
`kernel.config`, configuration/build/platform logs, build metadata, and, on
success, `Image.gz` and an AnyKernel3 ZIP for Raphael.
ReSukiSU builds also include setup/configuration logs, `kernel-source.patch`,
and `resukisu-symbols.log`; their AnyKernel3 ZIP name includes `ReSukiSU`.
