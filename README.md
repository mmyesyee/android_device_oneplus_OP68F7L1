# LineageOS 设备树 —— OnePlus PYS110 (OP68F7L1)

OnePlus PYS110（海外/国内型号名同）的 LineageOS 24.0（Android 17 / SDK 37）设备树。
平台为 MediaTek MT6878（Dimensity 7300），8 核（4×Cortex-A78 + 4×Cortex-A55），
arm64，A/B + Virtual A/B，recovery 位于 vendor_boot ramdisk。

> 目标分支是 **lineage-24.0（Android 17 / SDK 37，CINNAMON_BUN）**，而这台机器的
> 出厂基座是 ColorOS 16（Android 16 / SDK 36，`ro.vendor.api_level=34`）。也就是
> “新 framework + 旧 vendor blob”的组合，风险与对策见文末「首次开机排查清单」。

## 基本参数（全部读自真机）

| 项目 | 值 |
| --- | --- |
| 设备代号 | `OP68F7L1` |
| 型号 / 市场名 | `PYS110` |
| SoC | MT6878 (`TARGET_BOARD_PLATFORM := mt6878`) |
| 出厂系统 | ColorOS 16 / Android 16（SDK 36），安全补丁 2026-07-01 |
| 架构 | arm64 + arm（应用仅 64 位，系统内仍带 32 位运行库） |
| 屏幕密度 | 480 dpi |
| 指纹 | OPLUS 屏下指纹（UDFPS，`/odm` 下的 `vendor.oplus.hardware.biometrics.fingerprint`） |

分区大小：`boot` 64 MiB、`init_boot` 8 MiB、`vendor_boot` 64 MiB、`dtbo` 8 MiB、
`super` 16911433728 B、`vbmeta` 8 MiB、`vbmeta_system` 8 MiB、`userdata` 235191369728 B、
`metadata` 76513280 B。

super 只有一个逻辑分组 **`main`**（`main_a` / `main_b`，各 16907239424 B），
组内逻辑分区：`system system_ext vendor product odm vendor_dlkm odm_dlkm system_dlkm`
以及 OPLUS 的十个 `my_*`（`my_bigball my_carrier my_company my_engineering my_heytap
my_manifest my_preload my_product my_region my_stock`）。

## 仓库结构

按 Ace6-Development 的做法拆成 4 个仓库，各自独立 `git init`、可单独推到 GitHub：

| 本地路径 | 建议的仓库名 | 内容 |
| --- | --- | --- |
| `device/oneplus/OP68F7L1` | `android_device_oneplus_OP68F7L1` | 机型树：`BoardConfig.mk`、`device.mk`、产品定义、`extract-files.py`、`proprietary-files.txt`、`fastboot-info.txt`、DSU 脚本 |
| `device/oneplus/mt6878-common` | `android_device_oneplus_mt6878-common` | 平台树：`BoardConfigCommon.mk`、`common.mk`、`init/`、`configs/props`、`configs/vintf`、`sepolicy/` |
| `device/oneplus/OP68F7L1-kernel` | `android_device_oneplus_OP68F7L1-kernel` | stock 内核 `Image`（34 MiB，不编译） |
| `vendor/oneplus/OP68F7L1` | `proprietary_vendor_oneplus_OP68F7L1` | blob 仓库：`proprietary/`（5.9 GiB）+ 生成的 `Android.bp` / `Android.mk` / `*-vendor.mk` |

依赖方向只有单向一条：机型树 `include device/oneplus/mt6878-common/BoardConfigCommon.mk`
并 `inherit-product .../common.mk`，平台树反过来不引用机型树；`lineage.dependencies`
里列了平台树。

## 重要设计决定

