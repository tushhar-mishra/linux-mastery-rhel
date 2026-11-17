TITLE="What is Linux"
STEP_1="Kernel version and distribution"
step_1() {
  quiz "What kernel version does this machine run? (uname -r)" "^\s*$(uname -r | sed 's/[.+]/\\&/g')\s*$" "uname -r prints the running kernel's release."
  quiz "What is your distribution's ID in /etc/os-release?" "^\s*\"?${ID}\"?\s*$" "The ID= line, e.g. rhel, almalinux, rocky or ubuntu."
}
STEP_2="glibc in ldd's output"
step_2() {
  quiz "Which C library file did 'ldd /usr/bin/bash' list?" "libc\.so\.6" "libc.so.6 is glibc, the GNU C Library almost every program uses."
}
