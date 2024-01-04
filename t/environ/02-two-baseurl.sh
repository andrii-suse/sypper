set -e

# export SY_DEBUG_ALL=1;

sy=$(environ sy $PWD)

ng1=$(environ ng1)
ng2=$(environ ng2)
$ng1/start
$ng2/start

# ln -s $PWD/t/data/repo/fardep $ng1/dt/
ln -s $PWD/t/data/repo/fardep $ng2/dt/

$ng2/curl | grep far
$ng2/curl /fardep/ | grep repodata

$sy/ar http://$($ng1/print_address)/fardep fardep

# add another mirror to baseurl
sed -i 's!\(baseurl=.*\)!\1; http://127.0.0.1:2220/fardep!' $sy/dt/zypper_root/etc/zypp/repos.d/fardep.repo

$sy/download -v kmodtool

ls -lRa $sy/cwd/cache/packages/ | grep kmodtool

echo success
