#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/oneplus/mt6878-common',
    'device/oneplus/OP68F7L1',
    'hardware/mediatek',
]

lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
}

blob_fixups: blob_fixups_user_type = {
    'vendor/etc/init/android.hardware.neuralnetworks-shim-service-mtk.rc': blob_fixup()
        .regex_replace('start', 'enable'),

    'vendor/bin/hw/android.hardware.media.c2@1.2-mediatek-64b': blob_fixup()
        .add_needed('libstagefright_foundation-v33.so')
        .replace_needed('libavservices_minijail_vendor.so', 'libavservices_minijail.so'),

    'vendor/lib64/hw/audio.primary.mediatek.so': blob_fixup()
        .add_needed('libstagefright_foundation-v33.so')
        .replace_needed('libutils.so', 'libutils-v32.so')
        .replace_needed('libalsautils.so', 'libalsautils-v31.so'),

    'vendor/lib64/hw/hwcomposer.mtk_common.so': blob_fixup()
        .add_needed('libprocessgroup_shim.so'),

    ('vendor/lib64/mt6878/libneuralnetworks_sl_driver_mtk_prebuilt.so',
     'vendor/lib64/libnvram.so',
     'vendor/lib64/libsysenv.so',
     'vendor/lib64/libtflite_mtk.so'): blob_fixup()
        .add_needed('libbase_shim.so'),

    ('vendor/lib64/hw/mt6878/android.hardware.camera.provider@2.6-impl-mediatek.so',
     'vendor/lib64/mt6878/libmtkcam_stdutils.so'): blob_fixup()
        .replace_needed('libutils.so', 'libutils-v32.so')
        .add_needed('libbase_shim.so'),

    'vendor/etc/vintf/manifest/manifest_media_c2_V1_2_default.xml': blob_fixup()
        .regex_replace('1.1', '1.2')
        .regex_replace('@1.0', '@1.2'),

    ('vendor/lib64/mt6878/lib3a.ae.stat.so',
     'vendor/lib64/mt6878/lib3a.sensors.flicker.so',
     'vendor/lib64/mt6878/lib3a.sensors.color.so'): blob_fixup()
        .add_needed('liblog.so'),

    'vendor/lib64/mt6878/libmnl.so': blob_fixup()
        .add_needed('libcutils.so'),

    'vendor/lib64/mt6878/libmtkcam_hal_aidl_common.so': blob_fixup()
        .replace_needed('android.hardware.camera.common-V2-ndk.so',
                        'android.hardware.camera.common-V1-ndk.so'),

    'vendor/lib64/vendor.mediatek.hardware.bluetooth.audio-V1-ndk.so': blob_fixup()
        .replace_needed('android.hardware.audio.common-V1-ndk.so',
                        'android.hardware.audio.common-V2-ndk.so'),

    'vendor/lib64/mt6878/libneuralnetworks_sl_driver_mtk_prebuilt.so': blob_fixup()
        .clear_symbol_version('AHardwareBuffer_allocate')
        .clear_symbol_version('AHardwareBuffer_createFromHandle')
        .clear_symbol_version('AHardwareBuffer_describe')
        .clear_symbol_version('AHardwareBuffer_getNativeHandle')
        .clear_symbol_version('AHardwareBuffer_lock')
        .clear_symbol_version('AHardwareBuffer_lockPlanes')
        .clear_symbol_version('AHardwareBuffer_release')
        .clear_symbol_version('AHardwareBuffer_unlock'),

    'vendor/lib64/hw/mt6878/vendor.mediatek.hardware.pq_aidl-impl.so': blob_fixup()
        .add_needed('libui_shim.so'),

    # Every stock blob here links android.hardware.graphics.common v4. The
    # platform builds the same interface at v7 (hardware/interfaces/graphics/
    # common/aidl freezes only up to v6, and with frozen: false Soong numbers
    # the unfrozen current version max+1 = 7). libui and libgralloctypes link
    # the unversioned android.hardware.graphics.common-ndk_shared, i.e. that
    # v7, so a blob still on v4 makes any module that links both sides depend
    # on two versions of one aidl_interface, which Soong rejects outright.
    # v4, v6 and v7 are all revisions of one frozen-or-later interface, so the
    # ndk libraries are additive and rewriting DT_NEEDED straight to v7 is
    # safe. This list is every graphics.common linker in the stock vendor tree.
    ('vendor/bin/hw/mt6878/android.hardware.graphics.allocator-V2-service-mediatek.mt6878',
     'vendor/lib64/egl/mt6878/libGLES_mali.so',
     'vendor/lib64/hw/mt6878/android.hardware.graphics.allocator-V2-mediatek.so',
     'vendor/lib64/hw/mt6878/android.hardware.graphics.mapper@4.0-impl-mediatek.so',
     'vendor/lib64/hw/mt6878/mapper.mediatek.so',
     'vendor/lib64/mt6878/libmtkcam_grallocutils.so',
     'vendor/lib64/libcodec2_fsr.so',
     'vendor/lib64/libcodec2_vpp_AIMEMC_plugin.so',
     'vendor/lib64/libcodec2_vpp_AISR_plugin.so',
     'vendor/lib64/libmtkcam_grallocutils_aidlv1helper.so',
     'vendor/lib64/vendor.mediatek.hardware.camera.isphal-V1-ndk.so',
     'vendor/lib64/vendor.mediatek.hardware.pq_aidl-V2-ndk.so',
     'vendor/lib64/vendor.mediatek.hardware.pq_aidl-V4-ndk.so',
     'vendor/lib64/vendor.mediatek.hardware.pq_aidl-V7-ndk.so'): blob_fixup()
        .replace_needed('android.hardware.graphics.common-V4-ndk.so',
                        'android.hardware.graphics.common-V7-ndk.so'),
}  # fmt: skip

module = ExtractUtilsModule(
    'OP68F7L1',
    'oneplus',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    # 本机没有可提取的 firmware 分区清单；modem 等固件在 /vendor/firmware，
    # 已经写在 proprietary-files.txt 里，所以这里不启用 proprietary-firmware.txt。
    add_firmware_proprietary_file=False,
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()
