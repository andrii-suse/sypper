#!lib/test-in-container-environ.sh
set -e

export SY_METADATA_EXPIRE=2

sy=$(environ sy $PWD)

ng=$(environ ng)
$ng/start
ln -s $PWD/t/data/repo/fardep $ng/dt/

$sy/ar -f http://$($ng/print_address)/fardep fardep

output1=$($sy/refresh -vv 2>&1)
output2=$($sy/refresh -vv 2>&1)
sleep $SY_METADATA_EXPIRE
output3=$($sy/refresh -vv 2>&1)
output4=$($sy/refresh -vv --force 2>&1)

# repomd.xml should be always downloaded only in 1 3 and 4
echo check repomd.xml in output 1
echo "$output1" | grep "trying http://127.0.0.1:2210/fardep/repodata/repomd.xml"
echo check repomd.xml in output 3
echo "$output3" | grep "trying http://127.0.0.1:2210/fardep/repodata/repomd.xml"
echo check repomd.xml in output 4
echo "$output4" | grep "trying http://127.0.0.1:2210/fardep/repodata/repomd.xml"


echo check no repomd.xml in output 2
rc=0
echo "$output2" | grep "trying http://127.0.0.1:2210/fardep/repodata/repomd.xml" || rc=$?
test $rc -gt 0


# trying ... primary.xml should be only in 1 and 4
echo check primary.xml in output 1
echo "$output1" | grep "trying http://127.0.0.1:2210/fardep/repodata/007c0a05d5188bf4d61c2d66f2795fe1f920fcc4b5bee78dca88b18d6a890d73-primary.xml.gz"
echo check primary.xml in output 4
echo "$output4" | grep "trying http://127.0.0.1:2210/fardep/repodata/007c0a05d5188bf4d61c2d66f2795fe1f920fcc4b5bee78dca88b18d6a890d73-primary.xml.gz"

echo check no primary.xml in output 2
rc=0
echo "$output2" | grep "trying http://127.0.0.1:2210/fardep/repodata/007c0a05d5188bf4d61c2d66f2795fe1f920fcc4b5bee78dca88b18d6a890d73-primary.xml.gz" || rc=$?
test $rc -gt 0

echo check no primary.xml in output 3
rc=0
echo "$output3" | grep "trying http://127.0.0.1:2210/fardep/repodata/007c0a05d5188bf4d61c2d66f2795fe1f920fcc4b5bee78dca88b18d6a890d73-primary.xml.gz" || rc=$?
test $rc -gt 0

# 'primary cached' must be in output 3 (in output 2 the repo hasn't expire yet, so all was loaded from the cache)
echo check skip primary.xml in output 3
echo "$output3" | grep "skipping repodata/007c0a05d5188bf4d61c2d66f2795fe1f920fcc4b5bee78dca88b18d6a890d73-primary.xml.gz (already cached)"

echo success
