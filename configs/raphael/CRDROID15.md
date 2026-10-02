# crDroid 15.0 Raphael build

- Source: `crdroidandroid/android_kernel_xiaomi_sm8150`, branch `15.0-raphael`.
- Initial source commit: `f39d5b1d8627a1fe11f3a9a89a7953e72d591365`.
- Source kernel version: Linux 4.14.355.
- Build-repository branch: `tmp/raphael-crdroid15-resukisu-ci`.
- Workflow source choice: `kernel_source=crdroid15`; an empty `kernel_ref`
  selects `15.0-raphael`.

## Extracted configuration and matching compiler

`evolutionx-15.0-20250609.config` is the complete, unmodified IKCONFIG extracted
from `/home/zihan/下载/EvolutionX-15.0-20250609-raphael-10.7-Official/boot.img`.
The image was unpacked with `unpack_bootimg`, and its gzip kernel was passed
to the kernel's `scripts/extract-ikconfig`.

- Boot image SHA256:
  `761653824b9566b385672f93dec4bdef26e86d5112b5d8c0419584cdbb3077f4`.
- Extracted configuration: 5,995 lines; SHA256
  `984db5668106e7e125ac6219a1a31eb88ddb27f01154e987c73148b4d7262c68`.
- Config header: `Linux/arm64 4.14.226 Kernel Configuration`.
- Actual boot kernel: `4.14.353-openela-SOVIET-STAR-//a5e8d7c521`.
- Boot header: version 0, 4,096-byte pages, Android 15 / 2025-06.
- Boot compiler: `Android (11967740, +pgo, +bolt, +lto, +mlgo, based on
  r522817) clang version 18.0.1, LLD 18.0.1`.

CI uses the matching AOSP `clang-r522817` prebuilt at commit
`921f6da692b1ffc96a0daa7e741373f0089d40b0`. It checks
`manifest_11967740.xml`, `AndroidVersion.txt`, the compiler build ID, and both
Clang/LLD versions. The compiler's optimization tags describe the compiler
binary. The extracted kernel configuration uses `LTO_NONE=y`.

The shared script copies this extracted config into `kernel/out/.config`,
applies ReSukiSU overrides to that copy, runs `olddefconfig`, checks effective
platform/hook options, and builds `Image.gz`. Artifacts retain the original
configuration as `boot.config` and normalized configuration as `kernel.config`.
The source defaults `POLLY_CLANG` to `y`, while the extracted boot config does
not enable Polly. The copy explicitly disables it for the matching AOSP
toolchain.

## Compatibility fixes for the extracted configuration

The first CI attempt passed the boot-toolchain, effective-config and manual
hook checks, then found two source issues when retaining the extracted
configuration's tracing and SchedTune options.
`patch/raphael/crdroid15-extracted-config.patch`:

- Removes stale ARM64 Makefile references to `perf_trace_counters.c` and
  `perf_trace_user.c`, neither of which exists in this source. Standard
  hardware perf events and tracing remain enabled.
- Supplies the missing `schedtune_prefer_high_cap` helper using the existing
  positive per-task boost policy, matching the CPU-selection code's intent.
  The extracted configuration's `SCHED_TUNE=y` remains enabled.

CI applies these fixes in both crDroid build modes and records them with the
integration diff. Verified AOSP compiler archives are cached before kernel
compilation so failed kernel attempts can reuse the same boot compiler.

## ReSukiSU adaptation

The crDroid source contains a bundled legacy KernelSU driver and old
exec/stat/access/read/input hooks. ReSukiSU is checked out separately at the
selected ref, defaulting to `3a2745f78ab68e61c02a0681463021952083ec8c`.
`patch/raphael/resukisu-crdroid15-hooks.patch` directs Kconfig/Kbuild to
`drivers/resukisu`, a symlink to the new checkout's kernel directory.

The patch replaces the old exec/stat/access hooks with the guide's manual
hooks, adds fstat/fstat64 return and reboot hooks, and removes the obsolete
vfs_read and direct input hooks. Automatic LSM init.rc/setuid hooks and the
input_handler hook are enabled. `KALLSYMS_ALL=y` supplies SELinux static
symbols. Tracepoint and SUSFS modes are disabled. The bundled driver remains
in the source tree and is not part of the ReSukiSU build.

CI saves the exact integration diff, checks the source against that snapshot,
checks the ReSukiSU checkout, and verifies all seven manual-hook providers in
the linked `vmlinux`. AnyKernel3 packages replace the gzip kernel while
retaining the installed ramdisk and DTB.
This source's commit-only localversion format contains `//`. Only ZIP file
names replace those slashes with hyphens; the kernel release is retained.

## Post-patch manual guide review

The patched source was checked against the user-specified
[manual integration guide](https://raw.githubusercontent.com/ReSukiSU/ReSukiSU.github.io/refs/heads/main/docs/zh-Hans/guide/manual-integrate.md).

| Guide item | Applied implementation |
| --- | --- |
| stat | newfstatat/fstatat64 before `vfs_fstatat`; newfstat/fstat64 after stat copy and before return |
| exec (3.14+) | pre/post execveat hooks in the common wrapper, passing addresses of fd, filename, argv, envp, flags and retval |
| compat execution | native and compat execve/execveat all use the same common wrapper |
| faccessat (4.19-) | syscall hook before mode validation, with a `NULL` flags argument |
| reboot (3.11+) | hook in `kernel/reboot.c` before `CAP_SYS_BOOT` validation |
| input | `KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=y`, without the legacy direct input hook |
| setuid and init.rc (<6.8) | both automatic LSM hook options enabled; obsolete vfs_read hook removed |
| static SELinux symbols | `KALLSYMS_ALL=y` enabled and checked after `olddefconfig` |

All newly added syscall hooks are guarded by `CONFIG_KSU_MANUAL_HOOK`.
CI checks the upstream manual-hook prerequisites during compilation and the
seven provider symbols after linking. Toolchain checks require the boot's
exact Clang/LLD version and compiler build ID.