1. **不编译内核、不生成 vendor_boot、不生成 dtbo。**
   内核使用 stock `boot` 里那份未压缩的 `Image`（`device/oneplus/OP68F7L1-kernel/Image`，
   35,772,928 B，`TARGET_PREBUILT_KERNEL` + `TARGET_FORCE_PREBUILT_KERNEL`）。
   `vendor_boot`（内含厂商 ramdisk、DTB、235 个内核模块）与 `dtbo` 保留 ColorOS 原样。
   **`boot` 与 `init_boot` 也一律保持 stock**：真机的 `init_boot` 里注入了 KernelSU，
   刷掉就等于丢 root，而且本树的设计是“stock 引导 + 新 system”，原本就不需要换引导。
   因此 `fastboot-info.txt` 里没有 `boot` / `init_boot` / `vendor_boot` / `dtbo`，
   主测试路径是 DSU（见“用 DSU 测试”一节）。
   `BoardConfig.mk` 里刻意**没有**设置
   `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE` / `BOARD_DTBOIMG_PARTITION_SIZE` /
   `BOARD_INCLUDE_DTB_IN_BOOTIMG` / `BOARD_PREBUILT_DTBIMAGE_DIR` /
   `BOARD_*_KERNEL_MODULES`，构建产物里不会出现 `vendor_boot.img` 与 `dtbo.img`。
   `TARGET_NO_KERNEL_OVERRIDE := true` 与 `TARGET_FORCE_PREBUILT_KERNEL := true` 保证
   Soong 不去找 `kernel/oneplus/OP68F7L1` 源码树。

2. **全量复用 stock `/vendor` 与 `/odm`。**
   OPLUS/MTK 的 HAL（相机、指纹、显示、充电、NFC、音频、传感器、modem、trustonic
   keymint 等）全部是闭源 blob，`proprietary-files.txt` 把 `/vendor`、`/odm`、`/system_ext`
   三个分区的内容整体搬进 `vendor/oneplus/OP68F7L1`，因此 `device.mk` **不**
   inherit 任何 `hardware/mediatek` 的 vendor HAL 包，也不 inherit
   `vendor/mediatek/ims`。framework 侧只构建 AOSP/Lineage 自身的部分。

3. **`/product` 不做 blob。**
   stock fstab 里有 `overlay-overlay` 行，运行时把 `my_region`、`my_preload`、
   `my_product`、`my_heytap`、`my_stock`、`my_engineering` 的内容覆盖合并到
   `/product/{app,priv-app,lib,lib64,etc/permissions,framework,media/audio/ui}`。
   也就是说 `/product` 的“内容”实际分散在 `my_*` 分区里，重建 `/product` 只会
   丢掉这些覆盖层，所以这些分区整块保持 ColorOS 原样。

4. **只重建 super group `main` 里的五个分区**（`system system_ext vendor product odm`）。
   `vendor_dlkm`、`odm_dlkm`、`system_dlkm`、`my_*` 不在
   `BOARD_MAIN_DYNAMIC_PARTITIONS_PARTITION_LIST` 里，OTA 时 `update-super` 不会
   重新划分它们的大小，内容得以保留。

5. **`/vendor` 里的 init 脚本与 fstab 由设备树接管。**
   `init/fstab.mt6878`、`init/init.mt6878.rc` 等 13 个文件和 `ueventd.rc` 从真机取出后
   放进本树，由 `init/Android.bp` 以 `prebuilt_etc` 安装，同时在
   `proprietary-files.txt` 里排除，避免一个文件两个来源。

6. **`PRODUCT_SHIPPING_API_LEVEL := 34`。**
   真机出厂时 `ro.product.first_api_level=36`，但 vendor blob 的
   `ro.vendor.api_level` / `ro.vndk.version` 都是 34。shipping level 决定 framework
   对设备施加多少“新设备强制要求”（mainline APEX、HAL 最低版本等），取 34 可以
   让 Android 17 的 framework 不去要求这套 Android 16 vendor 并不具备的东西。
   若以后提到 36，构建期会开始要求额外的 mainline 模块与更新的 HAL。

## 目录结构

```
device/oneplus/OP68F7L1/                # 机型仓库
├── Android.bp                 # soong_namespace
├── Android.mk                 # 仅在 TARGET_DEVICE == OP68F7L1 时递归子目录
├── AndroidProducts.mk         # lineage_OP68F7L1-{user,userdebug,eng}
├── BoardConfig.mk             # 只写机型差异 + include 平台树
├── device.mk                  # AAPT/屏幕 + inherit 平台树 + vendor 仓库
├── lineage_OP68F7L1.mk
├── lineage.dependencies       # 平台树等依赖列表
├── extract-files.py           # 从 stock 分区提取 blob（含 DT_NEEDED / VINTF 修补）
├── setup-makefiles.py         # = extract-files.py --regenerate_makefiles
├── proprietary-files.txt
├── fastboot-info.txt
├── tools/dsu.sh               # DSU 测试助手（装镜像进 /data，不碰 boot/init_boot）
└── local_manifests/OP68F7L1.xml

device/oneplus/mt6878-common/           # 平台仓库
├── BoardConfigCommon.mk       # 架构/分区/内核参数/super/AVB/WiFi/sepolicy
├── common.mk                  # virtual A/B、update_engine、init 脚本、props
├── configs/
│   ├── props/                 # vendor/odm/system/product 的属性（TARGET_*_PROP）
│   └── vintf/                 # stock /vendor 的 manifest.xml + compatibility_matrix.xml
├── init/                      # fstab.mt6878、MTK 各 init.*.rc、ueventd.mt6878.rc
└── sepolicy/{basic/non_plat,vendor,private,public}
```

