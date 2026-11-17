TITLE="vi and vim"
STEP_1="Your practice copy"
step_1() {
  check "~/svc.txt exists" "cp /etc/services ~/svc.txt" test -f "$LHOME/svc.txt"
}
STEP_4="Quit without saving"
step_4() {
  check "~/svc.txt is still identical to /etc/services (you quit with :q!)" "If you saved by mistake: cp /etc/services ~/svc.txt and repeat steps 2–4" cmp -s /etc/services "$LHOME/svc.txt"
  quiz "Which command quits vim without saving?" "^\s*:q!\s*$" ":q! discards the changes; :wq or :x saves."
}
STEP_5="vimtutor"
step_5() { manual "You finished vimtutor (about 30 minutes)."; }
