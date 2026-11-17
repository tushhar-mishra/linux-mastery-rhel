TITLE="Building RPM packages"
STEP_1="Build, install, verify, remove"
step_1() {
  check "rpmbuild is installed" "sudo dnf install -y rpm-build rpmdevtools rpmlint" command -v rpmbuild
  check "you have built an RPM in ~/rpmbuild/RPMS" "rpmbuild -ba ~/rpmbuild/SPECS/hello-tool.spec" bash -c "find '$LHOME/rpmbuild/RPMS' -name '*.rpm' 2>/dev/null | grep -q ."
  quiz "Which command lists the files that changed since a package was installed?" "rpm\s+-V" "rpm -V PACKAGE (S size, 5 checksum, T time, c config)."
}
STEP_2="%config(noreplace)"
step_2() {
  quiz "What was the new packaged config file called after the upgrade?" "\.rpmnew" "Your edited file was kept; the new one landed as FILE.rpmnew."
}
STEP_3="A signed local repo"
step_3() {
  local f mine=""
  for f in /etc/yum.repos.d/*.repo; do rpm -qf "$f" >/dev/null 2>&1 || mine="$mine $f"; done
  check "you added your own .repo file (not one from a package)" "/etc/yum.repos.d/internal.repo with baseurl=, gpgcheck=1, gpgkey=" test -n "$mine"
  [ -n "$mine" ] || return 0
  check "it has gpgcheck=1" "gpgcheck=1 and a gpgkey= line" bash -c "grep -qsE '^\s*gpgcheck\s*=\s*1' $mine"
  check "its repodata is reachable (createrepo_c ran)" "sudo createrepo_c /var/www/html/repo, and the web server is running" bash -c 'for u in $(grep -hsE "^\s*baseurl\s*=" '"$mine"' | sed -E "s/^\s*baseurl\s*=\s*//"); do case $u in file://*) [ -f "${u#file://}/repodata/repomd.xml" ] && exit 0 ;; *) curl -sf --max-time 5 "$u/repodata/repomd.xml" >/dev/null && exit 0 ;; esac; done; exit 1'
  local ids; ids=$(sed -n 's/^\[\(.*\)\]\s*$/\1/p' $mine | sed 's/^/--enablerepo=/' | tr '\n' ' ')
  check "hello-tool is available from it" "Copy the RPM into the repo directory and run createrepo_c again" bash -c "dnf -q repoquery --disablerepo='*' $ids hello-tool 2>/dev/null | grep -q hello-tool"
}
