TITLE="Terminals, consoles and shells"
STEP_1="Two SSH sessions"
step_1() {
  quiz "What did 'tty' print in one of your SSH windows?" "^\s*/dev/pts/[0-9]+\s*$" "SSH sessions get a pseudo-terminal: /dev/pts/N."
}
STEP_2="The VM console"
step_2() {
  quiz "What did 'tty' print on the VM's console?" "^\s*/dev/tty[0-9]+\s*$" "The console is a kernel terminal: /dev/tty1 (and Ctrl+Alt+F2… for others)."
}
STEP_3="Fixing a scrambled terminal"
step_3() {
  quiz "Which command fixes a terminal scrambled by binary output?" "^\s*(reset|stty sane)\s*$" "reset reinitialises the terminal (stty sane is a lighter version)."
}
STEP_4="Ctrl+S"
step_4() {
  quiz "Which key combination resumes output after Ctrl+S froze it?" "ctrl.?[-+ ]?.?q|\^q" "Ctrl+S / Ctrl+Q are flow control: pause / resume. It isn't a crash."
}
