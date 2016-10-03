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
    [ -f "$4" ] && return
    cat >"$4" <<EOF
# Not all of these are used on every VM
export EXTRAHOSTFWDREL=""

# port 22 is already assigned by kvmsteps
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::43-${2}:43
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::80-${2}:80
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::81-${2}:8001
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::83-${2}:8000
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::84-${2}:8888
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::90-${2}:9000

export mcastMAC="$3"
export mcastPORT=$randomport
EOF
    
}

# last 2 digits, MACaddr, filename
cinfo="
10 192.168.11.99 52:54:00:12:00:99 datadir-jh.conf
20 192.168.11.88 52:54:00:12:00:09 datadir-jh-hub.conf
30 192.168.11.1  52:54:00:12:00:01 datadir-jh-node1.conf
40 192.168.11.2  52:54:00:12:00:02 datadir-jh-node2.conf
50 192.168.11.90 52:54:00:12:00:90 datadir-1box.conf
"

while read twodigits ipaddress mac fname ; do
    [ "$fname" == "" ] && continue
    mkdir-conf-file "$twodigits" "$ipaddress" "$mac" "$fname"
done <<<"$cinfo"

# make sure mcast addresses are the same

[ "$(grep -h -o mcastPORT.* *.conf | sort -u | wc -l)" -eq 1 ] || reportfailed "macPORT values differ in *.conf"

