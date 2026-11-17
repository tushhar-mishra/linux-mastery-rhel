TITLE="Quoting and control operators"
STEP_1="Word splitting"
step_1() {
  quiz "Why did 'ls my file.txt' fail?" "split|two (arg|word|name)|space|separate" "Unquoted, the shell splits it into two arguments, 'my' and 'file.txt'. Quotes keep it as one."
}
STEP_2="Three kinds of quoting"
step_2() {
  quiz "What did the third bracket show for '\$HOME' in single quotes?" '\$HOME' "Single quotes are fully literal: no variable expansion."
}
STEP_3="&& and ||"
step_3() {
  quiz "Output of: false && echo A || echo B" "^\s*B\s*$" "false fails, so 'echo A' is skipped and || runs echo B."
  quiz "Output of: true && false || echo C" "^\s*C\s*$" "true succeeds, false runs and fails, so || runs echo C. That's why a && b || c isn't if/else."
}
STEP_4="Aliases"
step_4() {
  quiz "Why was the alias gone in a new terminal?" "only|current|this (shell|session)|not saved|bashrc|memory" "Aliases live in the shell that defined them. Put them in ~/.bashrc to keep them."
}
