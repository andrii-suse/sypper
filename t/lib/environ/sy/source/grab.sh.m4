mkdir -p __workdir/dt
__workdir/gen_env
set -a
source __workdir/conf.env
set +a

(
cd __workdir/cwd

perl __srcdir/script/sypplite grab -n "$@"
)
