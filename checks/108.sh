TITLE="Image Builder"
STEP_1="Blueprint and compose"
step_1() {
  check "osbuild-composer's socket is enabled" "sudo dnf install -y osbuild-composer composer-cli && sudo systemctl enable --now osbuild-composer.socket" unit_enabled osbuild-composer.socket
  check "a blueprint has been pushed" "composer-cli blueprints push golden.toml" bash -c '[ -n "$(composer-cli blueprints list 2>/dev/null | grep .)" ]'
  check_match "a compose has finished" "composer-cli compose start BLUEPRINT qcow2, then wait for FINISHED" "FINISHED" composer-cli compose list
}
STEP_2="Version 0.0.2"
step_2() {
  check "a blueprint is at version 0.0.2 or later" "Bump version = \"0.0.2\" in the TOML and push it again" bash -c 'for b in $(composer-cli blueprints list 2>/dev/null); do composer-cli blueprints show "$b" 2>/dev/null | grep -qE "^version = \"0\.0\.([2-9]|[1-9][0-9])\"|^version = \"0\.[1-9]|^version = \"[1-9]" && exit 0; done; exit 1'
}
STEP_3="Many formats"
step_3() {
  quiz "Which command lists the image types you can build?" "compose types" "composer-cli compose types"
}
