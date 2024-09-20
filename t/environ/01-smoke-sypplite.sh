#!lib/test-in-container-environ.sh
set -e

# export SY_DEBUG_ALL=1;

sy=$(environ sy $PWD)

ng=$(environ ng)
$ng/start
ln -s $PWD/t/data/repo/fardep $ng/dt/

mkdir -p $sy/requests

(
    cd $sy/requests
    (
        echo $($ng/print_address)/fardep
        echo noarch/kmodtool-1-45.2.noarch.rpm
    ) > test1.request

    $sy/grab -vvv $sy/requests/test1.request
    ls -lRa $sy/cwd | grep kmodtool

    # try again the same
    out=$($sy/grab -vvv $sy/requests/test1.request 2>&1)

    echo $out | grep -q 'already cached'
)

echo success
