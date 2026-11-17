TITLE="Cryptography basics"
STEP_1="Verifying a download"
step_1() {
  quiz "Which command checks files against a list of SHA-256 sums?" "sha256sum\s+(-c|--check)" "sha256sum -c FILE.sha256 prints OK or FAILED for each file."
}
STEP_2="Certificates"
step_2() {
  quiz "Which openssl command shows a website's certificate chain?" "s_client" "openssl s_client -connect host:443 -servername host -showcerts </dev/null"
}
STEP_3="A self-signed certificate"
step_3() {
  quiz "In a self-signed certificate, how do Issuer and Subject compare?" "same|equal|identical|match" "It signs itself, so the issuer is the subject."
}
STEP_4="gpg -c"
step_4() {
  local f; f=$(find "$LHOME" -maxdepth 2 -name '*.gpg' -type f 2>/dev/null | head -1)
  check "an encrypted .gpg file exists in your home" "gpg -c FILE creates FILE.gpg" test -n "$f"
  [ -n "$f" ] && check "it is really encrypted (not plain text)" "Use gpg -c, not just a rename" bash -c "file '$f' | grep -qiE 'pgp|gpg|encrypted|data'"
}
