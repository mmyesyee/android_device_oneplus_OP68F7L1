#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/oneplus/OP68F7L1

# Inherit the MT6878 platform configuration. Everything that is not specific to
# this phone (kernel offsets, super layout, sepolicy, AVB, wifi, properties)
# lives there.
include device/oneplus/mt6878-common/BoardConfigCommon.mk

# Assert
TARGET_OTA_ASSERT_DEVICE := OP68F7L1,PYS110

# Display
TARGET_SCREEN_DENSITY := 480

# Fingerprint: side-mounted sensor integrated in the power button, not an
# under-display one. The stock OPLUS HAL in /odm implements
# android.hardware.biometrics.fingerprint (AIDL V3), so the framework needs no
# FOD/UDFPS configuration — TARGET_USES_FOD_ZPOS stays unset on purpose.

# Fastboot
TARGET_BOARD_FASTBOOT_INFO_FILE := $(DEVICE_PATH)/fastboot-info.txt

# Kernel (prebuilt, kept in its own repository next to this device tree)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)-kernel/Image

# Inherit the proprietary files
-include vendor/oneplus/OP68F7L1/BoardConfigVendor.mk
