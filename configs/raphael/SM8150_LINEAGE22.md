# SM8150 lineage-22.2 stock-source CI experiment

- Source: `xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150`.
- Branch: `lineage-22.2`, Linux 4.14.356-openela-rc1.
- Initial test source commit: `59220a048d04516e7fe1dfc094507930166a1e60`.
- Build-repository branch: `tmp/sm8150-lineage22-stock-ci`.
- Compiler/linker: AOSP Clang/LLD 17.0.2, build 10087095.

The workflow runs `scripts/build-raphael-sm8150-stock.sh` against the original
kernel source. It seeds `kernel/out/.config` from the extracted IKCONFIG in
`configs/raphael/boot.config`, enables `MACH_XIAOMI_RAPHAEL` and `MFD_SPK_ID`,
runs `olddefconfig`, and builds `Image.gz`.
Git diff checks before and after compilation verify that the tracked kernel
source is pristine. This experiment applies no source patches or ReSukiSU
hooks.

The original extracted configuration does not enable the new source's Xiaomi
platform symbols. Consequently, `apr_elliptic.c` references `elus_afe` while
`q6afe.c` excludes its definition behind `CONFIG_MACH_XIAOMI_SM8150`, causing
the initial stock-source test to fail during the final link.
`MACH_XIAOMI_RAPHAEL` selects `MACH_XIAOMI_SM8150`, which selects `MACH_XIAOMI`.
`MFD_SPK_ID` supplies `spk_id_get` for the Xiaomi audio codecs. CI checks all
these effective platform/provider symbols before compilation and records them
in `platform-config.log`.

Artifacts include the original extracted `boot.config`, effective
`kernel.config`, configuration/build/platform logs, build metadata, and, on
success, `Image.gz` and an AnyKernel3 ZIP for Raphael.
