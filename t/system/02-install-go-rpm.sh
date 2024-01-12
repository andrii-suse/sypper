#!../lib/test-in-container-systemd.sh

set -ex

make install

(
cd /tmp
/usr/share/sypper/script/sypper download -vvv go

rpm -i -U -v cache/packages/*/*/*.rpm
)

go env | grep GOPATH
echo success
