#!lib/test-in-container-environ.sh
set -e

sy=$(environ sy $PWD)

ng=$(environ ng)
$ng/start
ln -s $PWD/t/data/repo/fardep $ng/dt/

$sy/ar http://$($ng/print_address)/fardep fardep

output1=$($sy/download -v kmodtool 2>&1)
output2=$($sy/download -v kmodtool 2>&1)
output3=$($sy/download -v kmodtool --force 2>&1)

# only output 1 and 3 should have message about downloading the rpm
echo "$output1" | grep "trying http://$($ng/print_address)/fardep/noarch/kmodtool-1-45.2.noarch.rpm"
echo "$output3" | grep "trying http://$($ng/print_address)/fardep/noarch/kmodtool-1-45.2.noarch.rpm"

# output2 should take it from the cache
rc=0
echo "$output2" | grep "trying http://$($ng/print_address)/fardep/noarch/kmodtool-1-45.2.noarch.rpm" || rc=$?
test $rc -gt 0

echo success
