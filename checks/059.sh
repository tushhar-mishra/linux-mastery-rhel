TITLE="IP addressing and subnetting"
STEP_1="172.16.45.200/20 by hand"
step_1() {
  quiz "Network address of 172.16.45.200/20?" "^\s*172\.16\.32\.0(/20)?\s*$" "/20 = 255.255.240.0: the third octet steps by 16, and 45 falls in 32–47."
  quiz "Broadcast address?" "^\s*172\.16\.47\.255\s*$" "The last address of 172.16.32.0–172.16.47.255."
}
STEP_2="Splitting a /16"
step_2() {
  quiz "How many /24s fit in 10.10.0.0/16?" "^\s*256\s*$" "2^(24-16) = 256."
}
STEP_3="IPv6 shortening"
step_3() {
  quiz "Shorten 2001:0db8:0000:0000:0000:0000:0000:0001" "^\s*2001:db8::1\s*$" "Drop leading zeros in each group, then replace the longest run of zero groups with :: (once)."
}
STEP_4="Local or via the gateway?"
step_4() {
  quiz "Is 192.168.56.200 local to 192.168.56.10/24? (yes/no)" "^\s*yes" "Same /24 network: delivered directly (ip route get shows no 'via')."
  quiz "Is 192.168.57.5 local to it? (yes/no)" "^\s*no" "Different /24: it goes to the default gateway."
}
