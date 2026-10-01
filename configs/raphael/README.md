# Raphael build configuration

`boot.config` is the complete, unmodified IKCONFIG extracted from
`/home/zihan/work/boot.img` (5,959 lines, 158,412 bytes).

## Boot image provenance

- Kernel version string: `4.14.350-englezos-a8c95a375c`.
- Configuration header: `Linux/arm64 4.14.170 Kernel Configuration`.
- Compiler: `Android (10087095, +pgo, +bolt, +lto, -mlgo, based on r487747c)
  clang version 17.0.2`.
- Linker: `LLD 17.0.2`.
- Boot header version: 2; page size: 4,096 bytes; kernel compression: gzip.
- Kernel LTO is disabled: `CONFIG_LTO_NONE=y`.
- `CONFIG_KALLSYMS_ALL=y` and `CONFIG_COMPAT=y` are enabled.

The workflow downloads the official AOSP `clang-r487747c` directory from
the `android14-release` prebuilts commit
`425c8149f17c8d9914bf690b4d5abe45a13fb993`. That directory includes
`manifest_10087095.xml` and Clang/LLD 17.0.2. The `+pgo`, `+bolt`, `+lto`
and `-mlgo` tags describe how the compiler was built; they are not kernel
configuration options.

## Source and build

The default source is `penglezos/kernel_xiaomi_raphael`, branch `lineage-20`
(Linux 4.14.190, commit `c0ad285ece84ce234bcf0a04b94707efc95ad78a` when this
workflow was added). The boot image's `a8c95a375c` commit is not available
in that repository. The workflow's `kernel_ref` input can select another
branch, tag or commit; the hook patch must match the selected source.

`scripts/build-raphael.sh` copies this configuration into `kernel/out/.config`
and runs `olddefconfig` against the selected source. It retains the no-LTO
configuration, uses explicit Clang/LLD and LLVM utility selections, and
provides GNU ARM64/ARM32 cross-binutils for this kernel's external assembler.
Host tools use `-fcommon` for compatibility with the legacy DTC sources.

ReSukiSU is optional and disabled by default. Enabling it installs the
selected ReSukiSU ref, applies `patch/raphael/resukisu-manual-hooks-4.14.patch`,
and enables manual hooks plus automatic input, setuid and init.rc hooks.
`KALLSYMS_ALL` provides the SELinux static symbols required by the guide.

Artifacts include `Image.gz`, the effective `kernel.config`, the original
`boot.config`, build logs, build metadata and an AnyKernel3 ZIP. The ZIP
targets `raphael`/`raphaelin` and preserves the installed ramdisk and DTB.

## Run the workflow

In GitHub Actions, select **Raphael Kernel Build (AOSP Clang 17 + Optional
ReSukiSU)** and use **Run workflow**. Keep `kernel_ref=lineage-20` for the
source used to prepare this patch. Enable `enable_resukisu` to include root
support; `resukisu_ref` defaults to `main`. `kernel_name` adds a version suffix,
and `upload_to_release` optionally publishes the successful build.
