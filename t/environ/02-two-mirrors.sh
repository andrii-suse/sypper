set -e

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
(
echo http://$($ng1/print_address)/fardep
echo http://$($ng2/print_address)/fardep
) > $sy/dt/zypper_root/etc/zypp/repos.d/fardep.mirrors

$sy/download -v kmodtool

ls -lRa $sy/cwd/cache/packages/ | grep kmodtool

echo success
