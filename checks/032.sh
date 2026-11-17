TITLE="Flatpak and snap"
STEP_2="A user remote"
step_2() {
  check "flatpak is installed" "sudo dnf install -y flatpak" command -v flatpak
  check_match "Flathub is configured as a --user remote" "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" "^flathub" as_learner flatpak remotes --user --columns=name
}
STEP_3="Uninstalled again"
step_3() {
  check "no user-installed Flatpak apps remain" "flatpak uninstall --user APP, then flatpak uninstall --user --unused" bash -c "[ -z \"\$(runuser -u '$LEARNER' -- flatpak list --user --app --columns=application 2>/dev/null)\" ]"
}
