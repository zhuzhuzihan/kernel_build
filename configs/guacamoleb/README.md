# OnePlus 7 (guacamoleb) Evolution X build configuration

OnePlus 7 is `guacamoleb` (do not confuse with the 7 Pro `guacamole`;
packages are not interchangeable). SM8150/msmnile caps at Linux 4.14, so
every bootable kernel for this device is a 4.14.x openela LTS tree.

The device is A/B (slot devices) with `boot`/`dtbo`/`vbmeta` OTA
partitions, so the AnyKernel3 zip uses `IS_SLOT_DEVICE=1` and flashes the
active slot's boot partition while retaining the installed ramdisk and DTB.

## Ground truth: the official boot.img banners

Both official Evolution X boot images (CDN `guacamoleb/{15,16}/boot/boot.img`,
96 MiB each, uncompressed kernel) carry their kernel banner and an embedded
IKCONFIG. Everything below was extracted from them:

| | **A15 line** (`a15`) | **A16 line** (`a16`, default) |
|---|---|---|
| Banner | `4.14.356-openela-rc1-✨Caelum-OnePlus-7` | `4.14.356-openela-rc1-perf-gce1fce98e3f9` |
| Build date | 2025-06-04 (the A15 line shipped builds into June 2025) | 2026-04-15 (= official 11.6.3 release day) |
| Compiler | `Android (12701618, +pgo, +bolt, +lto, +mlgo, based on r536225) clang 19.0.1, LLD 19.0.1` | `Android (14054515, +pgo, +bolt, +lto, +mlgo, based on r563880c) clang 21.0.0, LLD 21.0.0` |
| IKCONFIG facts | `BUILD_ARM64_APPENDED_DTB_IMAGE=y`, `LOCALVERSION_AUTO` off, `QCA_CLD_WLAN=y` | `LOCALVERSION="-perf"` + `LOCALVERSION_AUTO=y`, no appended DTB, `QCA_CLD_WLAN=m` |
| Git state | banner has no `-g` suffix (dirty-tree `+` only) | `-gce1fce98e3f9` names the exact kernel commit |

Consequences that matter:

- The A16 release kernel is **4.14.356-openela-rc1**, not the 4.14.357 that
  the current `bka` tip carries (`6ddfa33`, 2026-08-24) — the 4.14.357 bump
  happened after 11.6.3 shipped. `ce1fce98` is byte-faithful to the ROM.
- `-perf` in the A16 banner comes from `CONFIG_LOCALVERSION="-perf"` in
  `vendor/sm8150-perf_defconfig` plus `LOCALVERSION_AUTO=y`, so our A16
  build reproduces `-perf-g<hash>` automatically.
- The A15 official build ran with `LOCALVERSION_AUTO` off and a fixed
  `CONFIG_LOCALVERSION="-✨Caelum-OnePlus-7"`; the script replicates both in
  `a15` mode (our clean checkout omits the dirty-tree `+` the official
  banner shows).
- `QCA_CLD_WLAN` is built-in (`y`) on A15 and a module (`m`) on A16 — both
  fall out of the era-correct defconfigs, nothing to override.

## Two lines, two boot layouts

