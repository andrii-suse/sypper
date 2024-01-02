set -e

# export SY_DEBUG_ALL=1;

sy=$(environ sy $PWD)

ng=$(environ ng)
$ng/start
ln -s $PWD/t/data/repo/fardep $ng/dt/
$ng/curl | grep far
$ng/curl /fardep/ | grep repodata

$sy/ar http://$($ng/print_address)/fardep fardep

$sy/start
$sy/status
$sy/curl /rest/repo | grep fardep

$sy/download kmodtool

ls -lRa $sy/dt/ | grep -v root_zypper | grep kmodtool
