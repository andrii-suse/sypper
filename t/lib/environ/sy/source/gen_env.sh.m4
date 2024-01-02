set -e
[ -e __workdir/conf.env ] || (

echo "export SYPP_ROOT=__workdir/dt
export MOJO_LISTEN=http://*:__port
"

    for i in "$@"; do
        [ -z "$i" ] || echo "export $i" >> __workdir/conf.env
    done
) > __workdir/conf.env