另外两个仓库：`device/oneplus/OP68F7L1-kernel/Image`（预编译内核）与
`vendor/oneplus/OP68F7L1/`（blob，见“vendor 目录”一节）。

```
vendor/oneplus/OP68F7L1/
├── Android.mk                 # 生成文件
├── Android.bp                 # 3,056 个 Soong 模块
├── BoardConfigVendor.mk       # 生成文件，故意为空
├── OP68F7L1-vendor.mk         # 由 extract-files.py -m 生成的真规则
└── proprietary/               # 提取出的 blob
```

## 构建

```bash
# 网络受限时先 export 代理（抓 GitHub 必需；raw.githubusercontent.com 裸连不通）
export all_proxy=http://127.0.0.1:7890
export http_proxy=$all_proxy https_proxy=$all_proxy

repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs
repo sync -c -j"$(nproc)"

# 把四个仓库的目录放到位（见“仓库结构”一节）
#   device/oneplus/OP68F7L1
#   device/oneplus/mt6878-common
#   device/oneplus/OP68F7L1-kernel
#   vendor/oneplus/OP68F7L1        （blob 已提取，见“vendor 目录”一节）
# 并从 local_manifests/OP68F7L1.xml 添加 hardware/mediatek、
# device/mediatek/sepolicy_vndr、tools/extract-utils 三个仓库
# （repo 会自动读取该文件；extract-utils 不在 LOS 默认 manifest 里）。

source build/envsetup.sh
lunch lineage_OP68F7L1-userdebug
mka bacon            # 或 mka systemimage vendorimage productimage odmimage bootimage
```

产物：`system.img`、`system_ext.img`、`vendor.img`、`product.img`、`odm.img`、
`vbmeta.img`、`vbmeta_system.img`，以及 DSU 测试要用的那几个。
`boot.img` / `init_boot.img` 虽然也会被构建出来（stock 内核 + generic ramdisk），
但它们**不参与**本树的测试与刷机流程，真机上保持 stock。
**没有** `vendor_boot.img` 与 `dtbo.img`（见上）。

### vendor 目录（blob 已就位）

`vendor/oneplus/OP68F7L1/` 现在的状态：`proprietary/` 下是**已从真机取出的 stock
blob**（`vendor` 2.0 GiB + `odm` 4.0 GiB，共 7,575 个条目、5.9 GiB），并且
`Android.bp`（3,056 个模块）、`Android.mk`、`BoardConfigVendor.mk`、
`OP68F7L1-vendor.mk`（4,715 条拷贝规则）都是用 `extract-files.py -m` 从这份 blob
生成的真规则，不再是骨架。

生成时做的三件事（都已固化在 `proprietary-files.txt` 里）：
- **符号链接**用 `;SYMLINK=<链接 dst>` 标在真实文件那一行（共 1,061 条链接、876 个
  目标文件），不再单列成一行——单列时 `extract_utils` 会把链接当 ELF 打开而报
  `file not found`；
- `vendor/overlay/*.apk`（7 个静态 RRO）加 `;MAKE_COPY_RULE_ONLY`，走
  `PRODUCT_COPY_FILES` 而不是 `android_app_import`（`extract_utils` 的 app 写入器只认
  `app/`、`priv-app/`，否则会在 `write_product_packages()` 里 `assert` 失败）；
- `system_ext/*` 的 2,399 条**暂时整块注释**（本机磁盘只够 vendor+odm）。

`proprietary/` 里带 `.gitignore`（`*`），blob 不随设备树仓库提交。

### 重新提取 blob（换机器/换 ROM 时）

