mkdir -p __workdir/dt/zypper_root/
ZYPP_LOGFILE=__workdir/dt/zypper_root/.zypp.log zypper --root __workdir/dt/zypper_root ar "$@"

ln -s __workdir/dt/zypper_root/etc/zypp/repos.d __workdir/dt/repos.d
