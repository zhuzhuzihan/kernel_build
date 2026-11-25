#!/sbin/sh
# AnyKernel3 configuration for OnePlus 7 (guacamoleb, A/B slot device).
properties() { '
kernel.string=@KERNEL_STRING@
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=guacamoleb
device.name2=OnePlus7
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

# Replace the kernel while retaining the installed ramdisk and DTB.
# - EvoX A15 builds ship Image-dtb (UNCOMPRESSED_IMG header + Image +
#   appended DTBs): the DTB travels inside the replaced kernel image.
# - EvoX A16 builds ship a plain Image: no dtb file in the zip, so the
#   boot image's own dtb section stays untouched.
split_boot;
flash_boot;
