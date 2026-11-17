TITLE="Expansion and globbing"
STEP_1="Globs in /tmp/g"
step_1() {
  check "the practice files exist in /tmp/g" "mkdir /tmp/g && cd /tmp/g && touch app.log app2.log db.log notes.txt Doc1 Doc2 DocA .hidden" bash -c 'cd /tmp/g && test -e app2.log -a -e DocA -a -e notes.txt -a -e .hidden'
  quiz "Which file(s) did 'ls *[0-9].log' match?" "^\s*app2\.log\s*$" "The character just before .log must be a digit: only app2.log."
  quiz "Did 'ls [!a]*' show .hidden? (yes/no)" "^\s*no" "Globs never match names starting with a dot unless you write the dot (or set dotglob)."
}
STEP_2="Brace expansion order"
step_2() {
  quiz "What did 'n=3; echo {1..\$n}' print?" '^\s*\{1\.\.3\}\s*$' "Brace expansion runs before variable expansion, so it saw the text {1..\$n}, which isn't a valid range."
}
STEP_3="nullglob"
step_3() {
  quiz "In an empty directory, what did the loop print WITHOUT nullglob?" 'got: \*\.txt' "A glob with no match stays as literal text, so the loop ran once with '*.txt'."
}
STEP_4="Quoting find patterns"
step_4() {
  quiz "Why can 'find /etc -name *.conf' misbehave when you're inside /etc?" "shell|expand|glob|paths must precede" "The shell expands *.conf against the current directory before find runs. Quote it: '*.conf'."
}
