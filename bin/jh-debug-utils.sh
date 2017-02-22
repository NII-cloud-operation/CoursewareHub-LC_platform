#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

usage()
{
    cat <<EOF
Usage:

./bin/serverctl list {hubid}                       ## List servers
./bin/serverctl allow-sudo {hubid} {server_name}   ## Give sudo powers

EOF
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

rootdir="${ORGCODEDIR%/*}"
ahdir="$rootdir/active-hubs"

DDCONFFILE="datadir.conf"


[ -d "$ahdir" ] || mkdir "$ahdir" || reportfailed

node_list="node1 node2"  # This should be overwritten by the value in the main datadir.conf

classid_to_hubpath()
{
    if [ -f "$1/hubid" ]; then
	echo "$1"
	exit
    else
	local hubid="$1"
	result="$(grep -HFx "$hubid" "$ahdir"/*/hubid)"
	[ "$result" = "" ] && reportfailed "Hub with name '$hubid' not found"
	# result is something like: active-hubs/002/hubid:class4
	echo "${result%/hubid*}"
    fi
}

get_container_names()
{
    annotation="$1"
    read ln # skip first line
    while read -a allwords; do
	lastword="${allwords[@]: -1}"
	echo "$lastword$annotation"
    done
}

do_list()
{
    local hubpath ; hubpath="$(classid_to_hubpath "$1")" || exit
    source "$hubpath/$DDCONFFILE" || reportfailed "missing $DDCONFFILE"

    for n in $node_list; do
	"$hubpath"/jhvmdir-${n}/ssh-shortcut.sh -q sudo docker ps -a | get_container_names " ($n)"
    done
}

cmd="$1"
shift

case "$cmd" in
    list)
	do_list "$@"
	 ;;
    *) usage
       ;;
esac
