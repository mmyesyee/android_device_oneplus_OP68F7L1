# proprietary-files.txt report — OP68F7L1 (OnePlus PYS110, MT6878, SDK 36)

Source: live device `3K667M0029D00000` via `adb shell "cd /<part> && find . -mindepth 1 \( -type f -o -type l \)"`. Literal paths only (no wildcards), C-sorted, no duplicates, no comments.
Scope: /vendor, /odm, /system_ext only. vendor_dlkm, odm_dlkm, system_dlkm, /product and my_* are deliberately not enumerated (kept stock / runtime overlay mounts). `apex/` (vendor 3, system_ext 2 `.apex`) is skipped during enumeration and is not part of any count below.

## Counts per partition

| partition | raw | excluded | dangling | kept |
|---|---|---|---|---|
| vendor | 4197 | 37 | 171 | 3989 |
| odm | 4663 | 14 | 0 | 4649 |
| system_ext | 2437 | 38 | 0 | 2399 |
| **total** | **11297** | **89** | **171** | **11037** |

## Exclusions applied (hit counts, sum = 89)

| pattern | n |
|---|---|
| vendor/{build.prop,ro.prop,rw.prop}, odm/build.prop | 4 |
| vendor/odm (symlink to /odm) | 1 |
| vendor/etc/vintf/{manifest.xml,compatibility_matrix.xml}, system_ext/etc/vintf/** | 5 |
| vendor/etc/selinux/** (13), odm/etc/selinux/** (11), system_ext/etc/selinux/** (30) | 54 |
| vendor/etc/init/hw/{init.mt6878,init.mt6878.usb,init.project,init.connectivity,init.connectivity.common,init_conninfra,init.modem,init.mtkgki,init.sensor_2_0,init.aee,init.cgroup,init.pstore}.rc | 12 |
| vendor/etc/fstab.mt6878 | 1 |
| vendor+system_ext /etc/{vndk*,llndk.libraries*,ld.config*,sanitizer.libraries*,public.libraries*}.txt | 2 |
| vendor/etc/ueventd.rc (the tree ships it as init/ueventd.mt6878.rc) | 1 |
| build-generated */etc/{build.prop,fs_config_dirs,fs_config_files,NOTICE.xml.gz} (vendor 3, odm 2, system_ext 4) | 9 |
| dangling symlinks (target does not exist; see Anomalies) | 171 |
| absent on device, 0 hits: vendor/default.prop, vendor/ueventd.rc, vendor/etc/recovery.fstab, system_ext/build.prop, all vendor+system_ext lib\*/{vndk-\*,vndk-sp-\*,libclang_rt\*,libvndksupport\*}, vendor/bin/vndk\* | 0 |

`vendor/ueventd.rc` does not exist. `vendor/etc/ueventd.rc` is excluded as well: the device
tree ships it as `init/ueventd.mt6878.rc` (installed to `/vendor/etc/ueventd.rc` by
`init/Android.bp`), so keeping the blob copy would make two sources write the same path.

## Size estimate (vendor/oneplus blob repo)

| partition | kept files | as-stored on device | dereferenced (`adb pull`) |
|---|---|---|---|
| vendor | 3989 | 1.95 GiB | 2.99 GiB |
| odm | 4649 | 3.90 GiB | 3.90 GiB |
| system_ext | 2399 | 1.64 GiB | 1.64 GiB |
| **total** | **11037** | **7.48 GiB** | **8.53 GiB** |

## Anomalies

- 171 dangling symlinks omitted: `adb pull` fails on them ("failed to stat remote object"). 170 are `vendor/bin/crossbuild/DataSet/SQLiteModule/db/tuning_DB/<sensor>_mipi_raw/ISP_{mapping,param}.db` → `/odm/.../mt6878/` targets that do not exist (only `koffront`/`kofmain`/`kofmono` really exist, and their `/odm` copies are listed). The 171st is `vendor/bin/hw/android.hardware.graphics.allocator-V1-service-mediatek` → `/vendor/bin/hw/mt6878/...mt6878` (broken in stock too).
- 1068 symlinks kept: 849 `vendor/lib*`→`lib*/mt6878/` shims, 184 toybox/toolbox applets, 35 other. `adb pull` dereferences them, hence 8.53 GiB vs 7.48 GiB.
- 25 links whose target lies outside their own partition: 17 `vendor/bin/crossbuild/*` → `/odm/bin/...` (valid), 6 `odm/lib64/koff*` → `//odm/...` (double slash, benign), `vendor/lib/modules` → `/vendor_dlkm/lib/modules`, `vendor/etc/mdota` → `/mnt/vendor/mdota`.
- No filenames with spaces, tabs, newlines or non-ASCII; no `*` or `?` anywhere.
- `odm/etc/vintf/**` (42 files) kept per instruction; `manifest_dsds.xml`/`manifest_ss.xml` are symlinks to `telephony_manifest_*.xml`, both present.
- Permission blobs kept: `vendor/etc/permissions` 46, `odm/etc/permissions` 17. All 11037 paths re-verified against the live device: 0 paths missing (set difference of the
on-device `find` output against the list). The 94 unlisted leftovers are exactly the 89
exclusions above plus the 5 skipped `apex/` files, i.e. no file is silently dropped.
