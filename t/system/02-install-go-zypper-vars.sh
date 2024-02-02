#!../lib/test-in-container-systemd.sh

set -ex

make install

sed -i 's/download.opensuse.org/\${downloadserver}/g' /etc/zypp/repos.d/*repo
sed -i 's/15.5/\$releasever_major.\$releasever_minor/g' /etc/zypp/repos.d/*repo
mkdir -p /etc/zypp/vars.d
echo mirrorcache-us.opensuse.org > /etc/zypp/vars.d/downloadserver

(
cd /tmp

/usr/share/sypper/script/sypper download -vvv go

# when running as root sypper will use /var/cache/zypp, so zypper should just pick up rpms
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
