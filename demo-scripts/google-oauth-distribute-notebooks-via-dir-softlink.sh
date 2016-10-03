#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

rootdir="${ORGCODEDIR%/*}"

[ -f "$rootdir/test2-build-nbgrader-environment-w-ansible" ] || reportfailed "bug1"

randomport="$(( 5000 + ( $RANDOM % 5000 ) ))"



mkdir-conf-file()
{
    [ -f "$3" ] && return
    cat >"$3" <<EOF
# Not all of these are used on every VM
export EXTRAHOSTFWD=""

# port 22 is already assigned by kvmsteps
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::43-:43
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::80-:80
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::81-:8001
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::83-:8000
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::84-:8888
EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::90-:9000

export mcastMAC="$2"
export mcastPORT=$randomport
EOF
    
}

# last 2 digits, MACaddr, filename
cinfo="
10 52:54:00:12:00:99 datadir-jh.conf
20 52:54:00:12:00:09 datadir-jh-hub.conf
30 52:54:00:12:00:01 datadir-jh-node1.conf
40 52:54:00:12:00:02 datadir-jh-node2.conf
50 52:54:00:12:00:90 datadir-1box.conf
"

while read twodigits mac fname ; do
    [ "$fname" == "" ] && continue
    mkdir-conf-file "$twodigits" "$mac" "$fname"
done <<<"$cinfo"

# make sure mcast addresses are the same

[ "$(grep -h -o mcastPORT.* *.conf | sort -u | wc -l)" -eq 1 ] || reportfailed "macPORT values differ in *.conf"

