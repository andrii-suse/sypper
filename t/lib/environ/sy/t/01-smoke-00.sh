set -euo pipefail
sy=$(environ sy $(pwd))

$sy/start
$sy/status

$sy/curl -Is / | grep 200
curl -Is $($sy/print_address) | grep 200

$sy/stop

rc=0
$sy/status 2>/dev/null || rc=$?

test $rc -gt 0
echo PASS $0
