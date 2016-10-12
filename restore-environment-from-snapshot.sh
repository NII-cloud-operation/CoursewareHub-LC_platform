#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

DATADIR="$(readlink -f "$1")"  # required

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

source "$DATADIR/datadir.conf" || reportfailed

restore_one_vm()
{
    VMDIR="$1"
    (
	$starting_group "Restore VM=$VMDIR"
	[ -d "$DATADIR/$VMDIR" ]
	$skip_group_if_unnecessary

	(
	    $starting_step "Expand snapshot tar file for VM=$VMDIR"
	    [ -f "$DATADIR/$VMDIR-snapshot.tar.gz" ]
	    $skip_step_if_already_done;  set -e

	    echo -n "Expanding tar file..."
	    cd "$DATADIR"
	    tar xSf "$snapshot_source/$VMDIR-snapshot.tar.gz"
	    echo "..finished."
	) ; prev_cmd_failed
    ) ; prev_cmd_failed
}

for i in "${vmlist[@]}"; do
    restore_one_vm "$i"
done

(
    $starting_step "Assign mcastPORT"
    [[ "$(cat "$DATADIR"/*/datadir.conf | tee /tmp/check)" != *set-this* ]]
    $skip_step_if_already_done; set -e

    alreadyset="$(cat "$DATADIR"/*/datadir.conf | grep mcastPORT= | grep -v set-this || true)"
    [ "$alreadyset" = "" ] || reportfailed "Some mcastPORT values (but not all) already set"

    locally_in_use="$(
       ps auxwww | grep -o "mcast=[0-9. ]*:[0-9]*" | cut -d : -f 2 | sort -u
       # e.g.:  "mcast=230.0.0.1:5320" -> "5320" -> sort -u
    )"
    while true; do
	randomport="$(( 5000 + ( $RANDOM % 5000 ) ))"
	if ! grep -Fx "$locally_in_use"  <<<"$randomport" 1>/dev/null ; then
	    break # if $randomport is not in the list
	fi
	sleep 0.567 # save CPU if this loop is buggy
    done
    # TODO, reduce the chance of port conflicts even more, somehow

    sed -i "s,mcastPORT=set-this-before-booting,mcastPORT=$randomport,"  "$DATADIR"/*/datadir.conf
)  ; prev_cmd_failed
