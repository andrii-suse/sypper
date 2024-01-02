mkdir -p __workdir/dt
__workdir/gen_env
set -a
source __workdir/conf.env
set +a

(
cd __workdir/cwd

perl __srcdir/script/syppd >> __workdir/.cout 2>> __workdir/.cerr &
pid=$!
echo $pid > __workdir/.pid
)
sleep 0.1
__workdir/status || sleep 0.1
__workdir/status || sleep 0.2
__workdir/status || sleep 0.3
__workdir/status || sleep 0.4
__workdir/status || sleep 1
