# SM8150 legacy stock-source CI experiment

- Source: `xiaomi-sm8150-devs/android_kernel_xiaomi_sm8150-legacy`.
- Branch: `lineage-20`, Linux 4.14.325.
- Initial test source commit: `812a4b14e34d1267693dbdd0abdf1ec659b6766d`.
- Build-repository branch: `tmp/sm8150-legacy-stock-ci`.
- Compiler/linker: AOSP Clang/LLD 17.0.2, build 10087095.

The experiment builds the repository's original source using the complete
extracted IKCONFIG in `configs/raphael/boot.config`. The workflow runs
`scripts/build-raphael-sm8150-legacy.sh`, which copies this configuration into
`kernel/out/.config`, runs `olddefconfig` against the new source, and builds
`Image.gz`. It records the effective configuration and source commit. Git diff
checks before and after compilation verify that the tracked kernel source is
pristine. This experiment applies no source patches or ReSukiSU hooks.

Artifacts include the original extracted `boot.config`, effective
`kernel.config`, configuration/build logs, build metadata, and, on success,
`Image.gz` and an AnyKernel3 ZIP for Raphael.
