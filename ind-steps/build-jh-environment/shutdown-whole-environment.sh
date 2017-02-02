#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# comment out this next line to make shutdown work on environments restored from snapshots.
[ -f "$DATADIR/flag-inital-build-completed" ] || reportfailed "build must be completed before running this"

[ "$node_list" != "" ] || reportfailed "node_list not defined"

# It is important that node1, node2, etc be shutdown before hub, because
# stopping the NFS server on the hub will freeze the node VMs and
# prevent them from doing a clean shutdown.

vmlist=(
    $(
	for i in $node_list; do
	    echo jhvmdir-$i
	done
    )
    jhvmdir
    jhvmdir-hub
)

TARSUFFIX=".tar"
TARPARAMS="cSf"

# This was created just by gutting snapshot-whole-environment.sh.

do_one_vm()
{
    VMDIR="$1"
    (
	$starting_group "Shutdown VM=$VMDIR"
	false
	$skip_group_if_unnecessary
	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" wrapped ; $iferr_exit

    ) ; $iferr_exit
}

for i in "${vmlist[@]}"; do
    do_one_vm "$i"
done
