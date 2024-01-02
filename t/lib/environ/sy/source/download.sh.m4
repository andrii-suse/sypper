set -a
source __workdir/conf.env
set +a

(
cd __workdir/cwd

perl __srcdir/script/sypper download "$@"
)
