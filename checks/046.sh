TITLE="Disks and partitions"
STEP_1="Reading lsblk"
step_1() {
  local d; d=$(lsblk -nso NAME,TYPE "$(findmnt -no SOURCE /)" 2>/dev/null | awk '$2=="disk"{print $1}' | sed 's/^[^a-z]*//' | head -1)
  quiz "Which disk holds / on this machine?" "^\s*(/dev/)?${d}\s*$" "lsblk shows the tree: the disk, its partition, maybe an LVM LV, and the mount point /."
}
STEP_2="fdisk: Linux + swap partitions"
step_2() {
  check_match "a disk has a ~1 GiB 'Linux filesystem' partition" "fdisk /dev/vdb: n, +1G, then w" "^\S+\s+1G\s+Linux filesystem" lsblk -lno NAME,SIZE,PARTTYPENAME
  check_match "and a 512 MiB 'Linux swap' partition" "fdisk: n, +512M, t, swap, then w" "^\S+\s+512M\s+Linux swap" lsblk -lno NAME,SIZE,PARTTYPENAME
}
STEP_3="parted: GPT + LVM"
step_3() {
  check_match "a disk has a GPT label and an 'LVM' partition" "parted /dev/vdc mklabel gpt mkpart data 1MiB 100% set 1 lvm on" "Linux LVM" lsblk -lno NAME,PARTTYPENAME
}
STEP_4="Stable names"
step_4() {
  quiz "Which /dev/disk/by-* directory names filesystems by their UUID?" "by-uuid" "Others: by-id (hardware serial), by-path (bus position), by-label, by-partuuid."
}