`proprietary-files.txt` 的路径以 `vendor/`、`odm/` 开头（`system_ext/` 已注释）。
最稳的做法是在有空间的源码树里、从 stock 镜像解包出的分区根目录提取：

```bash
cd device/oneplus/OP68F7L1
./extract-files.py /path/to/stock_dump   # 目录里要有 vendor/ odm/ 子树
```

`extract-files.py` 会处理 `.so` 的 `DT_NEEDED`（`libutils.so → libutils-v32.so`、
`android.hardware.graphics.common-V4-ndk.so → -V7-ndk.so` 等 32 处 fixup）、修补
`manifest_media_c2_V1_2_default.xml` 的版本号，并重新生成
`vendor/oneplus/OP68F7L1/` 下的 `Android.bp` / `OP68F7L1-vendor.mk`。

只重新生成 makefile（blob 已在位、只想改清单时）：

```bash
./extract-files.py -m     # 需要 $ANDROID_BUILD_TOP/prebuilts/extract-tools 下的 patchelf
```

> **不要 `adb pull` 目录树**：清单里 1,000 多个符号链接会被解引用成实体文件，
> `/vendor/lib/modules` 那种指向目录的链接甚至会递归拉取整个模块目录。
> 本机的 blob 是用 `adb exec-out tar -C / -cf - vendor odm` 取的（tar 保留链接），
> 之后按设备清单逐文件比过 size，0 缺失、0 不一致。
>
> fixup 里用到的 patchelf 在源码树里由 `prebuilts/extract-tools/linux-x86/bin/
> patchelf-0_18` 提供；本机没有这份 prebuilt，临时用系统 `/usr/bin/patchelf`
> 软链到该路径跑通的（只影响本机，正式构建请 `repo sync` 出真的 prebuilt）。
>
> 这些 fixup 是从同平台（MT6878, Motorola edge 60 fusion）的 LineageOS 23.2 模板树上
> 照搬并按本机文件存在性筛过的。首次整包构建如果出现 **aidl 接口版本冲突**、
> `cannot locate symbol`、或 `VINTF` 报错，优先检查这个列表：哪条 fixup 的路径在
> 本机上不存在、或者本机 blob 还额外依赖了某个 `-Vx-ndk` 库。

## 用 DSU 测试（不动 boot / init_boot）

真机的 `boot`（内核）和 `init_boot`（generic ramdisk，里面注入了 KernelSU）都保持
ColorOS 原样；本树只提供新的 `/system`、`/system_ext`、`/product`，
所以最合适的测试方式是 **AOSP DSU**：`gsi_tool` 把镜像写进 `/data` 的 backing 文件
并注册到 `/metadata/gsi/<slot>`，重启时 `first_stage_mount` 的
`TransformFstabForDsu()` 会把 fstab 里对应的逻辑分区（`system` → `system_gsi` 等）
**自动改写到 DSU 分区**——DSU 自己替换分区，不碰 boot/init_boot/vendor_boot/dtbo，
也不改 super 元数据和任何 `my_*` 分区。

```bash
# 1) 先构建
. build/envsetup.sh && lunch lineage_OP68F7L1-userdebug && mka

# 2) 装进 DSU（默认 system system_ext product；只装 system 最保守）
device/oneplus/OP68F7L1/tools/dsu.sh install
device/oneplus/OP68F7L1/tools/dsu.sh install system

# 3) 重启后就是本树的 system；状态/回滚：
device/oneplus/OP68F7L1/tools/dsu.sh status
device/oneplus/OP68F7L1/tools/dsu.sh disable   # 下次重启回 stock
device/oneplus/OP68F7L1/tools/dsu.sh wipe      # 删掉 DSU 槽位，回收 /data 空间
device/oneplus/OP68F7L1/tools/dsu.sh check     # 只读：解锁/AVB/DSU/空间现状
DSU_DRY_RUN=1 device/oneplus/OP68F7L1/tools/dsu.sh install   # 只打印命令，不写设备
```

要点：

- `install` 内部按 `gsi_tool install --install-dir /data/gsi/dsu/los --gsi-size <4K 向上取整>
  --partition-name <p>` 逐个装，并给 `system` 顺带建 8 GiB 的 `userdata_gsi`
  （DSU 里的 `/data`，第一次进 DSU 是全新系统），所以**必须包含 `system`**。
