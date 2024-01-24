#!../lib/test-in-container-systemd.sh

set -ex

make install

(
cd /tmp
SYPP_CACHEDIR=$(pwd)/cache /usr/share/sypper/script/sypper download -vvv -c 32 go

rpm -i -U -v cache/packages/*/*/*.rpm
)

go env | grep GOPATH
echo success
