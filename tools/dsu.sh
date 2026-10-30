#!/usr/bin/env bash
#
# dsu.sh - install this tree's images with Dynamic System Updates (DSU).
#
# DSU never touches boot, init_boot, vendor_boot, dtbo or vbmeta: gsi_tool
# creates backing files under /data/gsi/dsu/<slot>/ and the first-stage mount
# code rewrites the fstab on the next boot, so the stock kernel, the stock
# vendor_boot (DTB + modules) and KernelSU in init_boot keep working.
#
# Usage:
#   tools/dsu.sh install [partition...]   # default: system system_ext product
#   tools/dsu.sh status
#   tools/dsu.sh enable [--persist]       # single boot by default
#   tools/dsu.sh disable
#   tools/dsu.sh wipe
#   tools/dsu.sh check                    # read-only sanity check
#
# Environment:
#   ANDROID_PRODUCT_OUT / OUT   out dir (default <repo>/out/target/product/OP68F7L1)
#   DSU_SLOT                    slot name (default: los)
#   DSU_USERDATA_SIZE           size of the nested /data (default: 8 GiB)
#   DSU_SINGLE_BOOT             1 = one-shot boot (default), 0 = keep enabled
#   DSU_DRY_RUN                 1 = print commands, touch nothing
#
set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEVICE_DIR=$(cd "$SELF_DIR/.." && pwd)
REPO_ROOT=$(cd "$DEVICE_DIR/../../.." && pwd)

OUT_DIR=${ANDROID_PRODUCT_OUT:-${OUT:-$REPO_ROOT/out/target/product/OP68F7L1}}
SLOT=${DSU_SLOT:-los}
INSTALL_DIR=/data/gsi/dsu/$SLOT
USERDATA_SIZE=${DSU_USERDATA_SIZE:-8589934592}
SINGLE_BOOT=${DSU_SINGLE_BOOT:-1}
DRY_RUN=${DSU_DRY_RUN:-0}
DEFAULT_PARTITIONS=(system system_ext product)

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

sh_() { adb shell "$@"; }
root_sh_() { adb shell "su -c '$*'" 2>/dev/null || adb shell "$*"; }

need_root() {
    adb root >/dev/null 2>&1 || true
    sleep 1
    local uid
    uid=$(sh_ id 2>/dev/null | sed -n 's/.*uid=\([0-9]*\).*/\1/p')
    [ "$uid" = "0" ] || die "adb shell is not root (uid=$uid)"
}

round_up() { # round_up <value> <align>
    local v=$1 a=$2
    echo $(( (v + a - 1) / a * a ))
}

free_data_bytes() {
    sh_ df -k /data | awk 'NR==2 {print $4 * 1024}'
}

status() {
    note "device: $(sh_ getprop ro.product.device 2>/dev/null | tr -d '\r')"
    echo "gsi_tool status : $(sh_ gsi_tool status 2>/dev/null || echo '<unavailable>')"
    echo "active slot     : $(sh_ cat /metadata/gsi/dsu/active 2>/dev/null || echo '<none>')"
    echo "lp_names        : $(sh_ cat /metadata/gsi/dsu/lp_names 2>/dev/null || echo '<none>')"
    echo "avb_enforce     : $(sh_ 'test -e /metadata/gsi/avb_enforce && echo present || echo absent')"
}

check() {
    note "props (may be spoofed by hiding modules)"
    sh_ "getprop ro.boot.flash.locked; getprop ro.boot.verifiedbootstate; getprop ro.boot.veritymode" | sed 's/^/  /'
    note "cmdline verified-boot flags (trustworthy)"
    sh_ 'cat /proc/cmdline' | tr ' ' '\n' | grep -i 'verifiedbootstate' | sed 's/^/  /' || true
    status
    note "space"
    sh_ df -h /data | sed 's/^/  /'
}

require_system_first() {
    local have_system=0 p
    for p in "$@"; do [ "$p" = "system" ] && have_system=1; done
    [ "$have_system" = "1" ] || die "the list must contain 'system' (gsi_tool needs it as the base)"
}

install_cmd() {
    local partitions=("$@")
    [ ${#partitions[@]} -gt 0 ] || partitions=("${DEFAULT_PARTITIONS[@]}")
    require_system_first "${partitions[@]}"

    need_root
    case "$(sh_ gsi_tool status 2>/dev/null || true)" in
        *running*) die "a GSI is already running, disable it first" ;;
    esac

    local total=$USERDATA_SIZE p img size
    for p in "${partitions[@]}"; do
        img=$OUT_DIR/$p.img
        [ -f "$img" ] || die "$img not found (build it first, or set ANDROID_PRODUCT_OUT)"
        size=$(stat -c %s "$img")
        total=$(( total + $(round_up "$size" 4096) ))
    done

    local free
    free=$(free_data_bytes)
    note "needed on /data: $(( total / 1024 / 1024 )) MiB, free: $(( free / 1024 / 1024 )) MiB"
    [ "$free" -gt "$total" ] || die "not enough space on /data"

    if [ "$DRY_RUN" = "1" ]; then
        note "dry run, nothing is written"
        for p in "${partitions[@]}"; do
            img=$OUT_DIR/$p.img
            echo "  push $img -> /data/local/tmp/dsu-$p.img"
            echo "  gsi_tool install --install-dir $INSTALL_DIR --gsi-size $(round_up "$(stat -c %s "$img")" 4096) --partition-name $p --no-reboot"
        done
        echo "  adb reboot"
        return 0
    fi

    for p in "${partitions[@]}"; do
        img=$OUT_DIR/$p.img
        size=$(round_up "$(stat -c %s "$img")" 4096)
        note "installing $p ($(( size / 1024 / 1024 )) MiB)"
        adb push "$img" "/data/local/tmp/dsu-$p.img" >/dev/null
        if [ "$p" = "system" ]; then
            root_sh_ "gsi_tool install --install-dir $INSTALL_DIR --gsi-size $size --partition-name $p --userdata-size $USERDATA_SIZE --no-reboot < /data/local/tmp/dsu-$p.img"
        else
            root_sh_ "gsi_tool install --install-dir $INSTALL_DIR --gsi-size $size --partition-name $p --no-reboot < /data/local/tmp/dsu-$p.img"
        fi
        root_sh_ "rm -f /data/local/tmp/dsu-$p.img"
    done

    if [ "$SINGLE_BOOT" = "1" ]; then
        note "installed; rebooting once into the DSU (slot $SLOT)"
    else
        root_sh_ "gsi_tool enable -d $SLOT"
        note "installed and enabled persistently; rebooting"
    fi
    adb reboot
}

enable_cmd() {
    need_root
    if [ "${1:-}" = "--persist" ]; then
        root_sh_ "gsi_tool enable -d $SLOT"
    else
        root_sh_ "gsi_tool enable -s -d $SLOT"
    fi
}

disable_cmd() { need_root; root_sh_ "gsi_tool disable"; }
wipe_cmd()    { need_root; root_sh_ "gsi_tool wipe"; }

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

cmd=${1:-help}
shift || true
case "$cmd" in
    install) install_cmd "$@" ;;
    status)  status ;;
    enable)  enable_cmd "$@" ;;
    disable) disable_cmd ;;
    wipe)    wipe_cmd ;;
    check)   check ;;
    help|-h|--help) usage ;;
    *) die "unknown command: $cmd (try --help)" ;;
esac