- DSU 槽位吃的是 **/data 空间**（不是 super 物理空间），镜像总和 + `userdata_gsi`
  要小于 `/data` 剩余；脚本会先检查。
- `install` 默认是**单次启动**（`enableGsi(singleBoot=true)`）：进一次 DSU，
  再重启就回 stock，最安全。要常驻：`tools/dsu.sh enable --persist`。
- AVB：DSU boot 时镜像按 fstab 的 `avb_keys=/avb` 找 chained-vbmeta 公钥，
  自签 testkey 对不上；本机 BL 已解锁（`/proc/cmdline` 里
  `oplusboot.verifiedbootstate=orange`），`libfs_avb` 在解锁设备上走 permissive，
  所以能启动。注意**别把 `/metadata/gsi/avb_enforce` 建出来**，那会强制校验导致启动失败。
  另外真机装了隐藏解锁状态的模块，`getprop ro.boot.flash.locked` /
  `ro.boot.verifiedbootstate` 显示的是伪装的 `1`/`green`，不要被它误导。
- `vendor` / `odm` 可以进 DSU，但要留意：本树 vendor/odm 的 blob 已提取并对齐
  `proprietary-files.txt`，和 stock 是同一份（只多了 fixup 的 `DT_NEEDED` 改写）。
  第一次建议先只测 `system`（最保守），跑通后再加 `system_ext product`。
  默认分区列表因此是 `system system_ext product`。
- 起不来时：强制重启回 stock，`adb logcat -b all | grep -iE 'avb|fs_mgr|dsu'`；
  `/metadata/gsi/los/lp_names` 能看到实际装了哪些分区。

## 刷机（可选；boot / init_boot 不刷）

BL 需已解锁（真机 `/proc/cmdline` 的 `oplusboot.verifiedbootstate=orange`）。
**不要刷 `boot` 与 `init_boot`**：stock 内核 + stock init_boot（含 KernelSU）引导本树
system 即可，刷了反而丢 root。因为镜像用 AOSP `testkey` 自签，vbmeta 必须关掉验证：

```bash
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot flash vbmeta_system vbmeta_system.img
# fastboot flash boot boot.img        # 不要刷：保留 stock 内核与 KernelSU
# fastboot flash init_boot init_boot.img  # 不要刷
fastboot flash system system.img            # 逻辑分区需先 fastbootd
fastboot flash system_ext system_ext.img
fastboot flash product product.img
fastboot flash vendor vendor.img
fastboot flash odm odm.img
fastboot -w                                  # 换基座必须清 userdata
```

`fastboot-info.txt` 里刻意没有 `update-super`：resize 会把 `my_*` 等库存逻辑分区
挤掉。

## 首次开机排查清单（重要）

这套树是“stock vendor + 新建 framework”的组合，第一次开机大概率需要按下面的顺序
排错：

1. **VNDK / NDK 版本**：stock `/vendor` 是 Android 14 的 vendor（`ro.vndk.version=34`），
   而本树编出来的 `/system` 是 Android 17。若 HAL 起不来并报
   `cannot locate symbol` / `library "libxxx.so" not found`，说明某个 blob 依赖的
   VNDK 库在新系统里版本不匹配；用 `libraries` 里 readelf 的结果在
   `extract-files.py` 里补 `replace_needed`（LOS 的 `libutils-v32` 之类的
   compat 库就是为这个准备的）。
2. **SELinux**：stock 里 `androidboot.selinux=permissive`（`/proc/cmdline` 里虽看不到，
   但 vendor_boot 的 cmdline 带着它）。首次调试建议保持 permissive，等
   `dmesg | grep avc` 干净后再改 `enforcing`。
3. **指纹 HAL 标签**：`/odm/bin/hw/vendor.oplus.hardware.biometrics.fingerprint@*`
   的 file_contexts 应由 odm blob 仓库提供；若 `ls -Z` 显示 `u:object_r:vendor_file:s0`
   导致指纹起不来，在 `sepolicy/vendor/file_contexts` 里加一行
   `/odm/bin/hw/vendor\.oplus\.hardware\.biometrics\.fingerprint@[0-9.]* u:object_r:hal_fingerprint_default_exec:s0`
   并确保只有一个仓库定义它（重复定义会构建失败）。
