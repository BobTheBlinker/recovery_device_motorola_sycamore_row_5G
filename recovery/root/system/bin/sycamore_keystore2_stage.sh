#!/system/bin/sh

SRC=/data/misc/keystore/persistent.sqlite
DIR=/tmp/misc/keystore-sycamore
DST=$DIR/persistent.sqlite

setprop twrp.user.keystore_stage waiting

i=0
while [ ! -s "$SRC" ]; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
        setprop twrp.user.keystore_stage failed
        exit 1
    fi
    sleep 1
done

mkdir -p "$DIR" || exit 1
rm -f "$DST"

if ! cp "$SRC" "$DST"; then
    setprop twrp.user.keystore_stage failed
    exit 1
fi

restorecon "$DST"
chmod 0600 "$DST"

if [ ! -s "$DST" ]; then
    setprop twrp.user.keystore_stage failed
    exit 1
fi

setprop twrp.user.keystore_stage ready
exit 0
