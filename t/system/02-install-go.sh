#!../lib/test-in-container-systemd.sh

set -ex

make install

/usr/share/sypper/script/sypper download -vvv go

rpm -i cache/packages/*/*/*rpm

go env
echo success