| | **A15 mode** (`a15`) | **A16 mode** (`a16`, default) |
|---|---|---|
| ROM series | Evolution X 10.x | Evolution X 11.x (11.6.3 = 2026-04-15) |
| Kernel source (default) | `Evolution-X-Devices/kernel_oneplus_sm8150` @ `80bbe21cceb928c95fcc7a7c7022f8070545c051` | `Evolution-X-Devices/kernel_oneplus_sm8150` @ `ce1fce98e3f97beb4a3379da3934d6136577e08a` |
| Kernel version | 4.14.356-openela-rc1 (matches the official /15/ era) | 4.14.356-openela-rc1 (the exact 11.6.3 kernel commit) |
| Defconfig | `lineage_sm8150_defconfig` (single file) | `vendor/sm8150-perf_defconfig` + `vendor/oplus.config` fragment |
| Kernel image | `Image-dtb` (`UNCOMPRESSED_IMG` header + Image + appended DTBs) | `Image` (DTB lives in the boot image's own dtb section) |
| Legacy refs | `f192c5f0` = 4.14.355 era (Feb 2025, first 10.3 builds); `bka` tip = 4.14.357 (newer than any shipped ROM) | `vic` = 4.14.356-openela-rc1 old A16 QPR2 line |

### Why these refs

- **A15**: the EvoX `ap3a` kernel branch was deleted, but its content is
  preserved in `bka`'s history on the lineage-22.1 mainline.
  `lineage_sm8150_defconfig` was added 2024-01-29 ("oneplus7: Add config
  for all OP7 variants") and removed 2025-06-07 ("configs: Convert OP7 to
  use config fragments" → the `vendor/perf` + fragment scheme). Its parent
  `80bbe21c` is the last 4.14.356-openela-rc1 state with the A15
  defconfig — the era the official /15/ builds shipped. Caution: the
  stable-LTS batch of 2025-02-07 (e.g. `7f3a3eee`) reached `bka` through
  the `qcom/lineage-20` side line whose trees contain only the CAF
  `defconfig`; check `arch/arm64/configs/lineage_sm8150_defconfig` exists
  before pinning any older commit.
- **A16**: `ce1fce98` (2026-02-17, "sm8150/defconfig: enable ramoops") is
  the commit named by the official 11.6.3 banner (`-gce1fce98e3f9`).
  Verified at that commit: Makefile 4.14.356-openela-rc1, `vendor/`
  defconfigs present, and the BakaSU hook patch applies as-is.

### Configuration generation

The script replicates the ROM build exactly:

- A15: `make lineage_sm8150_defconfig`, then (mirroring the official
  build) `LOCALVERSION_AUTO=n` + `CONFIG_LOCALVERSION="-✨Caelum-OnePlus-7"`
  via `scripts/config`, then `olddefconfig`.
- A16: `make vendor/sm8150-perf_defconfig vendor/oplus.config` — kbuild
  applies the base defconfig, then the `%.config` rule merges the fragment
  with `scripts/kconfig/merge_config.sh -m` and runs `olddefconfig`
  (verified in `scripts/kconfig/Makefile` of the bka tree).
- The guacamoleb device trees pass `TARGET_KERNEL_ADDITIONAL_FLAGS :=
  CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y
  CONFIG_PROC_CMDLINE_APPEND_ANDROID_FORCE_NORMAL_BOOT=y`; the LOS build
  system appends those to every make invocation, so the script does too.
  Neither symbol exists in the sm8150 4.14 Kconfigs (skip_initramfs is
  handled by `__setup` in `init/initramfs.c`), so they are inert make
  variables kept purely for build parity with the ROM.
- Required checks after configuration: `KALLSYMS`, `KALLSYMS_ALL`,
  `SECURITY_SELINUX=y`; A15 additionally requires
  `BUILD_ARM64_APPENDED_DTB_IMAGE=y` (without it the `Image-dtb` target
  does not exist) and A16 requires it to stay unset (an appended DTB would
  duplicate the DTB the ROM packs separately). Both constraints match the
  IKCONFIG of the official boot images.

## Compiler: per-line official toolchains

Each mode downloads the exact AOSP prebuilt the official ROM build used
(verified by the banner's `Android (build, ...)` tag and the `manifest_<build>.xml`
inside the prebuilt):

| mode | clang dir | pinned prebuilts commit | manifest build |
|---|---|---|---|
| a15 | `clang-r536225` (19.0.1) | `96266255abde` (`android15-qpr2-release`) | `12701618` ✓ official |
| a16 | `clang-r563880c` (21.0.0) | `9916fb51ccb9` (`android16-qpr2-release`) | `14054515` ✓ official |

The workflow fetches `platform/prebuilts/clang/host/linux-x86/+archive/<commit>/<dir>.tar.gz`.
LLD matches (19.0.1 / 21.0.0). GNU cross-binutils are still provided for
this kernel's external assembler, and `-fcommon` host flags cover the
legacy in-tree DTC sources; `KBUILD_BUILD_USER/HOST` are set to
`build-user`/`build-host` so the banner matches the official format.

## BakaSU integration

BakaSU is ReSukiSU after its rename: the organization moved to
`Baka-SU/BakaSU` (old URLs redirect), docs live at
[bakasu.org](https://bakasu.org/guide/build.html). The Kconfig symbols
(`CONFIG_KSU`, `KSU_MANUAL_HOOK`, the three automatic-hook options), the
`drivers/kernelsu` symlink and the `KernelSU/` checkout name are unchanged,
so configuration handling is identical to the ReSukiSU era.

### Manual hooks follow the new recommended method

The upstream [manual integration
guide](https://bakasu.org/guide/manual-integrate.html) changed the execve
hook: the recommended form calls `ksu_handle_execveat` inside
`do_execveat_common` before the `IS_ERR(filename)` check and
`ksu_handle_post_execveat` at `out_ret:` before `putname(filename)`. The
wrapper-rename variant (`__do_execveat_common`) used by the old ReSukiSU
patch is deprecated upstream. BakaSU also gained a build-time hook check
(`kernel/tools/check_symbol`): every hook symbol referenced by the driver
must be defined in `vmlinux`, so a missing hook patch fails the build
instead of silently booting without root.

Because `CONFIG_KALLSYMS_ALL=y` is enforced, the guide's optional SELinux
static-export edits (write_op, sel_handle_status_ops, latest_granting, ...)
are not needed.

### Two patch variants

`ksu_handle_execveat` only guards `IS_ERR(filename)`, not `NULL` — and the
A16-era trees carry the LineageOS `__do_execve_file` refactor whose
`do_execve_file()` helper passes `filename = NULL` (the refactor even
special-cases `bprm->filename = "none"`). Hooking `__do_execve_file`
directly would dereference NULL, so:

- `patch/guacamoleb/bakasu-manual-hooks-4.14.patch` — standard 4.14 exec.c
  (applies to the A15 ref `80bbe21c` byte-for-byte; the four hook target
  files there are identical to the LOS lineage-22.1 / xiaomi lineage-22.2
  trees). Hooks go inside the real `do_execveat_common`.
- `patch/guacamoleb/bakasu-manual-hooks-4.14-evox-bka.patch` — refactor-era
  exec.c (bka tip, verified to also apply to `ce1fce98`). `do_execveat_common`
  is a thin wrapper over `__do_execve_file(..., NULL)`; the hooks wrap that
  call. `filename` is never NULL on this path (all callers pass a `getname`
  result), and `do_execve_file` direct callers keep working untouched.

The stat (`newfstatat`, `fstatat64`, `newfstat`, `fstat64`), faccessat and
reboot hook regions are identical across all of these trees, so both
variants share those hunks.

`bakasu_ref` defaults to the pinned commit
`57b2db6076f439cfd489f14576444e8f0f2f0a25` (BakaSU `main` at the time this
workflow was prepared, 2026-11-23).

## Artifacts and flashing

Artifacts include the kernel image (`Image-dtb` or `Image`), the effective
`kernel.config`, build logs, build metadata and an AnyKernel3 ZIP named
`OnePlus7-EvoX-<A15|A16>-<release>[-BakaSU]-<date>-<run>`. The zip targets
`guacamoleb`/`OnePlus7` and flashes the active slot's boot partition,
retaining the installed ramdisk and DTB.

- Flash the zip that matches the installed ROM line: an A15 kernel
  (Image-dtb, appended DTB) and an A16 kernel (Image + separate DTB) are
  not interchangeable, and A15↔A16 ROM switches are full-ROM flashes.
- Kernel modules (`wlan.ko` → `qca_cld3_wlan`, audio `*_dlkm.ko`) build
  with the ROM and stay installed; the zip replaces only the kernel image.
  A15 official builds carry `QCA_CLD_WLAN=y` (built-in), A16 `=m` — do not
  mix module expectations across lines.
- BakaSU manager compatibility: install the BakaSU manager APK
  (arm64-v8a) from [bakasu.org](https://bakasu.org).

## Run the workflow

In GitHub Actions, select **OnePlus 7 (guacamoleb) EvoX SM8150 Build
(Official Clang per line + BakaSU)** and use **Run workflow**. Pick
`android_version` (`a16` default), optionally override
`kernel_repository`/`kernel_ref`, toggle `enable_bakasu`, and set
`upload_to_release` to publish the build.