4. **VINTF 合并**：设备树带的是 stock `/vendor/etc/vintf/manifest.xml`，
   `vendor/etc/vintf/manifest/**` 的 fragment 仍由 blob 提供，两者会在运行时合并。
   若开机报 `VINTF` 或 `checkvintf` 失败，先把 `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE`
   里 `hardware/mediatek/vintf/mediatek_framework_compatibility_matrix.xml`
   这条的路径核对一下（不同 LOS 分支该文件位置可能不同）。
5. **内核头文件**：`TARGET_FORCE_PREBUILT_KERNEL` 在 LOS 24.0 上仍由
   `vendor/lineage/build/tasks/kernel.mk` 处理（已核对：24.0 分支保留该变量与
   `TARGET_PREBUILT_KERNEL` 分支），但 `TARGET_PREBUILT_KERNEL_HEADERS` 会被导出给
   Soong（`vendor/lineage/config/BoardConfigSoong.mk` 的 `EXPORT_TO_SOONG`）。
   本树没有附带 `kernel-uapi-headers.tar.gz`；如果构建在
   `kernel_headers` / `generated_kernel_includes` 阶段失败，把一份
   `make headers_install` 产物的 tarball 放到
   `device/oneplus/OP68F7L1-kernel/kernel-uapi-headers.tar.gz` 并在
   `BoardConfig.mk` 里加上
   `TARGET_PREBUILT_KERNEL_HEADERS := $(DEVICE_PATH)-kernel/kernel-uapi-headers.tar.gz`。
6. **avb / vbmeta**：本树用 AOSP testkey。走 fastboot 刷机路径时必须
   `fastboot --disable-verity --disable-verification flash vbmeta`，否则
   `vbmeta` 校验不过直接不进系统；走 DSU 路径完全不用碰 vbmeta
   （解锁设备上 AVB permissive，见“用 DSU 测试”）。
7. **erofs**：五个构建分区都用 erofs（stock fstab 首选 erofs）。
   `BOARD_EROFS_PCLUSTER_SIZE := 65536` 与 MTK 6.1 内核的 erofs 对齐。
8. **`my_*` 分区与 `/product` overlay**：如果 `/product` 里缺 OPLUS 应用（相机等），
   先确认 `my_product`、`my_heytap`、`my_stock` 没被 `-w` 之外的镜像操作覆盖——
   这三个分区本树从不写入。
9. **A17 framework + A16 vendor（本树特有）**：目标分支是 lineage-24.0，
   而 vendor blob 来自 Android 16。最可能出问题的是构建期 `checkvintf`：
   Android 17 的 framework compatibility matrix 可能要求比 stock vendor manifest
   更新的 HAL 版本。处理办法：
   - 构建期报 `checkvintf` / `VINTF` 错误时，先看缺的是哪个 HAL；
   - 能在 stock `/vendor`、`/odm` 里找到更新版本 fragment 的，让
     `proprietary-files.txt` 保留该 fragment；
   - 确实没有的，在 `configs/vintf/` 下加一个 `<hal>` 覆盖片段，通过
     `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` 引入；
   - 只是“设备声明了高于 matrix 要求的版本”这种告警可以忽略。
   另外 `PRODUCT_SHIPPING_API_LEVEL := 34`（见设计决定 6）就是为了少触发这类要求。

## 从零重建内核（可选，当前不需要）

如果以后要改成“内核也自己编”，需要：
- `device/oneplus/OP68F7L1-kernel/` 换成内核源码仓库（含 `Image` 与 `kernel-uapi-headers.tar.gz`）；
- `BoardConfig.mk` 里去掉 `TARGET_FORCE_PREBUILT_KERNEL` / `TARGET_PREBUILT_KERNEL`，
  改成 `TARGET_KERNEL_SOURCE` + `TARGET_KERNEL_CONFIG`；
- 加上 `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864`、
  `BOARD_INCLUDE_DTB_IN_BOOTIMG := true`、`BOARD_PREBUILT_DTBIMAGE_DIR`、
  `BOARD_{SYSTEM,VENDOR,VENDOR_RAMDISK}_KERNEL_MODULES` 与
  `BOARD_*_KERNEL_MODULES_LOAD`（模块清单可直接用 stock 的
  `modules.load` / `modules.load.vendor_boot` / `modules.load.recovery`，它们就在
  `twrp/OP68F7L1/kernel-modules/` 里）。
