#!lib/test-in-container-environ.sh
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

# ensure the package isn't in the cache yet
rc=0
ls -lRa $sy/cwd/cache/packages/ 2>/dev/null | grep kmodtool || rc=$?
test $rc -gt 0

$sy/download kmodtool

ls -lRa $sy/cwd/cache/packages/ | grep kmodtool

echo success
