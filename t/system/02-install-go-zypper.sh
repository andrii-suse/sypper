#!../lib/test-in-container-systemd.sh

set -ex

make install

(
cd /tmp

/usr/share/sypper/script/sypper download -vvv go
cp -r cache/packages/* /var/cache/zypp/packages/

zypper -nvvv in go | tee z.log

cnt=$(grep 'In cache' z.log | wc -l)

test $cnt -gt 10;

rc=0
# check that zypper never printed 'Retrieving', (except for repodata)
grep -v repodata z.log | grep -v media.1 | grep -i Retrieving || rc=$?
test $rc -gt 0
)
go env | grep GOPATH

echo success
