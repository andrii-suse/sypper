set -e

sy=$(environ sy $PWD)

mc=$(environ mc)
ng1=$(environ ng1)
ng2=$(environ ng2)
$ng1/start
$ng2/start

$mc/start

$mc/sql "insert into server(hostname,urldir,enabled,country,region) select '$($ng1/print_address)','','t','us','na'"
$mc/sql "insert into server(hostname,urldir,enabled,country,region) select '$($ng2/print_address)','','t','de','eu'"

ln -s $PWD/t/data/repo/fardep $mc/dt/
ln -s $PWD/t/data/repo/fardep $ng2/dt/

$mc/curl /download | grep far
$mc/curl /download/fardep/ | grep repodata

for job in folder_sync mirror_scan; do
    for p in /fardep/repodata /fardep/x86_64; do
        $mc/backstage/job -e $job -a '["'$p'"]'
    done
    $mc/backstage/shoot
done

$mc/curl /download/fardep/repodata/repomd.xml.meta4 | grep $($ng2/print_address)
$mc/curl /download/fardep/repodata/?mirrorlist | grep $($ng2/print_address)

$sy/ar http://$($mc/print_address)/download/fardep fardep

$sy/refresh -vvv

test -d $sy/cwd/cache/meta/
test -f $sy/cwd/cache/meta/fardep.mirrors
grep $($ng2/print_address) $sy/cwd/cache/meta/fardep.mirrors

echo success
