#!/bin/bash
#

DEBUG="true"

SCRIPTNAME="$(basename "$0")"
SYPPLITE=/usr/share/sypper/script/sypplite

FILES=""

PROGRESS_CURRENT=0
PROGRESS_MAX=0
DEST_DIR=""
FILES_IN_DEST=0
PID_SYPPLITE=-1

cleanup() {
    local sig=$1
    test "${PID_SYPPLITE:-1}" -lt 1 || kill $sig $PID_SYPPLITE
}

for sig in INT QUIT HUP TERM; do
  trap "
    cleanup $sig
    trap - $sig EXIT
    kill -s $sig "'"$$"' "$sig"
done
trap cleanup EXIT


log() {
    logger -p info -t $SCRIPTNAME --id=$$ "$@"
}

debug() {
    $DEBUG && log "$@"
}

respond() {
    local msg=$1
    test -z "$2" || msg="$msg\n$2"
    test -z "$3" || msg="$msg\n$3"
    test -z "$4" || msg="$msg\n$4"
    debug "<< [$1]"
    echo -ne "$msg\n\n\x00"
}

execute() {
    debug -- "Executing: $@"
}

create_request() {
    local frame="$1"
    local file
    file=$(
        (
            local w
            local f
            IFS=$' \t\n'
            read w # command
            read w # length
            read w
            read -d ' ' w # alias
            f="$w".predownload
            debug DEST file: {$DEST_DIR} {$f}
            read -d ' ' w # url
            echo $w > "$DEST_DIR/$f"
            (
                while read -r -d ' ' w ; do
                    echo $w
                done
                test -z "$w" || echo $w # last occurence
            ) >> "$DEST_DIR/$f"
            echo $f
        ) <<< "$frame"
    )
    test -z "$file" || {
        FILES="$FILES $file"
        PROGRESS_MAX=$(( $PROGRESS_MAX + $(wc -l < "$DEST_DIR/$file") - 1 ))
        debug FILES=$FILES PROGRESS_MAX=$PROGRESS_MAX
    }
}

set_dest_dir() {
    local frame="$1"
    DEST_DIR=$(
        (
            local w
            IFS=$' \t\n'
            read w # command
            read w # length
            read w
            read w # DEST_DIR
            echo "$w"
        ) <<< "$frame"
    )
    debug DEST DIR : $DEST_DIR
}


start_download() {
    debug Files to download: {$FILES}
    if test -z "$FILES"; then
        debug "Nothing to do"
        return 1
    fi
    PID_SYPPLITE=$(
        cd "$DEST_DIR"
        $SYPPLITE grab $FILES -v -c 12 --suffix .unverified >&2 &
        echo $!
    )
}

check_progress() {
    if test "$PID_SYPPLITE" -le 1; then
        PROGRESS_CURRENT=$PROGRESS_MAX
    elif kill -0 "$PID_SYPPLITE"; then
        cnt=$(find "$DEST_DIR"/*/* -type f 2>/dev/null | wc -l);
        PROGRESS_CURRENT=$(($cnt - $FILES_IN_DEST))
    else
        PID_SYPPLITE=-1
        PROGRESS_CURRENT=$PROGRESS_MAX
    fi
}

ret=0


# The frames are terminated with NUL.  Use that as the delimeter and get
# the whole frame in one go.
while read -d ' ' -r FRAME; do
    printf "%s: " "$(date)" >> /tmp/my.log
    echo ">>" $FRAME | debug
    # We only want the command, which is the first word
    read COMMAND <<<$FRAME

    # libzypp will only close the plugin on errors, which may also be logged.
    # It will also log if the plugin exits unexpectedly.  We don't want
    # to create a noisy log when using another file system, so we just
    # wait until COMMITEND to do anything.  We also need to ACK _DISCONNECT
    # or libzypp will kill the script, which means we can't clean up.
    debug "COMMAND=[$COMMAND]"
    case "$COMMAND" in
    PREDOWNLOAD_DEST)
        if test -x "$SYPPLITE"; then
            :
        else
            respond "ERROR"
            ret=1
            break
        fi
        set_dest_dir "$FRAME"
        if test -z "$DEST_DIR"; then
            respond "ERROR"
            ret=1
            break
        fi
        respond "ACK"
        continue
        ;;
    PREDOWNLOAD_FROM_REPO)
        create_request "$FRAME"
        respond "ACK"
        continue
        ;;
    PREDOWNLOAD_START)
        FILES_IN_DEST=$(find "$DEST_DIR"/*/* -type f 2>/dev/null | wc -l);
        start_download
        respond "ACK"
        continue
        ;;
    PLUGIN_PROGRESS)
        check_progress
        debug "PLUGIN_PROGRESS_CURRENT:$PROGRESS_CURRENT" "PLUGIN_PROGRESS_MAX:$PROGRESS_MAX"
        respond "ACK" "PLUGIN_PROGRESS_CURRENT:$PROGRESS_CURRENT" "PLUGIN_PROGRESS_MAX:$PROGRESS_MAX"
        continue
        ;;
    _DISCONNECT)
        if test "$PID_SYPPLITE" -gt 1 && kill -0 "$PID_SYPPLITE"; then
            kill "$PID_SYPPLITE"
        fi
        respond "ACK"
        break
        ;;
    *)
        respond "_ENOMETHOD"
        continue
        ;;
    esac

    # respond "ACK"
done
debug "Terminating with exit code $ret"
exit $ret
