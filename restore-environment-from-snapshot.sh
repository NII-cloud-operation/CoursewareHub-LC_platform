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
    [[ "$(cat "$DATADIR"/*/datadir.conf)" != *set-this* ]]
    $skip_step_if_already_done; set -e
    echo fffffffffffffffff
    exit 222
    cd "$DATADIR"
    tar cSf "$DATADIR/extra-snapshot-files.tar.gz" "${extrafiles[@]}"
)  ; prev_cmd_failed
