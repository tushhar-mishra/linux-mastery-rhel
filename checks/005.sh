TITLE="Getting help"
STEP_1="fstab fields from the man page"
step_1() {
  quiz "What does the 6th field of /etc/fstab set?" "fsck|check|pass" "The fsck order: 0 = never check, 1 = root, 2 = other filesystems (man 5 fstab)."
  quiz "And the 5th field?" "dump|backup" "Whether the old dump backup tool should back it up; almost always 0."
}
STEP_2="Finding a command with man -k"
step_2() {
  quiz "Which command changes a user's password expiry settings?" "^\s*chage\s*$" "chage (change age); 'man -k password' lists it."
}
STEP_3="Man sections"
step_3() {
  quiz "Which man section documents the crontab FILE format?" "^\s*5\s*$" "Section 5 = file formats: 'man 5 crontab'. Section 1 is the crontab command."
}
STEP_4="Builtins"
step_4() {
  quiz "Where do you read the documentation for the builtin 'cd': man or help?" "^\s*help" "Builtins are documented by bash's own 'help' command."
}
