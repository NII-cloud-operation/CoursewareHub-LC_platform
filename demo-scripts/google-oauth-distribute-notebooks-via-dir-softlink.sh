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
rand3digits="$(( 100 + ( $RANDOM % 25 ) ))"

mkdir-conf-file()
{
    [ -f "$3" ] && return
    cat >"$3" <<EOF
baseport=$rand3digits$1

export EXTRAHOSTFWD=,hostfwd=tcp::\$(( baseport + 8 ))-:8888

for i in \$(seq 0 5); do
    EXTRAHOSTFWD=\$EXTRAHOSTFWD,hostfwd=tcp::\$(( baseport + i ))-:\$(( 8000 + i ))
done

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

