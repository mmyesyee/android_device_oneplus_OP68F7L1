#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from the OP68F7L1 device tree
$(call inherit-product, device/oneplus/OP68F7L1/device.mk)

# Inherit some common Lineage stuff
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_OP68F7L1
PRODUCT_DEVICE := OP68F7L1
PRODUCT_BRAND := OnePlus
PRODUCT_MODEL := PYS110
PRODUCT_MANUFACTURER := OnePlus

PRODUCT_GMS_CLIENTID_BASE := android-oneplus

# Values read from the running ColorOS 16 (Android 16) build.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="sys_mssi_64_cn_armv82-user 16 BP2A.250605.015 1784212740609 release-keys" \
    BuildFingerprint=OnePlus/PYS110/OP68F7L1:16/UKQ1.231108.001/B.2c01668-732243-78c24b:user/release-keys \
    DeviceName=OP68F7L1 \
    DeviceProduct=PYS110 \
    SystemDevice=OP68F7L1 \
    SystemName=PYS110
