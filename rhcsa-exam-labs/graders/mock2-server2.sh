#!/usr/bin/env bash
# Grader for RHCSA mock exam 2, server2. Run as root AFTER a reboot:  bash mock2-server2.sh [DATADISK] [SPAREDISK]
# Defaults: /dev/vdb and /dev/vdc (use /dev/sdb /dev/sdc on VirtualBox). Read-only.
set -u
DISK=${1:-/dev/vdb} SPARE=${2:-/dev/vdc}
pass=0 fail=0
ok()  { printf '  PASS  %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
check() { local desc=$1; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi; }
section() { printf '\n== %s\n' "$1"; }

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 2; }
[[ -b $DISK ]] || { echo "No block device $DISK (pass the data disk as \$1)." >&2; exit 2; }

section "B0 general"
check "partition table on $DISK is GPT"         bash -c "blkid -p -s PTTYPE -o value $DISK | grep -qx gpt"
check "fstab passes findmnt --verify"           findmnt --verify
check "SELinux enforcing"                       bash -c "getenforce | grep -qx Enforcing"

section "B2 VFAT by label"
check "filesystem with label DOCS is vfat"      bash -c "blkid -L DOCS >/dev/null && blkid -s TYPE -o value \$(blkid -L DOCS) | grep -qx vfat"
check "DOCS is about 1 GiB (900-1100 MiB)"      bash -c "s=\$(lsblk -bno SIZE \$(blkid -L DOCS)); (( s >= 900*1024*1024 && s <= 1100*1024*1024 ))"
check "fstab mounts /mnt/docs by LABEL=DOCS"    bash -c "awk '\$1 !~ /^#/ && \$2==\"/mnt/docs\"{print \$1}' /etc/fstab | grep -qx 'LABEL=DOCS'"
check "/mnt/docs mounted"                       findmnt /mnt/docs
check "/mnt/docs owned by UID 2001"             bash -c "stat -c %u /mnt/docs | grep -qx 2001"

section "B3 swap by UUID"
check "at least two active swap areas"          bash -c "test \$(swapon --noheadings --show=NAME | wc -l) -ge 2"
check "a swap partition on $DISK is active"     bash -c "swapon --noheadings --show=NAME | grep -q '^${DISK}'"
check "that swap is in fstab by UUID"           bash -c "dev=\$(swapon --noheadings --show=NAME | grep '^${DISK}' | head -1); u=\$(blkid -s UUID -o value \$dev); grep -Eq \"^UUID=\$u[[:space:]]+(none|swap)[[:space:]]+swap\" /etc/fstab"
check "swap size about 512 MiB (450-560 MiB)"   bash -c "dev=\$(swapon --noheadings --show=NAME | grep '^${DISK}' | head -1); s=\$(lsblk -bno SIZE \$dev); (( s >= 450*1024*1024 && s <= 560*1024*1024 ))"

section "B4 LVM"
check "VG vgexam exists"                        vgs vgexam
check "vgexam extent size 8 MiB"                bash -c "vgs --noheadings --units m -o vg_extent_size vgexam | grep -Eq '^ *8\.00m'"
check "lvdata exists"                           lvs vgexam/lvdata
check "lvdata is 600 MiB (75 extents)"          bash -c "lvs --noheadings -o lv_size --units m vgexam/lvdata | grep -Eq '^ *600\.00m'"
check "lvdata is XFS"                           bash -c "blkid -s TYPE -o value /dev/vgexam/lvdata | grep -qx xfs"
check "/data in fstab by UUID of lvdata"        bash -c "u=\$(blkid -s UUID -o value /dev/vgexam/lvdata); awk '\$2==\"/data\"{print \$1}' /etc/fstab | grep -qx \"UUID=\$u\""
check "/data mounted from lvdata"               bash -c "findmnt -no SOURCE /data | grep -q 'vgexam-lvdata'"
# XFS overhead: a 600 MiB LV shows ~536M in df, the original 400 MiB ~336M
check "/data filesystem grown (df > 450 MiB)"   bash -c "s=\$(df -BM --output=size /data | tail -1 | tr -dc 0-9); (( s > 450 ))"

section "B5 ext4 by label"
check "lvlogs is ext4 labeled LOGS"             bash -c "blkid /dev/vgexam/lvlogs | grep -q 'LABEL=\"LOGS\"' && blkid -s TYPE -o value /dev/vgexam/lvlogs | grep -qx ext4"
check "lvlogs about 200 MiB"                    bash -c "lvs --noheadings -o lv_size --units m vgexam/lvlogs | grep -Eq '^ *200\.00m'"
check "/logs in fstab by LABEL=LOGS"            bash -c "awk '\$1 !~ /^#/ && \$2==\"/logs\"{print \$1}' /etc/fstab | grep -qx 'LABEL=LOGS'"
check "/logs mounted"                           findmnt /logs

section "B6 partition deleted"
if [[ -b $SPARE ]]; then
  check "$SPARE has no partitions"              bash -c "test \$(lsblk -nro TYPE $SPARE | grep -c part) -eq 0"
else
  printf '  SKIP  %s not present\n' "$SPARE"
fi

printf '\nScore: %d passed, %d failed (%d%%)\n' "$pass" "$fail" $(( 100 * pass / (pass + fail) ))
[[ $fail -eq 0 ]]
